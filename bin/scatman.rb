# MOCKUP
# take next job
# update job row
# create freelancer
# work (updates row)
#

class Jobby::Dispatcher
  def self.start_work_on(job)
    worker = job.args[:freelancer].classity.constantize.new(job.args)
  end
end

class Jobby::Freelancer
  def initialize(job)
    @job = job
    @job.update_attributes(:started_at => Time.now, :status => "RUNNING")
  end

  def progress_message=(message)
    @job.update_attribute(:progress_message => message)
  end

  def work
    puts "reading file..."
    # update progress message
    puts "stuff"
    # update progress message
    sleep 10
    puts "done"
  end
end

Jobby::Dispatcher.start_work_on(Jobby::Job.next)
