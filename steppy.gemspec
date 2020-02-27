# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'steppy/version'

Gem::Specification.new do |spec|
  spec.name          = 'steppy'
  spec.version       = Steppy::VERSION
  spec.authors       = ['cj']
  spec.email         = ['cjlazell@gmail.com']

  spec.summary       = %q()
  spec.description   = %q()
  spec.homepage      = 'https://github.com/cj/steppy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.1'
  spec.add_development_dependency 'reek', '~> 4.8.1'
  spec.add_development_dependency 'rubocop', '~> 0.52.1'
  spec.add_development_dependency 'rubocop-airbnb'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'super_awesome_print'
end
