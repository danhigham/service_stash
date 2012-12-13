require 'rubygems'
require 'bundler/setup'

require 'sidekiq'
require './init_redis'
require './lib/service_stash'

class ServiceWorker

  include Sidekiq::Worker

  def self.begin(job)
    self.perform_async job
  end

  def perform(job)
    service_stash = ServiceStash.new
    service_stash.backup_service job
  end

end