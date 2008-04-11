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
