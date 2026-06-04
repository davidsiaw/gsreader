# frozen_string_literal: true

require_relative 'lib/gsreader/version'

Gem::Specification.new do |spec|
  spec.name          = 'gsreader'
  spec.version       = GsReader::VERSION
  spec.authors       = ['David Siaw']
  spec.email         = ['874280+davidsiaw@users.noreply.github.com']

  spec.summary       = 'Read and write Google Sheets with a Hash-like API'
  spec.description   = 'Tiny convenience wrappers around the Google Sheets v4 API ' \
                       'that let you treat a spreadsheet like a Hash keyed by A1 notation.'
  spec.homepage      = 'https://github.com/davidsiaw/gsreader'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/davidsiaw/gsreader'
  spec.metadata['changelog_uri'] = 'https://github.com/davidsiaw/gsreader'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir['{exe,data,lib}/**/*'] + %w[Gemfile gsreader.gemspec]
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'google-apis-sheets_v4', '~> 0.40'
  spec.add_dependency 'googleauth', '~> 1.8'
end
