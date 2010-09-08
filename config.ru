require 'rubygems'
require 'vendor/sinatra/lib/sinatra.rb'

log = File.new('log/sinatra.log', 'w+')
STDOUT.reopen(log)
STDERR.reopen(log)

set :run, false
set :environment, :production

require 'qualeaoperadora.rb'
run Sinatra::Application
