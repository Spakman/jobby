require 'fileutils'
require 'socket'
require 'logger'

module Jobby
  # This is a generic server class which accepts connections on a UNIX socket. On
  # receiving a connection, the server process forks and runs the specified block.
  #
  # ==Example
  #
  #   Jobby::Server.new("/tmp/jobby.socket", 3, "/var/log/jobby.log").run do
  #     # This code will be run in the forked children
  #     puts "#{Process.pid}: I'm toilet trained!"
  #   end
  #
  # ==Log rotation
  #
  # The server can receive USR1 signals as notification that the logfile has been 
  # rotated. This will close and re-open the handle to the log file. Since the
  # server process forks to produce children, they too can handle USR1 signals on
  # log rotation.
  #
  # To tell all Jobby processes that the log file has been rotated, use something 
  # like:
  # 
  #   % pkill -USR1 -f jobby
  #
  class Server
    def initialize(socket_path, max_forked_processes, log_path)
      @socket_path = socket_path
      @max_forked_processes = max_forked_processes.to_i
      @log_path = log_path
      @pids = []
    end

    # Starts the server and listens for connections. The specified block is run in the child processes. The message variable that is passed to the block is the message that is received from Client#send.
    def run(&block)
      connect_to_socket_and_start_logging
      loop do
        client = @socket.accept
        message = client.recvfrom(1024).first
        # start a new thread to handle the client so we can return quickly
        Thread.new do
          if @pids.length >= @max_forked_processes
            begin
              reap_child
            rescue Errno::ECHILD
            end
          end
          # fork and run code that performs the actual work
          @pids << fork do
            block.call(message)
            exit 0
          end
          reap_child
        end
      end
    end
    
    protected

    # Checks if a process is already listening on the socket. If not, removes the 
    # socket file (if it's there) and starts a server. Throws an Errno::EADDRINUSE
    # exception if an existing server is detected.
    def connect_to_socket_and_start_logging
      unless File.exists? @socket_path
        connect_to_socket
      else
        begin
          # test for a server on the socket
          test_socket = UNIXSocket.open(@socket_path)
          test_socket.close # got this far - seems like there is a server already
          raise Errno::EADDRINUSE.new("it seems like there is already a server listening on #{@socket_path}")
        rescue Errno::ECONNREFUSED
          # probably not a server on that socket - start one
          FileUtils.rm(@socket_path, :force => true)
          connect_to_socket
        end
      end
    end

    def connect_to_socket
      @socket = UNIXServer.open(@socket_path)
      FileUtils.chmod 0770, @socket_path
      @socket.listen 10
      start_logging
    end

    def start_logging
      @logger = Logger.new @log_path
      @logger.info "Server started at #{Time.now}"
      Signal.trap("USR1") do
        rotate_log
      end
    end

    def reap_child
      @pids.delete Process.wait
    end

    def rotate_log
      @logger.close
      @logger = Logger.new @log_path
      @logger.info "USR1 received, rotating log file"
    end
  end
end
