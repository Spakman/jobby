require "#{File.dirname(__FILE__)}/../lib/server"
require 'fileutils'

# Due to the multi-process nature of these specs, there are a bunch of sleep calls
# around. This is, of course, pretty brittle but I can't think of a better way of 
# handling it. If they start failing 'randomly', I would first start by increasing
# the sleep times.

describe Jobby::Server do

  def run_server(socket, max_child_processes, log_filepath, &block)
    @server_pid = fork do
      Jobby::Server.new(socket, max_child_processes, log_filepath).run { block.call}
    end
    sleep 0.2
  end

  def terminate_server
    Process.kill 15, @server_pid
    FileUtils.rm @log_filepath
    if File.exists? @child_filepath
      FileUtils.rm @child_filepath
    end
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
      exit 0 # this makes sure the child process is terminated before carrying on and running specs (since it is forked)
    }
  end

  after :each do
    terminate_server
  end

  after :all do
    FileUtils.rm @socket
  end

  it "should listen on a UNIX socket" do
    lambda { UNIXSocket.open(@socket).close }.should_not raise_error
  end

  it "should set the correct permissions on the socket file" do
    `stat --format=%a,%F #{@socket}`.strip.should eql("770,socket")
  end

  it "should set the correct ownership on the socket file"

  it "should log when it is started" do
    File.read(@log_filepath).should match(/Server started at/)
  end

  it "should flush and reload the log file when it receieves the USR1 signal" do
    FileUtils.rm @log_filepath
    Process.kill "USR1", @server_pid
    sleep 0.2
    File.read(@log_filepath).should match(/USR1 received, rotating log file/)
  end

  it "should fork off a child and run the specified code when it receives a connection" do
    socket = UNIXSocket.open(@socket)
    socket.send("hiya", 0)
    sleep 0.2
    File.read(@child_filepath).should eql((@server_pid.to_i + 1).to_s)
  end

  it "should only fork off a certain number of children - the others should have to wait" do
    terminate_server
    run_server(@socket, @max_child_processes, @log_filepath) do
      File.open(@child_filepath, "a+") do |file|
        file << "#{Process.pid}\n"
      end
      sleep 2
      exit 0 # this makes sure the child process is terminated before carrying on and running specs (since it is forked)
    end
    (@max_child_processes + 1).times do |i|
      Thread.new do
        socket = UNIXSocket.open(@socket)
        socket.send("hiya", 0)
      end
    end
    sleep 0.5
    File.readlines(@child_filepath).length.should eql(@max_child_processes)
    sleep 2
    File.readlines(@child_filepath).length.should eql(@max_child_processes + 1)
  end
end
