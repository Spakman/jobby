require "#{File.dirname(__FILE__)}/../lib/job"
module Jobby
  class Dispatcher
    def dispatch_job
      job = Jobby::Job.next
      require "#{job.path_to_freelancers}/#{job.freelancer}_freelancer"
      freelancer_class = job.freelancer+"_freelancer"
      freelancer_class = freelancer_class.classify.constantize
      freelancer_class.new(job).go_to_work
    end
  end
end
