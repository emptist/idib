module Idib.Indicators.KDJ

import Data.List
import Idib.Types
import Idib.Vector

%default total

rsvCalc : Double -> Double -> Double -> Double
rsvCalc c h l =
  case h - l of
    0.0 => 50.0
    range => 100.0 * (c - l) / range

-- =========================================================================
-- KDJ result types
-- =========================================================================

public export
record KDJResultList where
  constructor MkKDJResultList
  k : List Double
  d : List Double
  j : List Double
  m : List Double

-- =========================================================================
-- KDJ computation: RSV → SMA(K) → SMA(D) → SMA(M), J = 3K - 2D
-- Matches glib's calc_kdj_with_config + compute_kdj_series_with_config
-- =========================================================================

public export
calcKDJSeriesWithConfig : IndicatorConfig -> List (Bar i) -> KDJResultList
calcKDJSeriesWithConfig config bars =
  let len = length bars
  in case len of
    0 => MkKDJResultList [] [] [] []
    _ =>
      let period = kdj_period config
          kPeriod = kdj_k_period config
          dPeriod = kdj_d_period config
          mPeriod = kdj_m_period config

          highs = map high bars
          lows = map low bars
          closes = map close bars

          -- Rolling max/min with expanding fallback
          hh = rollingMax period highs
          ll = rollingMin period lows

          -- RSV = 100 * (close - ll) / (hh - ll)
          rsv = zipWith3 rsvCalc closes hh ll

          -- K = SMA(RSV, kPeriod), D = SMA(K, dPeriod), M = SMA(K, mPeriod)
          kValues = smaSeries kPeriod rsv
          dValues = smaSeries dPeriod kValues
          mValues = smaSeries mPeriod kValues

          -- J = 3K - 2D
          jValues = zipWith (\k, d => 3.0 * k - 2.0 * d) kValues dValues

      in MkKDJResultList
        { k = kValues
        , d = dValues
        , j = jValues
        , m = mValues
        }

-- =========================================================================
-- Single-bar KDJ (last values only)
-- =========================================================================

public export
record KDJSingle where
  constructor MkKDJSingle
  k : Double
  d : Double
  j : Double
  m : Double

public export
calcKDJSingle : IndicatorConfig -> List (Bar i) -> KDJSingle
calcKDJSingle config bars =
  let series = calcKDJSeriesWithConfig config bars
      lastK = case reverse series.k of [] => 0.0; (v :: _) => v
      lastD = case reverse series.d of [] => 0.0; (v :: _) => v
      lastM = case reverse series.m of [] => 0.0; (v :: _) => v
      lastJ = 3.0 * lastK - 2.0 * lastD
  in MkKDJSingle { k = lastK, d = lastD, j = lastJ, m = lastM }

-- =========================================================================
-- KDJ pair series (k, d) for compute_kdj_series — used by strategy
-- =========================================================================

public export
computeKDJSeries : IndicatorConfig -> List (Bar i) -> List (Double, Double)
computeKDJSeries config bars =
  let series = calcKDJSeriesWithConfig config bars
  in zip series.k series.d
