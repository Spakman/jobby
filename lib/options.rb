options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: jobby [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |verbose|
    options[:verbose] = verbose
  end

  opts.on("-h", "--help", "Show this message") do
    puts opts
    exit
  end

  opts.on("--version", "Show version") do
    puts "brand spanking!"
    exit
  end

  opts.on("-s", "--socket [SOCKETFILE]", "Connect to this UNIX socket") do |socket|
    options[:socket] = socket
  end

  opts.on("-i", "--input [INPUT]", "Pass this string to the child process (can be used instead of STDIN)") do |input|
    options[:input] = input
  end

  opts.on("-f", "--flush", "Shutdown the server on the specified socket") do |flush|
    options[:flush] = flush
    options[:input] = "||JOBBY FLUSH||"
  end

  opts.on("-w", "--wipe", "Shutdown the server and terminate the children on the specified socket immediately") do |wipe|
    options[:wipe] = wipe
    options[:input] = "||JOBBY WIPE||"
  end

  opts.separator ""
  opts.separator "Server options:"

  opts.on("-l", "--log [LOGFILE]", "Log to this file") do |logfile|
    options[:log] = logfile
  end

  opts.on("-m", "--max-children [MAXCHILDREN]", "Run MAXCHILDREN forked processes at any one time") do |forked_children|
    options[:max_child_processes] = forked_children.to_i
  end

  opts.on("-u", "--user [USER]", "Run the processes as this user (probably requires superuser priviledges)") do |user|
    options[:user] = user
  end

  opts.on("-g", "--group [GROUP]", "Run the processes as this group (probably requires superuser priviledges)") do |group|
    options[:group] = group
  end

  opts.on("-r", "--ruby [RUBY]", "Run this Ruby code in the forked children") do |ruby|
    options[:ruby] = ruby
  end

  opts.on("-c", "--command [COMMAND]", "Run this shell code in the forked children") do |command|
    options[:command] = command
  end
end.parse!

default_options = {}
default_options[:socket] = "/tmp/jobby.socket"
if options[:input].nil?
  message "--input not supplied, reading from STDIN (use ctrl-d to end input)"
  default_options[:input] = $stdin.read
end
default_options[:log] = $stderr
default_options[:max_child_processes] = 1
options = default_options.merge options

# Setup the the Proc object that gets run in the forked processes
# 'input' is specified on the command line with --input or STDIN
if not options[:ruby].nil? and not options[:command].nil?
  error "You can only specify --ruby or --command, not both"
  exit
elsif options[:ruby]
  if File.file?(File.expand_path(options[:ruby]))
    options[:block_to_run] = lambda { |input| 
      load File.expand_path(options[:ruby])
    }
  else
    options[:block_to_run] = lambda { |input| 
      eval(options[:ruby])
    }
  end
elsif options[:command]
  options[:block_to_run] = lambda { |input| 
    exec("#{options[:command].gsub('"', '\"')}")
  }
end
