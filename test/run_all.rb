require File.dirname(__FILE__) + '/jobby_test_case.rb'

Dir.glob("#{File.dirname(__FILE__)}/*_test.rb") do |test|
  require test
end
