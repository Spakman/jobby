desc "Run the specs (Deprecated - Will run Test::Unit tests instead)"
task :spec do
  exec "testrb test/run_all.rb"
end

desc "Run the tests"
task :test do
  exec 'testrb test/run_all.rb'
end

desc "Pushes to Rubyforge and GitHub"
task :push_all do
  system "git push jobby_rubyforge master"
  system "git push jobby_github master"
end

desc "Builds the gem"
task :build do
  if ENV["VERSION"].nil?
    puts "You didn't specify a version number in the environment variable VERSION"
    exit -1
  end
  system "find #{File.dirname(__FILE__)} -type d -exec chmod -R 755 {} \;"
  system "find #{File.dirname(__FILE__)} -type f -exec chmod -R 644 {} \;"
  system "chmod -R 755 #{File.dirname(__FILE__)}/bin/jobby"
  FileUtils.cp "jobby.gemspec", "jobby.gemspec.before_substitution", :preserve => true
  FileUtils.cp "bin/jobby", "jobby.before_substitution", :preserve => true
  system "sed -i 's/%%%VERSION%%%/#{ENV["VERSION"]}/g' jobby.gemspec bin/jobby"
  system "gem build jobby.gemspec"
  FileUtils.mv "jobby-#{ENV["VERSION"]}.gem", "pkg/"
  FileUtils.mv "jobby.gemspec.before_substitution", "jobby.gemspec", :force => true
  FileUtils.mv "jobby.before_substitution", "bin/jobby", :force => true
end

task :default => :test
