require 'activerecord'

module Jobby
  class Job < ActiveRecord::Base

    def self.add(freelancer, time_to_live, priority, *args)
      job = self.new
      job.time_to_live = time_to_live
      job.args = args
      job.status = "NEW"
      job.save!
      return job
    end

    def self.next
      job = self.find(:first, :conditions => [ 'status == "NEW"' ], :order => :priority)
      job.update_attributes(:status => "RUNNING", :started_at => Time.now)
      return job
    end

    def running?
      self.status == 'RUNNING'
    end

    def progress_message=(message)
      write_attribute(:progress_message, message)
      update_attribue(:progress_message, message)
    end

    def args
      unless @unmasrshalled_args
        @unmarshalled_args = Marshal.load(read_attribute(:args)).flatten
      end
      @unmarshalled_args
    end

    def args=(*something)
      write_attribute(:args, Marshal.dump(something))
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
    Jobby::Job.delete_all
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

  it "should know if it's running or not" do
    high_priority_job = Jobby::Job.add(:test_freelancer, 60, 1, [])
    job = Jobby::Job.next
    job.running?.should eql(true)
  end

  it "should automatically marshall args" do
    low_priority_job = Jobby::Job.add(:test_freelancer, 60, 5, { :cheese => :good })
    job = Jobby::Job.find(low_priority_job.id)
    job.args.first[:cheese].should eql(:good)
  end
end
