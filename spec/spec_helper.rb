# frozen_string_literal: true

require "simplecov"
require "simplecov-formatter-badge"

SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::BadgeFormatter
  ])
  add_filter "/spec/"
end

require "rails"
require "x402/rails"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

Rails.logger = Logger.new(File::NULL)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed
end
