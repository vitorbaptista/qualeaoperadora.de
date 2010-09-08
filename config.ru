require 'rubygems'
require 'vendor/sinatra/lib/sinatra.rb'

set :run, false
set :environment, :production

require 'qualeaoperadora.rb'
run Sinatra::Application
