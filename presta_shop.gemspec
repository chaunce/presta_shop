# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'presta_shop/version'

Gem::Specification.new do |spec|
  spec.name          = 'presta_shop'
  spec.version       = PrestaShop::VERSION
  spec.authors       = ['chaunce']
  spec.email         = ['chaunce.slc@gmail.com']

  spec.summary       = %q{prestashop webservice api}
  spec.homepage      = 'https://github.com/chaunce/presta_shop'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_runtime_dependency 'rest-client', '~> 2.0'
  spec.add_runtime_dependency 'nokogiri', '~> 1.6'
  spec.add_runtime_dependency 'activesupport', '~> 5.0'

  spec.add_development_dependency 'bundler', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'webmock', '~> 2.1'
end
