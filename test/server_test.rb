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
 
  def test_should_read_all_of_the_sent_message
    terminate_server_and_wait_for_jobby!
    message = '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890'
    run_server(@socket, @max_child_processes, @log_filepath) do |input, l|
      File.open(@child_filepath, "a+") do |file|
        file << "#{input}"
      end
    end
    Jobby::Client.new(@socket) { |c| c.send(message) }
    wait_for_jobby!
    assert_equal message, File.read(@child_filepath)
  end

  def test_forks_off_a_child_and_runs_the_specified_code_upon_connection
    Jobby::Client.new(@socket) { |c| c.send("hiya") }
    wait_for_jobby!
    assert_not_equal @server_pid.to_s, File.read(@child_filepath)
  end

  def test_should_only_fork_of_a_maximum_of_chilren_and_queue_the_rest
    terminate_server
    run_server(@socket, @max_child_processes, @log_filepath) do
      wait_for_jobby! 2
      File.open(@child_filepath, "a+") do |file|
        file << "#{Process.pid}\n"
      end
    end
    (@max_child_processes + 2).times do |i|
      Thread.new do
        Jobby::Client.new(@socket) { |c| c.send("hiya") }
      end
    end
    wait_for_jobby! 2.5
    assert_equal @max_child_processes, File.readlines(@child_filepath).length
    wait_for_jobby! 4
    assert_equal (@max_child_processes + 2), File.readlines(@child_filepath).length
  end

  def test_stops_server_and_reaps_children_on_USR1_signal_receipt
    terminate_server_and_wait_for_jobby!
    run_server(@socket, 1, @log_filepath) do
      sleep 3
    end
    2.times do |i|
      Jobby::Client.new(@socket) { |c| c.send("hiya") }
    end
    wait_for_jobby!
    Process.kill "USR1", @server_pid
    wait_for_jobby! 1.5
    assert_raise Errno::ECONNREFUSED do
      lambda { Jobby::Client.new(@socket) { |c| c.send("hello?") } }.call
    end
    wait_for_jobby! 5
    assert_raise Errno::ENOENT do
      lambda { Jobby::Client.new(@socket) { |c| c.send("hello?") } }.call
    end
    assert_equal '2', `pgrep -f 'jobby spec' | wc -l`.strip
    assert_equal '1', `pgrep -f 'jobbyd spec' | wc -l`.strip
  end

  def test_can_execute_a_ruby_file_before_forking
    terminate_server
    ruby_file_path = File.expand_path(File.dirname(__FILE__) + '/file_for_prerunning.rb')
    assert File.exists?(ruby_file_path)
    run_server(@socket, 1, @log_filepath, Proc.new { |logger| load ruby_file_path }) do
      sleep 2
      if defined?(Preran)
        File.open(@child_filepath, "a+") do |file|
          file << "preran OK"
        end
      end
    end
    wait_for_jobby!
    Jobby::Client.new(@socket) { |c| c.send("hiya") }
    wait_for_jobby! 3
    assert_equal 'preran OK', File.read(@child_filepath)
  end
  
  def test_closes_all_inherited_file_descriptors_from_calling_processes
    terminate_server
    ruby_file_path = File.expand_path(File.dirname(__FILE__) + '/file_for_prerunning.rb')
    f = File.open(ruby_file_path, "r")
    run_server(@socket, 1, @log_filepath) do
      sleep 2
    end
    wait_for_jobby! 0.5
    assert_equal 7, Dir.entries("/proc/#{@server_pid}/fd/").length
    f.close
  end

end
