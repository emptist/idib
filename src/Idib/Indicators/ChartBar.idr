module Idib.Indicators.ChartBar

import Data.List
import Idib.Types
import Idib.Vector
import Idib.Indicators.SMA
import Idib.Indicators.BollingerBands
import Idib.Indicators.KDJ

%default total

lastOf : List a -> (dflt : a) -> a
lastOf [] dflt = dflt
lastOf xs dflt = case reverse xs of
  [] => dflt
  (x :: _) => x

countBarsKOnD : List (Double, Double) -> Nat
countBarsKOnD pairs = go (reverse pairs) 0
  where
    go : List (Double, Double) -> Nat -> Nat
    go [] count = count
    go ((k, d) :: rest) count =
      if k > d then go rest (count + 1) else count

countBarsDOnK : List (Double, Double) -> Nat
countBarsDOnK pairs = go (reverse pairs) 0
  where
    go : List (Double, Double) -> Nat -> Nat
    go [] count = count
    go ((k, d) :: rest) count =
      if d > k then go rest (count + 1) else count

-- Safe index: return default if out of bounds
nth : Nat -> List a -> a -> a
nth _ [] dflt = dflt
nth 0 (x :: _) _ = x
nth (S k) (_ :: rest) dflt = nth k rest dflt

-- Total range function (0..n-1), structurally recursive on n
private
range : Nat -> List Nat
range 0 = []
range (S k) = range k ++ [k]

-- =========================================================================
-- computeChartBars: all ChartBars with indicators precomputed
-- =========================================================================

public export
computeChartBars : {i : Interval} -> Interval -> IndicatorConfig -> List (Bar i) -> List (ChartBar i)
computeChartBars interval config bars =
  case bars of
    [] => []
    (defBar :: _) =>
      let n = length bars
          smaResult = calcSma7WithConfig config bars
          bbResult = calcBBSeriesWithConfigForInterval interval config bars
          kdjResult = calcKDJSeriesWithConfig config bars
          cmah7Values = map snd smaResult.cmah7_series
          cmal7Values = map snd smaResult.cmal7_series
          hlcmah7Values = map snd smaResult.hlcmah7_series

          buildOne : Nat -> ChartBar i
          buildOne idx =
            MkChartBar
              (nth idx bars defBar)
              (nth idx smaResult.sma7_series 0.0)
              (nth idx bbResult.bbm 0.0)
              (nth idx bbResult.bbu 0.0)
              (nth idx bbResult.bbl 0.0)
              (nth idx bbResult.bb6u 0.0)
              (nth idx bbResult.bb4u 0.0)
              (nth idx bbResult.bb4l 0.0)
              (nth idx bbResult.bb6l 0.0)
              (nth idx cmah7Values 0.0)
              (nth idx cmal7Values 0.0)
              (nth idx hlcmah7Values 0.0)
              (nth idx kdjResult.k 0.0)
              (nth idx kdjResult.d 0.0)
              (nth idx kdjResult.j 0.0)
              (nth idx kdjResult.m 0.0)
              ""

          indices : List Nat
          indices = range n

      in map buildOne indices

-- =========================================================================
-- computeIndicators: per-bar indicator snapshot for strategy
-- =========================================================================

public export
computeIndicators : {i : Interval} -> Interval -> IndicatorConfig -> List (Bar i) -> Indicators
computeIndicators interval config bars =
  case bars of
    [] => MkIndicators 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 False False 0 0 False 0 0 False
    (defBar :: _) =>
      let chartBars = computeChartBars interval config bars
          z = 0.0
          defaultChart = MkChartBar defBar z z z z z z z z z z z z z z z ""
          lastChart = lastOf chartBars defaultChart

          prevChartBars = case chartBars of
            [] => []
            cs => case reverse cs of
              [] => []
              (_ :: rest) => reverse rest
          prevChart = lastOf prevChartBars lastChart

          smaResult = calcSma7WithConfig config bars
          prevSma7 = smaResult.prev_sma7

          bigInterval = interval == Month3 || interval == Month1 || interval == Week1
          smasUp = lastChart.sma7 > prevSma7 && lastChart.bbm > prevChart.bbm
          cmasUp7 = lastChart.hlcmah7 > prevChart.hlcmah7 && lastChart.sma7 > prevSma7
          cmasUp = if bigInterval then cmasUp7
                   else cmasUp7 && lastChart.sma7 >= lastChart.hlcmah7

          kdjPairs = computeKDJSeries config bars
          bkod = countBarsKOnD kdjPairs
          bdonk = countBarsDOnK kdjPairs

          prevKdjPairs = case kdjPairs of
            [] => []
            ps => case reverse ps of
              [] => []
              (_ :: rest) => reverse rest
          prevJ = case reverse prevKdjPairs of
            [] => 0.0
            ((k, d) :: _) => 3.0 * k - 2.0 * d

          bbSingle = calcBBSingle interval config bars
          xlow = (bbSingle.bbl - lastChart.bar.low) >= (bbSingle.bb6l - bbSingle.bbl)

          sma7Series = smaResult.sma7_series
          prevSma7Val = case sma7Series of
            [] => 0.0
            xs => case reverse xs of
              [] => 0.0
              (_ :: rest) => case reverse rest of
                [] => 0.0
                (v :: _) => v
          lastSma7Val = lastOf sma7Series 0.0
          sma7Rising = lastSma7Val > prevSma7Val
          kdjRightNow = lastChart.k > lastChart.d && bkod <= 3
          bbuy = sma7Rising && kdjRightNow

      in MkIndicators
        { sma7 = lastChart.sma7
        , prev_sma7 = prevSma7
        , bbm = lastChart.bbm
        , prev_bbm = prevChart.bbm
        , bbu = lastChart.bbu
        , bbl = lastChart.bbl
        , bb6u = lastChart.bb6u
        , bb4u = lastChart.bb4u
        , bb4l = lastChart.bb4l
        , bb6l = lastChart.bb6l
        , k = lastChart.k
        , d = lastChart.d
        , j = lastChart.j
        , prev_j = prevJ
        , m = lastChart.m
        , cmah7 = lastChart.cmah7
        , hlcmah7 = lastChart.hlcmah7
        , smas_up = smasUp
        , cmas_up = cmasUp
        , bars_k_on_d = bkod
        , bars_d_on_k = bdonk
        , xlow = xlow
        , hlrows = 0
        , hlhlrows = 0
        , bbuy = bbuy
        }
