require 'test/unit'
require "#{File.dirname(__FILE__)}/../lib/server"
require "#{File.dirname(__FILE__)}/../lib/client"
require 'fileutils'

# Since we need to test a lot of multiprocess stuff, it's neater to have 
# things like sleeps and friends available to all of our tests, so we
# extend test/unit's test case to include some helpful methods
#
class JobbyTestCase < Test::Unit::TestCase

  def setup
    prepare_jobby_values!
    $0 = "jobby spec"
    run_server(@socket, @max_child_processes, @log_filepath) do
      File.open(@child_filepath, "a+") do |file|
        file << "#{Process.pid}"
      end
    end
    wait_for_jobby!
  end

  def teardown
    terminate_server
    FileUtils.rm @socket, :force => true
  end

  def test_jobby_environment_is_set_up
    assert !@socket.nil?
    assert_equal 2, @max_child_processes 
    assert !@log_filepath.nil?
    assert !@child_filepath.nil?
  end

  protected

  def wait_for_jobby!(time = 0.5)
    sleep time
  end

  def prepare_jobby_values!
    @socket = File.expand_path("#{File.dirname(__FILE__)}/jobby_server.sock")
    @max_child_processes = 2
    @log_filepath = File.expand_path("#{File.dirname(__FILE__)}/jobby_server.log")
    @child_filepath = File.expand_path("#{File.dirname(__FILE__)}/jobby_child")
  end

  def run_server(socket, max_child_processes, log_filepath, prerun = nil, &block)
    @server_pid = fork do
      Jobby::Server.new(socket, max_child_processes, log_filepath, prerun).run(&block)
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


end
