desc "Run the specs"
task :spec do
  require "spec/run_all.rb"
end

desc "Pushes to Rubyforge and GitHub"
task :push_all do
  system "git push jobby_rubyforge master"
  system "git push jobby_github master"
end

task :default => :spec
