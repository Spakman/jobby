require "#{File.dirname(__FILE__)}/../lib/dispatcher"

describe Jobby::Dispatcher do
  include Jobby

  before :each do
    ActiveRecord::Base.establish_connection(
      :database => "db/jobby.sqlite3",
      :adapter => "sqlite3"
    )
    Jobby::Job.delete_all
    @job = Jobby::Job.add(:test, "#{File.dirname(__FILE__)}/../lib/freelancers", 60, 1, [])
  end

  it "should fetch the next job and create the the correct freelancer" do
    Jobby::Dispatcher.dispatch_job
    Jobby::Job.find(@job.id).progress_message.should eql("Dangleberries are bad")
  end
end
