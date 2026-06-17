# frozen_string_literal: true

require_relative 'candle_builder'
require_relative 'pb7_fixture'

module PB3Fixture
  module_function

  LONG_ENTRY_INDEX = 55
  SHORT_ENTRY_INDEX = 55

  def long_candles
    CandleBuilder.sequence(
      [
        *Array.new(12) { { open: 110.0, high: 110.5, low: 109.5, close: 110.2 } },
        { open: 110.5, high: 112.0, low: 110.0, close: 111.5 },
        { open: 111.5, high: 113.0, low: 111.0, close: 112.5 },
        { open: 112.5, high: 114.0, low: 112.0, close: 113.5 },
        { open: 113.5, high: 115.5, low: 113.0, close: 115.0 },
        { open: 115.0, high: 115.2, low: 114.0, close: 114.5 },
        { open: 114.5, high: 114.8, low: 113.5, close: 114.0 },
        { open: 114.0, high: 114.3, low: 112.5, close: 113.0 },
        { open: 113.0, high: 113.3, low: 111.5, close: 112.0 },
        { open: 112.0, high: 112.3, low: 110.5, close: 111.0 },
        { open: 111.0, high: 111.3, low: 109.5, close: 110.0 },
        { open: 110.0, high: 110.3, low: 108.5, close: 109.0 },
        { open: 109.0, high: 109.3, low: 107.5, close: 108.0 },
        { open: 108.0, high: 108.3, low: 106.5, close: 107.0 },
        { open: 107.0, high: 107.3, low: 105.5, close: 106.0 },
        { open: 106.0, high: 106.3, low: 102.0, close: 103.0 },
        { open: 103.0, high: 104.0, low: 102.5, close: 103.5 },
        { open: 103.5, high: 104.5, low: 103.0, close: 104.0 },
        { open: 104.0, high: 105.0, low: 103.5, close: 104.5 },
        { open: 104.5, high: 105.5, low: 104.0, close: 105.0 },
        { open: 105.0, high: 106.0, low: 104.5, close: 105.5 },
        { open: 105.5, high: 106.5, low: 105.0, close: 106.0 },
        { open: 106.0, high: 107.0, low: 105.5, close: 106.5 },
        { open: 106.5, high: 107.5, low: 106.0, close: 107.0 },
        { open: 107.0, high: 108.0, low: 106.5, close: 107.5 },
        { open: 107.5, high: 108.5, low: 107.0, close: 108.0 },
        { open: 108.0, high: 109.0, low: 107.5, close: 108.5 },
        { open: 108.5, high: 109.5, low: 108.0, close: 109.0 },
        { open: 109.0, high: 110.0, low: 108.5, close: 109.5 },
        { open: 109.5, high: 110.5, low: 109.0, close: 110.0 },
        { open: 110.0, high: 111.0, low: 109.5, close: 110.5 },
        { open: 110.5, high: 111.5, low: 110.0, close: 111.0 },
        { open: 111.0, high: 112.0, low: 110.5, close: 111.5 },
        { open: 111.5, high: 112.5, low: 111.0, close: 112.0 },
        { open: 112.0, high: 112.2, low: 111.5, close: 112.0 },
        { open: 112.0, high: 112.2, low: 111.5, close: 112.0 },
        { open: 113.0, high: 117.0, low: 112.5, close: 116.0 },
        { open: 116.0, high: 116.2, low: 113.5, close: 114.0 },
        { open: 114.0, high: 114.2, low: 111.5, close: 112.0 },
        { open: 112.0, high: 112.2, low: 109.9, close: 110.5 },
        { open: 110.5, high: 110.8, low: 110.3, close: 110.6 },
        { open: 110.6, high: 110.9, low: 110.3, close: 110.7 },
        { open: 110.7, high: 111.0, low: 110.3, close: 110.8 },
        { open: 110.8, high: 111.2, low: 110.0, close: 110.5 },
        { open: 110.5, high: 111.0, low: 109.85, close: 110.8 }
      ],
      start_time: Time.utc(2026, 6, 1, 9, 0)
    )
  end

  def short_candles
    PB7Fixture.mirror_candles(long_candles, pivot: 110.0)
  end
end

RSpec.configure do |config|
  config.include PB3Fixture
end
