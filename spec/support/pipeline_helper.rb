# frozen_string_literal: true

module PipelineHelper
  module_function

  def run_pipeline(candles, up_to_index:, pivot_left: 4, pivot_right: 4, sweep_tolerance: 0.0015)
    pivot_detector = SMC::PivotDetector.new(left_bars: pivot_left, right_bars: pivot_right)
    market_structure = SMC::MarketStructure.new
    liquidity_sweep = SMC::LiquiditySweep.new(tolerance_pct: sweep_tolerance)
    ob_detector = SMC::OrderBlockDetector.new

    (0..up_to_index).each do |index|
      candle = candles[index]
      swings = pivot_detector.detect_swings(candles[0..index])
      market_structure.update(swings, candle, index)

      recent_bos = market_structure.bos_events.last
      ob_detector.check_for_new_ob(recent_bos, candles, index) if recent_bos && recent_bos[:index] == index

      recent_choch = market_structure.choch_events.last
      ob_detector.check_for_new_ob(recent_choch, candles, index) if recent_choch && recent_choch[:index] == index

      liquidity_sweep.update_equal_levels(swings)
      liquidity_sweep.detect_sweeps(swings, candle, index)
      ob_detector.update_mitigations(candle, index)
    end

    {
      pivot_detector: pivot_detector,
      market_structure: market_structure,
      liquidity_sweep: liquidity_sweep,
      ob_detector: ob_detector
    }
  end

  def evaluate_pb3(candles, index:, strategy: nil, **pipeline_options)
    state = run_pipeline(candles, up_to_index: index, **pipeline_options)
    strategy ||= SMC::Strategy::BosPullbackStrategy.new

    strategy.evaluate(
      candles,
      index,
      state[:pivot_detector],
      state[:market_structure],
      state[:liquidity_sweep],
      state[:ob_detector]
    )
  end

  def evaluate_pb6(candles, index:, strategy: nil, **pipeline_options)
    state = run_pipeline(candles, up_to_index: index, **pipeline_options)
    strategy ||= SMC::Strategy::SweepReversalStrategy.new

    strategy.evaluate(
      candles,
      index,
      state[:pivot_detector],
      state[:market_structure],
      state[:liquidity_sweep],
      state[:ob_detector]
    )
  end

  def evaluate_pb7(candles, index:, strategy: nil, **pipeline_options)
    state = run_pipeline(candles, up_to_index: index, **pipeline_options)
    strategy ||= SMC::Strategy::SweepOB.new

    strategy.evaluate(
      candles,
      index,
      state[:pivot_detector],
      state[:market_structure],
      state[:liquidity_sweep],
      state[:ob_detector]
    )
  end
end

RSpec.configure do |config|
  config.include PipelineHelper
end
