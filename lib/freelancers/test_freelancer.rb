require "#{File.dirname(__FILE__)}/../freelancer"
class TestFreelancer < Jobby::Freelancer
  def work
    @job.progress_message = "Dangleberries are bad"
  end
end
