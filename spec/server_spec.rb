require "#{File.dirname(__FILE__)}/../lib/server"
require "#{File.dirname(__FILE__)}/../lib/client"
require 'fileutils'
$0 = "jobby spec"


# Due to the multi-process nature of these specs, there are a bunch of sleep calls
# around. This is, of course, pretty brittle but I can't think of a better way of 
# handling it. If they start failing 'randomly', I would first start by increasing
# the sleep times.

describe Jobby::Server do

  def run_server(socket, max_child_processes, log_filepath, &block)
    @server_pid = fork do
      Jobby::Server.new(socket, max_child_processes, log_filepath).run(&block)
    end
    sleep 0.2
  end

  def terminate_server
    Process.kill 15, @server_pid
    if File.exists? @child_filepath
      FileUtils.rm @child_filepath
    end
    FileUtils.rm @log_filepath, :force => true
    sleep 0.5
  end

  before :all do
    @socket = File.expand_path("#{File.dirname(__FILE__)}/jobby_server.sock")
    @max_child_processes = 2
    @log_filepath = File.expand_path("#{File.dirname(__FILE__)}/jobby_server.log")
    @child_filepath = File.expand_path("#{File.dirname(__FILE__)}/jobby_child")
  end

  before :each do
    run_server(@socket, @max_child_processes, @log_filepath) {
      File.open(@child_filepath, "a+") do |file|
        file << "#{Process.pid}"
      end
    }
  end

  after :each do
    terminate_server
  end

  after :all do
    FileUtils.rm @socket, :force => true
  end

  it "should listen on a UNIX socket" do
    lambda { UNIXSocket.open(@socket).close }.should_not raise_error
  end

  it "should allow the children to log from within the called block" do
    terminate_server
    sleep 0.5
    run_server(@socket, @max_child_processes, @log_filepath) { |input, logger|
      logger.info "I can log!"
    }
    sleep 1
    client_socket = UNIXSocket.open(@socket)
    client_socket.send("hiya", 0)
    client_socket.close
    sleep 1
    File.read(@log_filepath).should match(/I can log!/)
  end

  it "should throw an exception if there is already a process listening on the socket" do
    lambda { Jobby::Server.new(@socket, @max_child_processes, @log_filepath).run { true } }.should raise_error(Errno::EADDRINUSE, "Address already in use - it seems like there is already a server listening on #{@socket}")
  end

  it "should set the correct permissions on the socket file" do
    `stat --format=%a,%F #{@socket}`.strip.should eql("770,socket")
  end

  it "should log when it is started" do
    File.read(@log_filepath).should match(/Server started at/)
  end

  it "should be able to accept an IO object instead of a log filepath" do
    terminate_server
    sleep 1
    io_filepath = File.expand_path("#{File.dirname(__FILE__)}/io_log_test.log")
    FileUtils.rm io_filepath, :force => true
    io = File.open(io_filepath, "a+")
    run_server(@socket, @max_child_processes, io) {}
    terminate_server
    sleep 0.5
    File.readlines(io_filepath).length.should eql(1)
    FileUtils.rm io_filepath
  end

  it "should flush and reload the log file when it receieves the USR1 signal" do
    FileUtils.rm @log_filepath
    Process.kill "USR1", @server_pid
    sleep 0.2
    File.read(@log_filepath).should match(/USR1 received, rotating log file/)
  end

  it "should not run if a block is not given" do
    terminate_server
    sleep 0.5
    run_server(@socket, @max_child_processes, @log_filepath)
    sleep 0.5
    lambda { UNIXSocket.open(@socket).close }.should raise_error
  end
  
  it "should read all of the provided message" do
    terminate_server
    sleep 0.5
    run_server(@socket, @max_child_processes, @log_filepath) { |input, logger|
      File.open(@child_filepath, "a+") do |file|
        file << "#{input}"
      end
    } 
    Jobby::Client.new(@socket) { |c| c.send("1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890") }
    sleep 0.5
    File.read(@child_filepath).should eql("1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
  end

  it "should fork off a child and run the specified code when it receives a connection" do
    Jobby::Client.new(@socket) { |c| c.send("hiya") }
    sleep 0.2
    File.read(@child_filepath).should_not eql(@server_pid.to_s)
  end

  it "should only fork off a certain number of children - the others should have to wait (in an internal queue)" do
    terminate_server
    run_server(@socket, @max_child_processes, @log_filepath) do
      sleep 2
      File.open(@child_filepath, "a+") do |file|
        file << "#{Process.pid}\n"
      end
    end
    (@max_child_processes + 2).times do |i|
      Thread.new do
        Jobby::Client.new(@socket) { |c| c.send("hiya") }
      end
    end
    sleep 2.5
    File.readlines(@child_filepath).length.should eql(@max_child_processes)
    sleep 4
    File.readlines(@child_filepath).length.should eql(@max_child_processes + 2)
  end

  it "should receive a flush command from the client and terminate while the children continue processing" do
    terminate_server
    sleep 1
    run_server(@socket, 1, @log_filepath) do
      sleep 2
    end
    2.times do |i|
      Jobby::Client.new(@socket) { |c| c.send("hiya") }
    end
    sleep 1
    Jobby::Client.new(@socket) { |c| c.send("||JOBBY FLUSH||") }
    sleep 1.5
    lambda { Jobby::Client.new(@socket) { |c| c.send("hello?") } }.should raise_error(Errno::ENOENT)
    `pgrep -f 'jobby spec' | wc -l`.strip.should eql("2")
  end

  it "should receive a wipe command from the client and terminate, taking the children with it" do
    terminate_server
    run_server(@socket, 1, @log_filepath) do
      sleep 2
    end
    2.times do |i|
      Jobby::Client.new(@socket) { |c| c.send("hiya") }
    end
    sleep 1
    Jobby::Client.new(@socket) { |c| c.send("||JOBBY WIPE||") }
    sleep 2.5
    lambda { Jobby::Client.new(@socket) { |c| c.send("hello?") } }.should raise_error(Errno::ENOENT)
    `pgrep -f 'jobby spec'`.strip.should eql("#{Process.pid}")
  end
end
