# encoding: utf-8
# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "yoga/version"

Gem::Specification.new do |spec|
  spec.name          = "yoga"
  spec.version       = Yoga::VERSION
  spec.authors       = ["Jeremy Rodi"]
  spec.email         = ["me@medcat.me"]

  spec.summary       = "Ruby scanner and parser helpers."
  spec.homepage      = "https://github.com/medcat/yoga"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mixture", "~> 0.6"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.13"
  spec.add_development_dependency "rubocop", "~> 0.47"
end
