require "fileutils"
require "socket"
module Jobby
  class Server
    def initialize(socket_path, max_forked_processes)
      FileUtils.rm(socket_path, :force => true)
      @socket = UNIXServer.open(socket_path)
      FileUtils.chmod 0770, socket_path
      @socket.listen 10
      @pids = []
      @max_forked_processes = max_forked_processes
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
          # require 'program that know how to handle a message'
          puts "run this job: #{message_struct.first}"
        end
        reap_child
      end
    end
    
    def reap_child
      Thread.new do
        @pids.delete Process.wait
      end
    end
  end
end
