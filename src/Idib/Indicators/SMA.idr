module Idib.Indicators.SMA

import Data.List
import Idib.Types
import Idib.Vector

%default total

-- =========================================================================
-- SMA series: expanding-window mean, one value per input bar
-- =========================================================================

public export
calcSmaSeries : (period : Nat) -> List Double -> List Double
calcSmaSeries = smaSeries

-- =========================================================================
-- Running trough count: cumsum of (values[i] == cummin(values[i]))
-- =========================================================================

runningTroughCount : List Double -> List Nat
runningTroughCount [] = []
runningTroughCount (x :: xs) = go x 1 [1] xs
  where
    go : Double -> Nat -> List Nat -> List Double -> List Nat
    go _ count acc [] = reverse acc
    go currentMin count acc (v :: rest) =
      let newMin = min v currentMin
          isTrough = abs (v - newMin) < 0.0001
          newCount = if isTrough then count + 1 else count
      in go newMin newCount (newCount :: acc) rest

-- =========================================================================
-- computeCNST7: 100 * expanding_mean(sma > prev_sma AND hlhrows == 0)
-- Matches glib's compute_cnst7
-- =========================================================================

computeCNST7 : List Double -> List Nat -> Double
computeCNST7 [] _ = 0.0
computeCNST7 _ [] = 0.0
computeCNST7 (firstSma :: restSma) hlhrows =
  case hlhrows of
    [] => 0.0
    (_ :: restHlh) => doCompute restSma restHlh firstSma 0.0 0
  where
    doCompute : List Double -> List Nat -> Double -> Double -> Nat -> Double
    doCompute [] _ _ sumVal count =
      case count of
        0 => 0.0
        _ => 100.0 * sumVal / cast count
    doCompute (sma :: smaRest) [] _ sumVal count =
      case count of
        0 => 0.0
        _ => 100.0 * sumVal / cast count
    doCompute (sma :: smaRest) (hlh :: hlhRest) prevSma sumVal count =
      let rising = sma > prevSma
          cond = rising && hlh == 0
          newSum = if cond then sumVal + 1.0 else sumVal
          newCount = count + 1
      in doCompute smaRest hlhRest sma newSum newCount

-- =========================================================================
-- List-based SMA result (public, used by all indicator modules)
-- =========================================================================

public export
record SmaResultList where
  constructor MkSmaResultList
  sma7           : Double
  prev_sma7      : Double
  sma7_series    : List Double
  cmah7          : Double
  cmal7          : Double
  hlcmah7        : Double
  cmah7_series   : List (Integer, Double)
  cmal7_series   : List (Integer, Double)
  hlcmah7_series : List (Integer, Double)
  cnst7          : Double
  hrows7         : Nat
  lrows7         : Nat
  hlhrows7       : Nat
  hprd           : List Nat
  lprd           : List Nat
  lrows_series   : List Nat
  lprd_series    : List Nat

-- =========================================================================
-- calcSma7WithConfig: compute SMA7 + full CMA chain
-- Matches glib's calc_sma7_with_config
-- =========================================================================

public export
calcSma7WithConfig : {i : Interval} -> IndicatorConfig -> List (Bar i) -> SmaResultList
calcSma7WithConfig config bars =
  let closes = map close bars
      len = length closes
  in case len of
    0 => MkSmaResultList 0.0 0.0 [] 0.0 0.0 0.0 [] [] [] 0.0 0 0 0 [] [] [] []
    _ =>
      let smaPeriod = sma_period config
          sma7Values = smaSeries smaPeriod closes

          -- Last SMA value
          lastSma = case reverse sma7Values of
            [] => 0.0
            (v :: _) => v

          -- hprd = running peak count of SMA values
          hprd = runningPeakCount sma7Values
          -- hrows = bar index within each hprd group
          hrows = rowsWithinEachGroup hprd

          -- lprd = running trough count of SMA values
          lprd = runningTroughCount sma7Values
          -- lrows = bar index within each lprd group
          lrows = rowsWithinEachGroup lprd

          -- hlsf = cumulative min within each hprd group
          hlsf = cumulativeMinWithinGroups sma7Values hprd
          -- hlprd = running peak count on hlsf
          hlprd = runningPeakCountOnValues sma7Values hlsf
          -- hlhsf = cumulative max within each hlprd group
          hlhsf = cumulativeMaxWithinGroups sma7Values hlprd
          -- hlhprd = running peak count on hlhsf
          hlhprd = runningPeakCountOnValues sma7Values hlhsf
          -- hlhrows = bar index within each hlhprd group
          hlhrows = rowsWithinEachGroup hlhprd

          -- Expanding means within groups (last value)
          hlcmah7Last = expandingMeanWithinGroups sma7Values hlhprd
          cmah7Last = expandingMeanWithinGroups sma7Values hprd
          cmal7Last = expandingMeanWithinGroups sma7Values lprd

          -- Full series for CMA values
          hlcmah7Ser = expandingMeanWithinGroupsSeries sma7Values hlhprd
          cmah7Ser = expandingMeanWithinGroupsSeries sma7Values hprd
          cmal7Ser = expandingMeanWithinGroupsSeries sma7Values lprd

          -- cnst7
          cnst7Val = computeCNST7 sma7Values hlhrows

          -- prev_sma7: SMA of bars[:-1] for period 7
          prevSma7 = if len >= 8
            then let dropN = the Nat (cast {from=Integer} {to=Nat} (cast {from=Nat} {to=Integer} len - 8))
                     prevCloses = take 7 (drop dropN closes)
                 in case prevCloses of
                   [] => lastSma
                   cs => case reverse (smaSeries smaPeriod cs) of
                     [] => lastSma
                     (v :: _) => v
            else lastSma

          -- Last hrows/lrows/hlhrows
          lastHrows = case reverse hrows of
            [] => 0
            (v :: _) => v
          lastLrows = case reverse lrows of
            [] => 0
            (v :: _) => v
          lastHlhrows = case reverse hlhrows of
            [] => 0
            (v :: _) => v

      in MkSmaResultList
        { sma7 = lastSma
        , prev_sma7 = prevSma7
        , sma7_series = sma7Values
        , cmah7 = cmah7Last
        , cmal7 = cmal7Last
        , hlcmah7 = hlcmah7Last
        , cmah7_series = cmah7Ser
        , cmal7_series = cmal7Ser
        , hlcmah7_series = hlcmah7Ser
        , cnst7 = cnst7Val
        , hrows7 = lastHrows
        , lrows7 = lastLrows
        , hlhrows7 = lastHlhrows
        , hprd = hprd
        , lprd = lprd
        , lrows_series = lrows
        , lprd_series = lprd
        }
