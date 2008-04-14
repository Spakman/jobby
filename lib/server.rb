require 'fileutils'
require 'socket'

module Jobby
  class Server
    def initialize(socket_path, max_forked_processes, log_path)
      FileUtils.rm(socket_path, :force => true)
      @socket = UNIXServer.open(socket_path)
      FileUtils.chmod 0770, socket_path
      @socket.listen 10
      @pids = []
      @max_forked_processes = max_forked_processes
      @log_path = log_path
      @logger = Logger.new log_path
      Signal.trap("USR1") do
        puts "USR1 received by process #{Process.pid}, refreshing log file descriptors"
        rotate_log
      end
    end

    def run
      loop do
        client = @socket.accept
        message_struct = client.recvfrom(1024)
        if @pids.length > @max_forked_processes
          begin
            @pids.delete Process.wait
          rescue Errno::ECHILD
          end
        end
        # Fork and run code that performs the actual work
        @pids << fork do
          puts "run this job: #{message_struct.first}"
          @logger.info "#{Process.pid}: hello"
          sleep 3
        # Dispatcher.dispatch_job
        end
        reap_child
      end
    end
    
    def reap_child
      Thread.new do
        @pids.delete Process.wait
      end
    end

    def rotate_log
      @logger.close
      @logger = Logger.new @log_path
    end
  end
end
