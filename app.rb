#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'clockwork'

require './service_worker'
require './lib/service_stash'

include Clockwork

`chmod +x ./bin/*` # make everything in bin executable!

service_stash = ServiceStash.new

handler do |frequency|

  puts "Running #{frequency}"
  jobs = service_stash.jobs(frequency)

  jobs.each do |job|
    ServiceWorker.begin job
  end

end

every(1.hour, :hour)
every(1.day, :day)
every(1.week, :week)

Clockwork::run