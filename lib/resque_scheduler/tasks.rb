require 'resque/tasks'
# will give you the resque tasks

namespace :resque do
  task :setup

  desc "Start Resque Scheduler"
  task :scheduler => :scheduler_setup do
    require 'resque'
    require 'resque_scheduler'

    # Need to set this here for conditional Process.daemon redirect of stderr/stdout to /dev/null
    Resque::Scheduler.mute = true if ENV['MUTE'] 

    if ENV['BACKGROUND']
      unless Process.respond_to?('daemon')
        abort "env var BACKGROUND is set, which requires ruby >= 1.9"
      end
      Process.daemon(true,!Resque::Scheduler.mute)
    end

    File.open(ENV['PIDFILE'], 'w') { |f| f << Process.pid.to_s } if ENV['PIDFILE']

    Resque::Scheduler.dynamic = true if ENV['DYNAMIC_SCHEDULE']
    Resque::Scheduler.verbose = true if ENV['VERBOSE']
    Resque::Scheduler.run
  end

  task :scheduler_setup do
    if ENV['INITIALIZER_PATH']
      load ENV['INITIALIZER_PATH'].to_s.strip
    else
      Rake::Task['resque:setup'].invoke
    end
  end

  desc "Generate reverted index to fetch timestamps associated to jobs"
  task :migrate do
    redis = Resque.redis
    redis.zrange("resque:delayed_queue_schedule", 0, -1).each { |timestamp|
      timestamp = timestamp.to_i
      key = "resque:delayed:%d" % timestamp
      redis.lrange(key, 0, -1).each { |job_hash|
        key = "resque:timestamps:%s" % job_hash
        redis.rpush(key, timestamp)
      }
    }
  end

end
