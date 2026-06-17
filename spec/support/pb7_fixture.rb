# frozen_string_literal: true

require_relative 'candle_builder'

module PB7Fixture
  module_function

  LONG_ENTRY_INDEX = 52
  SHORT_ENTRY_INDEX = 52

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
        { open: 106.0, high: 106.3, low: 104.5, close: 105.0 },
        { open: 105.0, high: 105.3, low: 102.0, close: 103.0 },
        { open: 103.0, high: 104.0, low: 102.5, close: 103.5 },
        { open: 103.5, high: 104.5, low: 103.0, close: 104.0 },
        { open: 104.0, high: 105.0, low: 103.5, close: 104.5 },
        { open: 104.5, high: 105.5, low: 104.0, close: 105.0 },
        { open: 105.0, high: 107.0, low: 104.5, close: 106.5 },
        { open: 106.5, high: 108.5, low: 106.0, close: 108.0 },
        { open: 108.0, high: 110.0, low: 107.5, close: 109.5 },
        { open: 109.5, high: 112.5, low: 109.0, close: 112.0 },
        { open: 112.0, high: 112.2, low: 110.5, close: 111.0 },
        { open: 111.0, high: 111.2, low: 109.5, close: 110.0 },
        { open: 110.0, high: 110.2, low: 108.5, close: 109.0 },
        { open: 109.0, high: 109.2, low: 107.5, close: 108.0 },
        { open: 108.0, high: 108.2, low: 106.5, close: 107.0 },
        { open: 107.0, high: 107.2, low: 105.5, close: 106.0 },
        { open: 106.0, high: 106.2, low: 104.5, close: 105.0 },
        { open: 105.0, high: 105.2, low: 104.0, close: 104.5 },
        { open: 104.5, high: 104.8, low: 104.2, close: 104.4 },
        { open: 104.4, high: 104.7, low: 104.3, close: 104.5 },
        { open: 104.5, high: 104.8, low: 104.25, close: 104.6 },
        { open: 104.6, high: 104.9, low: 104.3, close: 104.7 },
        { open: 104.7, high: 105.0, low: 103.5, close: 104.3, volume: 15_000 },
        { open: 105.5, high: 105.8, low: 102.2, close: 102.5 },
        { open: 102.5, high: 113.5, low: 102.2, close: 113.0 },
        { open: 113.0, high: 117.0, low: 112.5, close: 116.0 },
        { open: 116.0, high: 104.5, low: 103.0, close: 104.0 }
      ],
      start_time: Time.utc(2026, 6, 1, 9, 0)
    )
  end

  def short_candles
    mirror_candles(long_candles, pivot: 110.0)
  end

  def mirror_candles(candles, pivot:)
    candles.map do |candle|
      SMC::Candle.new(
        time: candle.time,
        open: mirror_price(candle.open, pivot),
        high: mirror_price(candle.low, pivot),
        low: mirror_price(candle.high, pivot),
        close: mirror_price(candle.close, pivot),
        volume: candle.volume
      )
    end
  end

  def mirror_price(price, pivot)
    (2.0 * pivot) - price
  end
end

RSpec.configure do |config|
  config.include PB7Fixture
end
