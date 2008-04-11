require "#{File.dirname(__FILE__)}/../lib/job"
module Jobby
  class Freelancer
    attr_reader :job
    def initialize(job)
      @job = job
    end

    def progress_message=(message)
      @job.update_attribute(:progress_message, message)
    end

    def work
      raise "Sub-classes of Jobby::Freelancer should implement a work method."
    end

    def go_to_work
      begin
        @job.update_attributes(:started_at => Time.now, :status => "RUNNING")
        work
        @job.update_attribute(:status, "DONE")
      rescue Exception => exception
        mark_job_as_failed
      end
    end

    def mark_job_as_failed
      @job.update_attribute(:status, "ERROR")
    end
  end
end
