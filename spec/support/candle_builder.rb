# frozen_string_literal: true

module CandleBuilder
  module_function

  def build(open:, high: nil, low: nil, close: nil, volume: 1000, time: nil)
    high ||= [open, close].compact.max
    low ||= [open, close].compact.min
    close ||= open

    SMC::Candle.new(
      time: time || Time.utc(2026, 6, 1, 9, 0),
      open: open.to_f,
      high: high.to_f,
      low: low.to_f,
      close: close.to_f,
      volume: volume.to_f
    )
  end

  def sequence(specs, start_time: Time.utc(2026, 6, 1, 9, 0), interval_seconds: 300)
    specs.each_with_index.map do |spec, index|
      attrs = spec.is_a?(Hash) ? spec : { open: spec }
      build(
        **attrs,
        time: start_time + (index * interval_seconds)
      )
    end
  end
end

RSpec.configure do |config|
  config.include CandleBuilder
end
