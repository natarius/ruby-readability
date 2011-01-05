$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'readability'
require 'spec'
require 'spec/autorun'
require 'nokogiri'
require 'open-uri'
require 'fakeweb'

Spec::Runner.configure do |config|

end
