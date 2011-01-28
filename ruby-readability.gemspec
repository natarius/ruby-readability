Gem::Specification.new do |s|
  s.authors = ["Fabio Mont Alegre", "Rodrigo Flores"]
  s.email = "it-team@busk.com"
  s.homepage = "http://github.com/busk/ruby-readability"
  s.version = "1.1.1"
  s.name = "busk-ruby-readability"
  s.summary = "A rewrite of original ruby-readability"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
