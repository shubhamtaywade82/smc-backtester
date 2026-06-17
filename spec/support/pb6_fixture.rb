# frozen_string_literal: true

require_relative 'candle_builder'
require_relative 'pb7_fixture'

module PB6Fixture
  module_function

  LONG_ENTRY_INDEX = 52
  SHORT_ENTRY_INDEX = 52

  def long_candles
    preamble = PB7Fixture.long_candles[0..50]
    tail = CandleBuilder.sequence(
      [
        { open: 113.0, high: 113.2, low: 111.0, close: 112.0 },
        { open: 112.0, high: 112.2, low: 105.0, close: 105.8 }
      ],
      start_time: preamble.last.time + 300
    )
    preamble + tail
  end

  def short_candles
    PB7Fixture.mirror_candles(long_candles, pivot: 110.0)
  end
end

RSpec.configure do |config|
  config.include PB6Fixture
end
