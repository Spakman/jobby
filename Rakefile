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
  system "gem build jobby.gemspec"
  system "mv *.gem pkg/"
end

task :default => :spec
