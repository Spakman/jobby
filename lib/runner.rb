module Jobby
  class Runner
    DEFAULT_OPTIONS = {}
    DEFAULT_OPTIONS[:socket] = "/tmp/jobby.socket"
    DEFAULT_OPTIONS[:log] = $stderr
    DEFAULT_OPTIONS[:max_child_processes] = 1
    DEFAULT_OPTIONS[:exit_on_error] = true

    def initialize(options = {})
      @options = DEFAULT_OPTIONS.merge options
      if @options[:wipe]
        @options[:input] = "||JOBBY WIPE||"
      elsif @options[:flush]
        @options[:input] = "||JOBBY FLUSH||"
      elsif @options[:input].nil?
        message "--input not supplied, reading from STDIN (use ctrl-d to end input)"
        @options[:input] = $stdin.read
      end
    end

    # Tries to connect a client to the server. If there isn't a server detected on
    # the socket this process is forked and a server is started. Then, another 
    # client tries to connect to the server.
    #
    # We may consider using fork and exec instead of just fork since COW [1] 
    # semantics are broken using Ruby 1.8.x. There is a patch, for those who can
    # use it [2].
    #
    # [1] - http://blog.beaver.net/2005/03/ruby_gc_and_copyonwrite.html
    #
    # [2] - http://izumi.plan99.net/blog/index.php/2008/01/14/making-ruby’s-garbage-collector-copy-on-write-friendly-part-7/
    #
    # TODO: this code is pretty ugly.
    def run
      change_process_ownership
      begin
        if @options[:flush] or @options[:wipe]
          if @options[:wipe]
            message "Stopping Jobby server and terminating forked children..."
          else
            message "Stopping Jobby server..."
          end
        end
        run_client
      rescue Errno::EACCES => exception
        return error(exception.message)
      rescue Errno::ENOENT, Errno::ECONNREFUSED
        message "There doesn't seem to be a server listening on #{@options[:socket]} - starting one..." if @options[:verbose]
        # Connect failed, fork and start the server process
        exit if @options[:flush] or @options[:wipe]
        fork do
          begin
            Jobby::Server.new(@options[:socket], @options[:max_child_processes], @options[:log]).run(&get_proc_from_options)
          rescue Exception => exception
            return error(exception.message)
          end
        end
        sleep 2 # give the server time to start
        begin
          run_client
        rescue Errno::ECONNREFUSED
          return error("Couldn't connect to the server process")
        end
      end
    end

    protected

    # Creates a client and gets it to try to send a message to the Server on 
    # @options[:socket]. If this doesn't succeed, either a Errno::EACCES, 
    # Errno::ENOENT or Errno::ECONNREFUSED will probably be raised.
    def run_client
      message "Trying to connect to server on #{@options[:socket]}..." if @options[:verbose]
      Jobby::Client.new(@options[:socket]) { |client| client.send(@options[:input]) }
      message "Client has run successfully!" if @options[:verbose]
    end

    # Creates a Proc object that will be run by any children that the Server forks.
    # The input parameter that is passed to the Proc is the input string that a
    # Client will send to the server.
    def get_proc_from_options
      if @options[:ruby].nil? and @options[:command].nil?
        return error("No server found on #{@options[:socket]} and you didn't give --ruby or --command to execute")

      elsif not @options[:ruby].nil? and not @options[:command].nil?
        return error("You can only specify --ruby or --command, not both")

      elsif @options[:ruby] # can be either some Ruby code or a filepath
        if File.file?(File.expand_path(@options[:ruby]))
          return lambda { |input|
            load File.expand_path(@options[:ruby])
          }
        else
          return lambda { |input|
            eval(@options[:ruby])
          }
        end

      elsif @options[:command]
        return lambda { |input|
          exec("#{@options[:command].gsub('"', '\"')}")
        }
      end
    end

    # Changes the user and group ownership of the current process if 
    # @options[:user] or @options[:group] are set. This might be a privileged 
    # operation.
    def change_process_ownership
      begin
        if @options[:group]
          message "Setting group ownership to #{@options[:group]}..." if @options[:verbose]
          Process::GID.change_privilege Etc.getgrnam(@options[:group]).gid
        end
        if @options[:user]
          message "Setting user ownership to #{@options[:user]}..." if @options[:verbose]
          Process::UID.change_privilege Etc.getpwnam(@options[:user]).uid
        end
      rescue Errno::EPERM
        return error("You don't have permission to change the process ownership - perhaps you should be root?")
      end
    end

    def error(text)
      puts "  ERROR - #{text}"
      exit -1 if @options[:exit_on_error]
      return false
    end

    def message(text)
      puts "  #{text}"
    end
  end
end
