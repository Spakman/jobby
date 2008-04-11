require "#{File.dirname(__FILE__)}/../lib/job"

describe Jobby::Job do
  include Jobby

  before :each do
    ActiveRecord::Base.establish_connection(
      :database => "db/jobby.sqlite3",
      :adapter => "sqlite3"
    )
    Jobby::Job.delete_all
    @freelancers_dir = "#{File.dirname(__FILE__)}/../lib/freelancers"
  end

  it "should be added to the database" do
    job = Jobby::Job.add(:test, @freelancers_dir, 60, 1, [])
    job.path_to_freelancers.should eql(File.expand_path(@freelancers_dir))
    job.freelancer.should eql("test")
    job.should be_kind_of(Jobby::Job)
    job.status.should eql("NEW")
    job.progress_message.should be_nil
    job.created_at.should_not be_nil
    job.started_at.should be_nil
  end

  it "should be able to be taken from the database" do
    low_priority_job = Jobby::Job.add(:test, @freelancers_dir, 60, 5, [])
    high_priority_job = Jobby::Job.add(:test, @freelancers_dir, 60, 1, [])
    job = Jobby::Job.next
    job.priority.should eql(high_priority_job.priority)
    job.status.should eql("RUNNING")
    job.started_at.should_not be_nil
  end

  it "should know if it's running or not" do
    high_priority_job = Jobby::Job.add(:test, @freelancers_dir, 60, 1, [])
    job = Jobby::Job.next
    job.running?.should eql(true)
  end

  it "should automatically marshall args" do
    low_priority_job = Jobby::Job.add(:test, @freelancers_dir, 60, 5, { :cheese => :good })
    job = Jobby::Job.find(low_priority_job.id)
    job.args.first[:cheese].should eql(:good)
  end
end
