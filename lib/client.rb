require "socket"
module Jobby
  class Client
    def initialize(socket_path, &block)
      @socket = UNIXSocket.open(socket_path)
      if block_given?
        yield(self)
        close
      end
    end
    
    def send(message = "")
      @socket.send(message, 0)
    end

    def close
      @socket.close
    end
  end
end
