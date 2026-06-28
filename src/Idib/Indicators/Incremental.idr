module Idib.Indicators.Incremental

import Idib.Types
import Idib.Fractal.Leaf
import Idib.Fractal.LeafDetect
import Idib.Fractal.Branch
import Idib.Fractal.Types
import Idib.Strategy.Position
import Data.List

%default total

-- =========================================================================
-- takeN / updateWindow
-- =========================================================================

takeN : Nat -> List a -> List a
takeN _ [] = []
takeN 0 _ = []
takeN (S k) (x :: xs) = x :: takeN k xs

updateWindow : Nat -> Double -> List Double -> List Double
updateWindow maxSize val window = takeN maxSize (val :: window)

-- =========================================================================
-- IState: rolling state between bars — O(1) per bar
-- =========================================================================

public export
record IState where
  constructor MkIState
  -- SMA7 sliding window
  sma7Sum     : Double
  sma7Count   : Nat
  sma7Window  : List Double
  -- BB sliding window
  bbSum       : Double
  bbSumSq     : Double
  bbCount     : Nat
  bbWindow    : List Double
  -- Previous bar indicators
  prevSma7    : Double
  prevBbm     : Double
  prevK       : Double
  prevD       : Double
  prevJ       : Double
  prevM       : Double
  prevLow     : Double
  -- KDJ consecutive counts
  barsKOnD    : Nat
  barsDOnK    : Nat
  -- Rolling windows for KDJ RSV
  lowWindow   : List Double
  highWindow  : List Double

public export
initState : IState
initState = MkIState
  { sma7Sum = 0.0, sma7Count = 0, sma7Window = []
  , bbSum = 0.0, bbSumSq = 0.0, bbCount = 0, bbWindow = []
  , prevSma7 = 0.0, prevBbm = 0.0
  , prevK = 50.0, prevD = 50.0, prevJ = 50.0, prevM = 50.0
  , prevLow = 0.0
  , barsKOnD = 0, barsDOnK = 0
  , lowWindow = [], highWindow = []
  }

-- =========================================================================
-- ChartResult: indicators for one bar
-- =========================================================================

public export
record ChartResult where
  constructor MkChartResult
  sma7     : Double
  bbm      : Double
  bbu      : Double
  bbl      : Double
  bb6u     : Double
  bb4u     : Double
  bb4l     : Double
  bb6l     : Double
  k        : Double
  d        : Double
  j        : Double
  m        : Double

-- =========================================================================
-- stepBar: one bar → (IState, ChartResult) — O(1)
-- =========================================================================

public export
covering
stepBar : IState -> (bar : Bar i) -> (IState, ChartResult)
stepBar st bar =
  let c = close bar
      h = high bar
      lo = low bar

      -- SMA7: sliding window sum of last 7 closes
      oldSma7N = st.sma7Count
      newSma7N = oldSma7N + 1
      sma7Drop = if oldSma7N >= 7
        then case reverse st.sma7Window of
          [] => 0.0
          (oldest :: _) => oldest
        else 0.0
      newSma7Sum = st.sma7Sum + c - sma7Drop
      newSma7Window = updateWindow 7 c st.sma7Window
      sma7N = min newSma7N 7
      sma7Val = newSma7Sum / cast sma7N

      -- BB: sliding window sum of last 20 closes
      oldBbN = st.bbCount
      newBbN = oldBbN + 1
      bbDrop = if oldBbN >= 20
        then case reverse st.bbWindow of
          [] => 0.0
          (oldest :: _) => oldest
        else 0.0
      newBbSum = st.bbSum + c - bbDrop
      newBbSumSq = st.bbSumSq + c * c - bbDrop * bbDrop
      newBbWindow = updateWindow 20 c st.bbWindow
      bbN = min newBbN 20
      bbmVal = newBbSum / cast bbN
      bbStd = if bbN >= 2
        then sqrt (abs ((newBbSumSq - newBbSum * newBbSum / cast bbN) / cast bbN))
        else 0.1
      bbuVal = bbmVal + 2.0 * bbStd
      bblVal = bbmVal - 2.0 * bbStd
      bb6uVal = bbmVal + 6.0 * bbStd
      bb4uVal = bbmVal + 4.0 * bbStd
      bb4lVal = bbmVal - 4.0 * bbStd
      bb6lVal = bbmVal - 6.0 * bbStd

      -- KDJ
      newLowWindow = updateWindow 7 lo st.lowWindow
      newHighWindow = updateWindow 7 h st.highWindow
      period = min newSma7N 7
      rLow = foldl min 1.0e18 (takeN period newLowWindow)
      rHigh = foldl max 0.0 (takeN period newHighWindow)
      rsvRange = rHigh - rLow
      rsv = if rsvRange > 0.0001 then (c - rLow) / rsvRange * 100.0 else 50.0
      kVal = (2.0 / 3.0) * st.prevK + (1.0 / 3.0) * rsv
      dVal = (2.0 / 3.0) * st.prevD + (1.0 / 3.0) * kVal
      jVal = 3.0 * kVal - 2.0 * dVal
      mVal = (2.0 / 10.0) * st.prevM + (1.0 / 10.0) * jVal

      -- Consecutive counts
      newBarsKOnD = if kVal > dVal then st.barsKOnD + 1 else 0
      newBarsDOnK = if dVal > kVal then st.barsDOnK + 1 else 0

      result = MkChartResult sma7Val bbmVal bbuVal bblVal
        bb6uVal bb4uVal bb4lVal bb6lVal
        kVal dVal jVal mVal

      newSt = MkIState
        newSma7Sum newSma7N newSma7Window
        newBbSum newBbSumSq newBbN newBbWindow
        sma7Val bbmVal
        kVal dVal jVal mVal
        lo
        newBarsKOnD newBarsDOnK
        newLowWindow newHighWindow
      in (newSt, result)

-- =========================================================================
-- computeIndicators: single-pass fold, returns SMA7 series + all results
-- =========================================================================

public export
covering
computeIndicators : {i : Interval} -> List (Bar i) -> (List Double, List ChartResult)
computeIndicators bars = go initState [] [] bars
  where
    go : IState -> List Double -> List ChartResult -> List (Bar i) -> (List Double, List ChartResult)
    go _ smas results [] = (reverse smas, reverse results)
    go st smas results (b :: bs) =
      let (newSt, cr) = stepBar st b
      in go newSt (cr.sma7 :: smas) (cr :: results) bs

-- =========================================================================
-- Full pipeline: bars → indicators → leaves → branches → regime → signals
-- =========================================================================

segFractal : Segment -> Fractal
segFractal (YangLeaf f) = f
segFractal (YinLeaf f) = f
segFractal (YangBranch f _) = f
segFractal (YinBranch f _) = f

isYangLeafSeg : Segment -> Bool
isYangLeafSeg (YangLeaf _) = True
isYangLeafSeg _ = False

isYinLeafSeg : Segment -> Bool
isYinLeafSeg (YinLeaf _) = True
isYinLeafSeg _ = False

isBullMarket : List Segment -> Bool
isBullMarket [] = True
isBullMarket leaves =
  let yangTotal = foldl (\acc, seg => acc + segBarsCount seg) 0
                      (filter isYangLeafSeg leaves)
      yinTotal = foldl (\acc, seg => acc + segBarsCount seg) 0
                     (filter isYinLeafSeg leaves)
  in yangTotal >= yinTotal

indexedMap : (Nat -> a -> b) -> List a -> List b
indexedMap f xs = go 0 xs
  where
    go : Nat -> List a -> List b
    go _ [] = []
    go i (x :: rest) = f i x :: go (i + 1) rest

public export
record FractalResult where
  constructor MkFractalResult
  leaves     : List Segment
  branches   : List Segment
  bullMarket : Bool
  sma7Series : List Double

public export
covering
computeFractal : {i : Interval} -> List (Bar i) -> (List ChartResult, FractalResult)
computeFractal bars =
  let (sma7Series, results) = computeIndicators bars
      leafBars = indexedMap (\idx, val => MkLeafBar (cast idx) val) sma7Series
      leaves = detectLeaf leafBars
      bull = isBullMarket leaves
      config = MkBranchConfig i "SMA7"
      branches = detectBranch config leafBars leaves
      fractal = MkFractalResult leaves branches bull sma7Series
  in (results, fractal)
