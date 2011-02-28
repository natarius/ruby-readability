require 'rubygems'
require 'readability'
require 'bundler'

Bundler.setup(:test)

require 'open-uri'
require 'fakeweb'

require 'vcr'

RSpec.configure do |c|
  c.extend VCR::RSpec::Macros
end

VCR.config do |c|
  c.cassette_library_dir     = 'spec/fixtures/cassettes'
  c.stub_with                :fakeweb
end