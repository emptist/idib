module Idib.Indicators.BollingerBands

import Data.List
import Idib.Types
import Idib.Vector

%default total

-- =========================================================================
-- BB result types
-- =========================================================================

public export
record BBResultList where
  constructor MkBBResultList
  bbm  : List Double
  bbu  : List Double
  bbl  : List Double
  bb6u : List Double
  bb4u : List Double
  bb4l : List Double
  bb6l : List Double

public export
record BBSingle where
  constructor MkBBSingle
  bbm  : Double
  bbu  : Double
  bbl  : Double
  bb6u : Double
  bb4u : Double
  bb4l : Double
  bb6l : Double

-- =========================================================================
-- Internal helpers (must be defined before use)
-- =========================================================================

-- BB middle = SMA of slice (expanding window for early bars)
bbmForSlice : List Double -> (window : Nat) -> Double
bbmForSlice [] _ = 0.0
bbmForSlice slice window =
  let len = length slice
      windowSize = if len >= window then window else len
  in case windowSize of
    0 => 0.0
    _ => let s = foldl (+) 0.0 (take windowSize (reverse slice))
         in s / cast windowSize

-- Compute BB series for all bars
doBBCalc : List Double -> (window : Nat) -> (multiplier : Double) -> (fallback : Double) -> BBResultList
doBBCalc [] _ _ _ = MkBBResultList [] [] [] [] [] [] []
doBBCalc closes window multiplier fallback =
  let results = go 0 closes
      bbmVals = map fst results
      bbuBbl = map snd results
      bbuVals = map fst bbuBbl
      bblVals = map snd bbuBbl
  in MkBBResultList
    { bbm = bbmVals
    , bbu = bbuVals
    , bbl = bblVals
    , bb6u = map (\(m, u) => 0.618 * u + 0.382 * m) (zip bbmVals bbuVals)
    , bb4u = map (\(m, u) => 0.382 * u + 0.618 * m) (zip bbmVals bbuVals)
    , bb4l = map (\(m, l) => 0.382 * l + 0.618 * m) (zip bbmVals bblVals)
    , bb6l = map (\(m, l) => 0.618 * l + 0.382 * m) (zip bbmVals bblVals)
    }
  where
    go : Integer -> List Double -> List (Double, (Double, Double))
    go _ [] = []
    go idx (x :: rest) =
      let slice = take (cast (idx + 1)) closes
          m = bbmForSlice slice window
          s = stdDev fallback slice
          u = m + s * multiplier
          l = m - s * multiplier
      in (m, (u, l)) :: go (idx + 1) rest

-- =========================================================================
-- BB series API
-- =========================================================================

public export
calcBBSeriesWithConfigForInterval : Interval -> IndicatorConfig -> List (Bar i) -> BBResultList
calcBBSeriesWithConfigForInterval interval config bars =
  let closes = map close bars
      window = bbMAWindow interval
      multiplier = bb_multiplier config
      fallback = bb_std_fallback config
  in doBBCalc closes window multiplier fallback

-- =========================================================================
-- Single-bar BB (for Indicators snapshot, last bar)
-- =========================================================================

public export
calcBBSingle : Interval -> IndicatorConfig -> List (Bar i) -> BBSingle
calcBBSingle interval config bars =
  let series = calcBBSeriesWithConfigForInterval interval config bars
  in case ( reverse series.bbm
          , reverse series.bbu
          , reverse series.bbl ) of
    (bm :: _, bu :: _, bl :: _) =>
      MkBBSingle
        { bbm = bm
        , bbu = bu
        , bbl = bl
        , bb6u = 0.618 * bu + 0.382 * bm
        , bb4u = 0.382 * bu + 0.618 * bm
        , bb4l = 0.382 * bl + 0.618 * bm
        , bb6l = 0.618 * bl + 0.382 * bm
        }
    _ => MkBBSingle 0.0 0.0 0.0 0.0 0.0 0.0 0.0
