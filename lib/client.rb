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
    
    # Sends a message to the socket.
    def send(message = "")
      @socket.send(message, 0)
    end

    def close
      @socket.close
    end
  end
end
