require_relative "lib/ncpp/version"

Gem::Specification.new do |spec|
  spec.name = "NCPrePatcher"
  spec.version = NCPP::VERSION
  spec.authors = ["Will Smith"]
  spec.email = ["willsmithofficial2222@gmail.com"]

  spec.summary = "A preprocessor for NCPatcher"
  spec.homepage = "https://github.com/pete420griff/NCPrePatcher"
  spec.license = "GPL-3.0-only"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = { "source_code_uri" => "https://github.com/pete420griff/NCPrePatcher" }

  spec.add_dependency 'ffi', '~> 1.17', '>= 1.17.2'
  spec.add_dependency 'parslet', '~> 2.0'

  # Specifies which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[LICENSE.txt README.md {exe,lib,example}/**/*]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

end

