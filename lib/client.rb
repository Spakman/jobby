# Copyright (C) 2008-2010 Mark Somerville <mark@scottishclimbs.com>
# Released under the Lesser General Public License (LGPL) version 3.
# See COPYING.

require 'socket'

module Jobby
  class Client
    # Creates a new client. Passing a block here is a shortcut for calling send and then close.
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
