desc "Run the specs"
task :spec do
  require "spec/run_all.rb"
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
  FileUtils.cp "jobby.gemspec", "jobby.gemspec.before_substitution"
  FileUtils.cp "bin/jobby", "jobby.before_substitution"
  system "sed -i 's/%%%VERSION%%%/#{ENV["VERSION"]}/g' jobby.gemspec bin/jobby"
  system "gem build jobby.gemspec"
  FileUtils.mv "jobby-#{ENV["VERSION"]}.gem", "pkg/"
  FileUtils.mv "jobby.gemspec.before_substitution", "jobby.gemspec", :force => true
  FileUtils.mv "jobby.before_substitution", "bin/jobby", :force => true
end

task :default => :spec
