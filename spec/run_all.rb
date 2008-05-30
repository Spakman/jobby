require 'rubygems'
require 'spec'

Dir.glob("#{File.dirname(__FILE__)}/*_spec.rb") do |spec|
  require spec
end
