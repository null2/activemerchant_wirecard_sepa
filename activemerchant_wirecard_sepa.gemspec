# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activemerchant_wirecard_sepa/version'

Gem::Specification.new do |spec|
  spec.name          = "activemerchant_wirecard_sepa"
  spec.version       = ActivemerchantWirecardSepa::VERSION
  spec.authors       = ["mdumke"]
  spec.email         = ["matthias.dumke@gmx.net"]
  spec.summary       = "Implements SEPA Payment processing via the Wirecard REST API"
  spec.description   = "Process payments via Wirecard using SEPA"
  spec.homepage      = "http://github.com/null2/active_merchant_wirecard_sepa.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "nokogiri"
  spec.add_development_dependency "pry"

  spec.add_dependency "rails-i18n"
  spec.add_dependency "net-sftp"
  spec.add_dependency "activesupport"
  spec.add_dependency "activemerchant"
end
