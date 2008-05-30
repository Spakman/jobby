require 'rubygems'
SPEC = Gem::Specification.new do |spec|
  spec.rubyforge_project = "jobby"
  spec.name = "jobby"
  spec.version = "0.1.0" 
  spec.author = "Mark Somerville"
  spec.email = "mark@scottishclimbs.com"
  spec.homepage = "http://mark.scottishclimbs.com/"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "Jobby is a small utility and library for managing running jobs in concurrent processes."
  candidates = Dir.glob("{bin,lib,spec}/**/*")
  puts candidates.inspect
  spec.files = candidates
  spec.executables = "jobby"
  spec.require_path = "lib"
  spec.has_rdoc = true
  spec.extra_rdoc_files = [ "README" ]
end
