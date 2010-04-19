require File.dirname(__FILE__) + '/jobby_test_case'
class Jobby::Server
  # Redefining STDIN, STDOUT and STDERR makes testing pretty savage
  def reopen_standard_streams; end
end

class ServerTest < JobbyTestCase

  def test_server_listens_on_a_unix_socket
    assert_nothing_raised do
      lambda { UNIXSocket.open(@socket).close }.call
    end
  end

  def test_server_throws_exception_if_something_already_listening_on_socket
    assert_raise Errno::EADDRINUSE do
      lambda { Jobby::Server.new(@socket, @max_child_processes, @log_filepath).run { true } }.call
    end
  end

  def test_server_sets_socket_permission_correctly
    assert_equal "770,socket", `stat --format=%a,%F #{@socket}`.strip
  end

  def test_server_logs_when_started
    assert_match /Server started at/, File.read(@log_filepath)
  end

  def test_flushes_and_reloads_log_when_HUP_recieved
    FileUtils.rm @log_filepath
    Process.kill "HUP", @server_pid
    wait_for_jobby! 0.2
    assert_match /# Logfile created on/, File.read(@log_filepath)  
  end

  def test_does_not_run_if_a_block_is_not_given
    terminate_server
    wait_for_jobby!
    run_server(@socket, @max_child_processes, @log_filepath)
    wait_for_jobby!
    assert_raise Errno::ENOENT do
      lambda { UNIXSocket.open(@socket).close }.call
    end
  end
 
end
