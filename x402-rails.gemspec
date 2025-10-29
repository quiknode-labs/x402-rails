# frozen_string_literal: true

require_relative "lib/x402/rails/version"

Gem::Specification.new do |spec|
  spec.name = "x402-rails"
  spec.version = X402::Rails::VERSION
  spec.authors = ["Zach Perlman"]
  spec.email = ["z.h.perlman@gmail.com"]

  spec.summary = "Rails integration for x402 payment protocol"
  spec.description = "Accept instant blockchain micropayments in Rails applications using the x402 protocol. Enable HTTP 402 Payment Required with USDC payments on Base and other networks."
  spec.homepage = "https://github.com/yourusername/x402-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/x402-rails"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "rails", ">= 7.0.0"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-follow_redirects", "~> 0.3"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "vcr", "~> 6.0"
end
