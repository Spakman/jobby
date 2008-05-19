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
  # A client process can send one of two special strings to stop the server. 
  #
  #   "||JOBBY FLUSH||"   will stop the server forking any more children and shut
  #                       it down.
  #
  #   "||JOBBY WIPE||"    will stop the server forking any more children, kill 9 
  #                       any existing children and shut it down.
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
    def initialize(socket_path, max_forked_processes, log)
      @socket_path = socket_path
      @max_forked_processes = max_forked_processes.to_i
      @log = log
      @queue = Queue.new
    end

    # Starts the server and listens for connections. The specified block is run in 
    # the child processes. When a connection is received, the input parameter is 
    # immediately added to the queue.
    def run(&block)
      connect_to_socket_and_start_logging
      unless block_given?
        @logger.error "No block given, exiting"
        terminate
      end
      start_forking_thread(block)
      loop do
        client = @socket.accept
        input = ""
        begin
          while client.recv_nonblock(128, Socket::MSG_PEEK)
            input += client.recv_nonblock(128)
          end
        rescue Errno::EAGAIN
        end
        if input == "||JOBBY FLUSH||"
          terminate
        elsif input == "||JOBBY WIPE||"
          terminate_children
          terminate
        else
          @queue << input
        end
        client.close
      end
    end

    protected

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
            $0 = "jobby: child" # set the process name
            @logger.info "Child process started (#{Process.pid})"
            block.call(input)
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
      @logger = Logger.new @log
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
      @logger = Logger.new @log
      @logger.info "USR1 received, rotating log file"
    end

    # Cleans up the server and exits the process with a return code 0.
    def terminate
      @queue.clear
      @logger.info "Flush received - terminating server"
      @socket.close
      FileUtils.rm(@socket_path, :force => true)
      exit! 0
    end
    
    # Stops any more children being forked and terminates the existing ones. A kill
    # 9 signal is used as you will likely be run when termination is needed 
    # immediately, perhaps due to 'runaway' children.
    def terminate_children
      @queue.clear
      @logger.info "Wipe received - terminating forked children"
      @pids.each do |pid|
        begin
          Process.kill 9, pid
        rescue Errno::ESRCH
        end
      end
    end
  end
end
