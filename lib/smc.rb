# frozen_string_literal: true

require 'json'
require 'time'

# Require all files in smc/ directory
require_relative 'smc/candle'
require_relative 'smc/atr'
require_relative 'smc/indicators/supertrend'
require_relative 'smc/liquidity/displacement'
require_relative 'smc/liquidity/strong_low_detector'
require_relative 'smc/liquidity/strong_high_detector'
require_relative 'smc/pivot_detector'
require_relative 'smc/market_structure'
require_relative 'smc/liquidity_sweep'
require_relative 'smc/order_block'
require_relative 'smc/strategy'
require_relative 'smc/strategy/mtf_confluence'
require_relative 'smc/risk_manager'
require_relative 'smc/backtester'
require_relative 'smc/mtf_engine'
require_relative 'smc/data_generator'
