require 'rubygems'
require 'bundler/setup'
require 'httparty'

class Superhug
  include HTTParty
  base_uri 'localhost:3000'
end
