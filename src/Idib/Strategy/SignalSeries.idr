module Idib.Strategy.SignalSeries

import Data.List
import Idib.Types
import Idib.Vector
import Idib.Indicators.SMA
import Idib.Indicators.BollingerBands
import Idib.Indicators.KDJ
import Idib.Indicators.ChartBar
import Idib.Strategy.Position
import Idib.Strategy.Evaluate

%default total

-- Helper: take first n elements from list
takeIdx : Nat -> List a -> List a
takeIdx _ [] = []
takeIdx 0 _ = []
takeIdx (S k) (x :: xs) = x :: takeIdx k xs

-- Helper: count K > D from end
countBarsKOnD : List (Double, Double) -> Nat
countBarsKOnD pairs = go (reverse pairs) 0
  where
    go : List (Double, Double) -> Nat -> Nat
    go [] count = count
    go ((k, d) :: rest) count =
      if k > d then go rest (count + 1) else count

-- Helper: count D > K from end
countBarsDOnK : List (Double, Double) -> Nat
countBarsDOnK pairs = go (reverse pairs) 0
  where
    go : List (Double, Double) -> Nat -> Nat
    go [] count = count
    go ((k, d) :: rest) count =
      if d > k then go rest (count + 1) else count

-- =========================================================================
-- Signal: a signal with its bar index and type
-- =========================================================================

public export
record Signal where
  constructor MkSignal
  barIndex : Integer
  signal   : String

-- =========================================================================
-- evaluateSeries: sequential evaluation with state threading
-- Matches glib's compute_signal_series
-- For each bar i >= 20, recompute indicators on bars[0..i] and evaluate
-- =========================================================================

public export
evaluateSeries : {i : Interval} -> Interval -> IndicatorConfig -> List (Bar i) -> List Signal
evaluateSeries interval config bars =
  let len = length bars
  in case len < 2 of
    True => []
    False =>
      let state = createStrategy
      in go state bars 0 []
  where
    go : StrategyState -> List (Bar i) -> Integer -> List Signal -> List Signal
    go _ [] _ acc = reverse acc
    go state (bar :: rest) idx acc =
      if idx < 20
      then go state rest (idx + 1) acc
      else let subBars = takeIdx (cast (idx + 1)) bars
               subLen = length subBars
           in case subLen < 2 of
             True => go state rest (idx + 1) acc
             False =>
               let smaResult = calcSma7WithConfig config subBars
                   bbResult = calcBBSeriesWithConfigForInterval interval config subBars
                   kdjResult = calcKDJSeriesWithConfig config subBars

                   prevSma7 = smaResult.prev_sma7
                   prevBbm = case reverse bbResult.bbm of
                     [] => 0.0
                     (_ :: rest2) => case reverse rest2 of
                       [] => 0.0
                       (v :: _) => v

                   prevKdjPairs = case computeKDJSeries config subBars of
                     [] => []
                     ps => case reverse ps of
                       [] => []
                       (_ :: psRest) => reverse psRest

                   prevJ = case reverse prevKdjPairs of
                     [] => 0.0
                     ((k, d) :: _) => 3.0 * k - 2.0 * d

                   -- Build indicators for this bar
                   chartBars = computeChartBars interval config subBars
                   lastChart = case reverse chartBars of
                     [] => let z = the Double 0.0
                               s = the String ""
                           in MkChartBar bar z z z z z z z z z z z z z z z s
                     (cb :: _) => cb

                   prevChartBars = case chartBars of
                     [] => []
                     cs => case reverse cs of
                       [] => []
                       (_ :: csRest) => reverse csRest
                   prevChart = case reverse prevChartBars of
                     [] => lastChart
                     (cb :: _) => cb

                   bigInterval = interval == Month3 || interval == Month1 || interval == Week1
                   smasUp = lastChart.sma7 > prevSma7 && lastChart.bbm > prevBbm
                   cmasUp7 = lastChart.hlcmah7 > prevChart.hlcmah7 && lastChart.sma7 > prevSma7
                   cmasUp = if bigInterval then cmasUp7
                            else cmasUp7 && lastChart.sma7 >= lastChart.hlcmah7

                   kdjPairs = computeKDJSeries config subBars
                   bkod = countBarsKOnD kdjPairs
                   bdonk = countBarsDOnK kdjPairs

                   -- prev bar
                   prevBar = case reverse (takeIdx (cast idx) bars) of
                     [] => bar
                     (pb :: _) => pb

                   ind = MkIndicators
                     { sma7 = lastChart.sma7
                     , prev_sma7 = prevSma7
                     , bbm = lastChart.bbm
                     , prev_bbm = prevBbm
                     , bbu = lastChart.bbu
                     , bbl = lastChart.bbl
                     , bbp = 0.0
                     , bb6u = lastChart.bb6u
                     , bb4u = lastChart.bb4u
                     , bb4l = lastChart.bb4l
                     , bb6l = lastChart.bb6l
                     , k = lastChart.k
                     , d = lastChart.d
                     , j = lastChart.j
                     , m = lastChart.m
                     , prev_k = 0.0
                     , prev_j = prevJ
                     , hrows7 = 0
                     , lrows7 = 0
                     , hprd7 = 0
                     , lprd7 = 0
                     , cmah7 = lastChart.cmah7
                     , cmal7 = lastChart.cmal7
                     , prev_hlcmah7 = 0.0
                     , hlhrows7 = 0
                     , cnst7 = 0.0
                     , velo7 = 0.0
                     , cnsvel7 = 0.0
                     , bias = 0.0
                     , smas_up = smasUp
                     , cmas_up = cmasUp
                     , bars_k_on_d = bkod
                     , bars_d_on_k = bdonk
                     , xlow = False
                     , hlrows = 0
                     , hlhlrows = 0
                     , bbuy = smasUp && lastChart.k > lastChart.d && bkod <= 3
                     }

                   (newState, signalStr) = evaluateBar state bar prevBar ind

                   newAcc = case signalStr of
                     "hold" => acc
                     "holding" => acc
                     _ => MkSignal idx signalStr :: acc

               in go newState rest (idx + 1) newAcc
