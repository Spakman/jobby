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
    terminate_server_and_wait_for_jobby!
    run_server(@socket, @max_child_processes, @log_filepath)
    wait_for_jobby!
    assert_raise Errno::ENOENT do
      lambda { UNIXSocket.open(@socket).close }.call
    end
  end
 
  def test_allows_children_to_log_within_called_block
    terminate_server_and_wait_for_jobby!
    run_server(@socket, @max_child_processes, @log_filepath) do |i, logger|
      logger.info "I can log!"
    end
    wait_for_jobby! 1
    client_socket = UNIXSocket.open(@socket)
    client_socket.send("hiya", 0)
    client_socket.close
    wait_for_jobby! 1
    assert_match /I can log!/, File.read(@log_filepath)
  end

  def test_accepts_IO_object_instead_of_a_log_filepath
    terminate_server_and_wait_for_jobby!
    io_filepath = File.expand_path("#{File.dirname(__FILE__)}/io_log_test.log")
    FileUtils.rm io_filepath, :force => true
    io = File.open(io_filepath, "w")
    run_server(@socket, @max_child_processes, io) {}
    terminate_server_and_wait_for_jobby!
    assert_equal 4, File.readlines(io_filepath).length
    FileUtils.rm io_filepath
  end


end
