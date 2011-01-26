Gem::Specification.new do |s|
  s.authors = ["Spiceee"]
  s.email = "it-team@busk.com"
  s.homepage = "http://github.com/busk/ruby-readability"
  s.version = "1.0.7"
  s.name = "busk-ruby-readability"
  s.summary = "A rewrite of original ruby-readability"
  s.require_paths = ["lib", "spec", "spec/fixtures"]
  s.files = ["lib/readability.rb"] + Dir.glob("{spec}/**/*")
end
