#Use bundler to load gems
require 'bundler'

#Load gems from Gemfile
Bundler.require

#Load the app
require_relative 'app.rb'

#Slim HTML formatting
Slim::Engine.set_options pretty: true, sort_attrs: false

#Run the app
run App
