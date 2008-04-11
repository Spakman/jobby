require "#{File.dirname(__FILE__)}/../lib/freelancer"

class TestFreelancer < Jobby::Freelancer
  def work; end
end

describe Jobby::Job do
  include Jobby

  before :each do
    ActiveRecord::Base.establish_connection(
      :database => "db/jobby.sqlite3",
      :adapter => "sqlite3"
    )
    Jobby::Job.delete_all
    @freelancers_dir = "#{File.dirname(__FILE__)}/../lib/freelancers"
    @job = Jobby::Job.add(:test, @freelancers_dir, 60, 5, { :cheese => :good })
    @freelancer = TestFreelancer.new(@job)
  end

  it "should be able to carry out a job" do
    @freelancer.go_to_work
  end

  it "should be able to update the progress message of a job" do
    @freelancer.progress_message = "Jobby rocks"
    Jobby::Job.find(@freelancer.job.id).progress_message.should eql("Jobby rocks")
  end

  it "should mark a job as completed" do
    @freelancer.go_to_work
    Jobby::Job.find(@freelancer.job.id).status.should eql("DONE")
  end

  it "should mark a job as errored when an unhandled exception is thrown" do
    class BadFreelancer < Jobby::Freelancer
      def work; raise; end
    end
    @freelancer = BadFreelancer.new(@job)
    @freelancer.go_to_work
    Jobby::Job.find(@freelancer.job.id).status.should eql("ERROR")
  end

  it "should be able to explicitly mark a job as failed" do
    @freelancer.mark_job_as_failed
    Jobby::Job.find(@freelancer.job.id).status.should eql("ERROR")
  end

  it "should be able to log messages"
  it "should write to the log when unhandled exceptions are thrown"
end
