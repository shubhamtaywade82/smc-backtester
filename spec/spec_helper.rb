# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__)) unless $LOAD_PATH.include?(File.expand_path('../../lib', __FILE__))

require 'smc'

Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |file| require file }

RSpec.configure do |config|
  # Enforce expect syntax only
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Enable color and detailed formatting
  config.color = true
  config.formatter = :documentation

  # Run specs in random order to help surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Enable partial double verification
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
