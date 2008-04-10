require 'activerecord'

module Jobby
  class Job < ActiveRecord::Base
    def self.add(freelancer, time_to_live, priority, *args)
      job = self.new
      job.time_to_live = time_to_live
      job.args = Marshal.dump(args)
      job.status = "NEW"
      job.save!
      return job
    end

    def self.next
      job = self.find(:first, :conditions => [ 'status == "NEW"' ], :order => :priority)
      job.update_attributes(:status => "RUNNING", :started_at => Time.now)
      return job
    end
  end
end

describe Jobby::Job do
  include Jobby

  before :each do
    ActiveRecord::Base.establish_connection(
      :database => "db/jobby.sqlite3",
      :adapter => "sqlite3"
    )
  end

  it "should be added to the database" do
    job = Jobby::Job.add(:test_freelancer, 60, 1, [])
    job.should be_kind_of(Jobby::Job)
    job.status.should eql("NEW")
    job.progress_message.should be_nil
    job.created_at.should_not be_nil
    job.started_at.should be_nil
  end

  it "should be able to be taken from the database" do
    low_priority_job = Jobby::Job.add(:test_freelancer, 60, 5, [])
    high_priority_job = Jobby::Job.add(:test_freelancer, 60, 1, [])
    job = Jobby::Job.next
    job.priority.should eql(high_priority_job.priority)
    job.status.should eql("RUNNING")
    job.started_at.should_not be_nil
  end

  it "should be able to have the progress updated"
end
