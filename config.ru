require 'rubygems'
require 'vendor/sinatra/lib/sinatra.rb'

log_stdout = File.new('log/sinatra-stdout.log', 'a')
log_stderr = File.new('log/sinatra-stderr.log', 'a')
STDOUT.reopen(log_stdout)
STDERR.reopen(log_stderr)

set :run, false
set :environment, :production

require 'qualeaoperadora.rb'
run Sinatra::Application
