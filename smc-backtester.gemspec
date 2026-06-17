# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "smc-backtester"
  spec.version       = "1.0.0"
  spec.authors       = ["Shubham Taywade"]
  spec.email         = ["shubhamtaywade82@gmail.com"]

  spec.summary       = "SMC + ICT Institutional Trading Playbook Rules Engine & Backtester"
  spec.description   = "A pure Ruby OOP rules engine and backtester for Smart Money Concepts (SMC) and ICT models. Supports pivot detection, BOS/CHoCH structure breaks, liquidity sweeps, order blocks, and multi-timeframe (MTF) confluenced simulations."
  spec.homepage      = "https://github.com/shubhamtaywade82/smc-backtester"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is built.
  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "Rakefile", "spec/**/*.rb", "smc-playbook.html"]
  spec.bindir        = "exe"
  spec.executables   = ["smc-backtest", "smc-mtf-backtest", "smc-fetch-coindcx"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
