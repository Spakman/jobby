require 'fileutils'
require 'socket'
require 'logger'

module Jobby
  class Server
    def initialize(socket_path, max_forked_processes, log_path)
      FileUtils.rm(socket_path, :force => true)
      @socket = UNIXServer.open(socket_path)
      FileUtils.chmod 0770, socket_path
      @socket.listen 10
      @pids = []
      @max_forked_processes = max_forked_processes.to_i
      @log_path = log_path
      @logger = Logger.new log_path
      @logger.info "Server started at #{Time.now}"
      Signal.trap("USR1") do
        rotate_log
      end
    end

    def run(&block)
      loop do
        client = @socket.accept
        message_struct = client.recvfrom(1024)
        if @pids.length >= @max_forked_processes
          begin
            @pids.delete Process.wait
          rescue Errno::ECHILD
          end
        end
        # Fork and run code that performs the actual work
        @pids << fork do
          block.call
        end
        reap_child
      end
    end
    
    protected

    def reap_child
      Thread.new do
        @pids.delete Process.wait
      end
    end

    def rotate_log
      @logger.close
      @logger = Logger.new @log_path
      @logger.info "USR1 received, rotating log file"
    end
  end
end
