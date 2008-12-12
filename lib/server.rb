# Copyright (C) 2008  Mark Somerville
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require 'fileutils'
require 'socket'
require 'logger'
require 'thread'

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
  # ==Stopping the server
  #
  # There are two built-in ways of stopping the server:
  #
  #   SIGUSR1    will stop the server accepting any more connections, but it 
  #              will continue to fork if there are any requests in the queue. 
  #              It will then wait for the children to exit before terminating.
  #
  #   SIGTERM    will stop the server forking any more children, kill 9 any 
  #              existing children and terminate it.
  #
  # ==Log rotation
  #
  # The server can receive SIGHUP as notification that the logfile has been 
  # rotated. This will close and re-open the handle to the log file. Since the
  # server process forks to produce children, they too can handle SIGHUP on log 
  # rotation.
  #
  # To tell all Jobby processes that the log file has been rotated, use something 
  # like:
  # 
  #   % pkill -HUP -f jobby
  #
  class Server
    # The log parameter can be either a filepath or an IO object.
    def initialize(socket_path, max_forked_processes, log, prerun = nil)
      $0 = "jobbyd: #{socket_path}" # set the process name
      @log = log.path rescue log
      reopen_standard_streams
      close_fds
      start_logging
      @socket_path = socket_path
      @max_forked_processes = max_forked_processes.to_i
      @queue = Queue.new
      setup_signal_handling
      prerun.call(@logger) unless prerun.nil?
    end

    # Starts the server and listens for connections. The specified block is run in 
    # the child processes. When a connection is received, the input parameter is 
    # immediately added to the queue.
    def run(&block)
      try_to_connect_to_socket
      unless block_given?
        @logger.error "No block given, exiting"
        terminate
      end
      start_forking_thread(block)
      loop do
        client = @socket.accept
        input = ""
        while bytes = client.read(128)
          input += bytes
        end
        client.close
        @queue << input
      end
    end

    protected

    # Reopens STDIN (/dev/null), STDOUT and STDERR (both @log).
    def reopen_standard_streams
      $stdin.reopen("/dev/null", "r")
      # @log is either a string or an IO object
      if @log.respond_to? :close
        $stdout.reopen(@log)
        $stderr.reopen(@log)
      else
        $stdout.reopen(@log, "w")
        $stderr.reopen(@log, "w")
      end
    end

    # This closes all file descriptors for this process except STDIN, STDOUT 
    # and STDERR. This is because we might have inherited some FDs from the 
    # calling process, which we don't want.
    def close_fds
      Dir.entries("/dev/fd/").each do |file|
        unless file == '.' or file == '..' or file.to_i < 3
          IO.new(file.to_i).close rescue nil
        end
      end
    end

    # Traps SIGHUP, SIGTERM and SIGUSR1 for log rotation, immediate shutdown 
    # and very pleasant shutdown.
    def setup_signal_handling
      Signal.trap("HUP") do
        @logger.info "HUP signal received"
        rotate_log
      end
      Signal.trap("TERM") do
        @logger.info "TERM signal received"
        @socket.close unless @socket.closed?
        @queue.clear
        terminate_children
        terminate
      end
      Signal.trap("USR1") do
        @logger.info "USR1 signal received"
        wait_for_children_to_return
        terminate
      end
    end

    # Runs a thread to manage the forked processes. It will block, waiting for a 
    # child to finish if the maximum number of forked processes are already 
    # running. It will then, read from the queue and fork off a new process.
    #
    # The input variable that is passed to the block is the message that is 
    # received from Client#send.
    def start_forking_thread(block)
      Thread.new do
        @pids = []
        loop do
          if @pids.length >= @max_forked_processes
            begin
              reap_child
            rescue Errno::ECHILD
            end
          end
          # fork and run code that performs the actual work
          input = @queue.pop
          @pids << fork do
            @socket.close unless @socket.closed? # inherited from the Jobby::Server
            # re-trap TERM to simply exit, since it is inherited from the Jobby::Server
            Signal.trap("TERM") do
              @logger.info "Terminating child process #{Process.pid}"
              exit 0
            end
            Signal.trap("USR1") {}
            $0 = "jobby: #{@socket_path}" # set the process name
            @logger.info "Child process started (#{Process.pid})"
            block.call(input, @logger)
            exit 0
          end
          Thread.new do
            reap_child
          end
        end
      end
    end
    
    # Checks if a process is already listening on the socket. If not, removes the 
    # socket file (if it's there) and starts a server. Throws an Errno::EADDRINUSE
    # exception if an existing server is detected.
    def try_to_connect_to_socket
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
    end

    def start_logging
      @logger = Logger.new @log
      @logger.info "Server started at #{Time.now}"
    end

    def reap_child
      @pids.delete Process.wait
    end

    def rotate_log
      @logger.info "Rotating log file"
      @logger.close
      @logger = Logger.new @log
    end

    # Closes the socket and waits for any children to finish before 
    # terminating. New children that are already in the queue may be 
    # still be forked at this stage.
    def wait_for_children_to_return
      @socket.close
      while @pids.length > 0
        sleep 1
      end
    end

    # Cleans up the server and exits the process with a return code 0.
    def terminate
      @queue.clear
      @logger.info "Terminating server #{Process.pid}"
      @socket.close unless @socket.closed?
      FileUtils.rm(@socket_path, :force => true)
      exit! 0
    end
    
    # Stops any more children being forked and terminates the existing ones. A kill
    # 9 signal is used as you will likely be run when termination is needed 
    # immediately, perhaps due to 'runaway' children.
    def terminate_children
      @queue.clear
      @logger.info "Terminating forked children"
      @pids.each do |pid|
        begin
          Process.kill 15, pid
        rescue Errno::ESRCH
        end
      end
    end
  end
end
