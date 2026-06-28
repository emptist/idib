module Idib.Indicators.Incremental

import Idib.Types
import Idib.Fractal.Leaf
import Idib.Strategy.Position
import Data.List

%default total

-- =========================================================================
-- State: rolling windows + previous values — O(1) per bar
-- =========================================================================

public export
record IState where
  constructor MkIState
  sma7Sum     : Double
  sma7Count   : Nat
  sma7Window  : List Double
  bbSum       : Double
  bbSumSq     : Double
  bbCount     : Nat
  bbWindow    : List Double
  prevSma7    : Double
  prevBbm     : Double
  prevBbu     : Double
  prevBbl     : Double
  prevK       : Double
  prevD       : Double
  prevJ       : Double
  prevM       : Double
  prevClose   : Double
  prevLow     : Double
  barsKOnD    : Nat
  barsDOnK    : Nat
  lowWindow   : List Double
  highWindow  : List Double
  prevLeafEnd : Integer
  prevIsYang  : Bool

public export
initState : IState
initState = MkIState
  { sma7Sum = 0.0, sma7Count = 0, sma7Window = []
  , bbSum = 0.0, bbSumSq = 0.0, bbCount = 0, bbWindow = []
  , prevSma7 = 0.0, prevBbm = 0.0, prevBbu = 0.0, prevBbl = 0.0
  , prevK = 50.0, prevD = 50.0, prevJ = 50.0, prevM = 50.0
  , prevClose = 0.0, prevLow = 0.0
  , barsKOnD = 0, barsDOnK = 0
  , lowWindow = [], highWindow = []
  , prevLeafEnd = -1, prevIsYang = False
  }

-- =========================================================================
-- Helpers (defined before use)
-- =========================================================================

takeN : Nat -> List a -> List a
takeN _ [] = []
takeN 0 _ = []
takeN (S k) (x :: xs) = x :: takeN k xs

updateWindow : Nat -> Double -> List Double -> List Double
updateWindow maxSize val window = takeN maxSize (val :: window)

findLeafAtBar : List Segment -> Integer -> Maybe Segment
findLeafAtBar [] _ = Nothing
findLeafAtBar (seg :: rest) idx =
  let endI = cast (fEndIdx (segFractal seg))
  in if endI == idx then Just seg else findLeafAtBar rest idx
  where
    segFractal : Segment -> Fractal
    segFractal (YangLeaf f) = f
    segFractal (YinLeaf f) = f
    segFractal (YangBranch f _) = f
    segFractal (YinBranch f _) = f

-- =========================================================================
-- stepBar: one bar → (IState, ChartBar) — O(1)
-- =========================================================================

public export
covering
stepBar : IState -> List Segment -> (bar : Bar i) -> Integer -> (IState, ChartBar i)
stepBar st leaves bar barIdx =
  let c = close bar
      h = high bar
      lo = low bar

      -- SMA7
      newSma7Sum = st.sma7Sum + c
      newSma7Count = st.sma7Count + 1
      newSma7Window = updateWindow 7 c st.sma7Window
      sma7Val = newSma7Sum / cast (min newSma7Count 7)

      -- BB (SMA20 + std)
      newBbSum = st.bbSum + c
      newBbSumSq = st.bbSumSq + c * c
      newBbCount = st.bbCount + 1
      newBbWindow = updateWindow 20 c st.bbWindow
      bbN = min newBbCount 20
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
      period = min newSma7Count 7
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

      -- xlow / shifted_xlow
      prevLowest = case st.lowWindow of
        [] => 1.0e18
        ws => foldl min 1.0e18 ws
      xlowVal = lo < prevLowest
      shiftedXlow = case drop 1 st.lowWindow of
        [] => False
        ws => lo > foldl max 0.0 ws
      newLowestLow = min lo prevLowest

      -- smas_up
      sma7Rising = sma7Val > st.prevSma7

      -- Leaf lookup
      leafAtBar = findLeafAtBar leaves barIdx
      isYangLeaf = case leafAtBar of
        Just (YangLeaf _) => True
        _ => False
      isYinLeaf = case leafAtBar of
        Just (YinLeaf _) => True
        _ => False

      -- hprd7: bars since last yang leaf end
      hprd7 : Integer
      hprd7 = case leafAtBar of
        Just (YangLeaf _) => 0
        _ => if st.prevLeafEnd >= 0
             then barIdx - st.prevLeafEnd
             else cast newSma7Count

      -- lprd7: bars since last yin leaf end
      lprd7 : Integer
      lprd7 = case leafAtBar of
        Just (YinLeaf _) => 0
        _ => if st.prevLeafEnd >= 0
             then barIdx - st.prevLeafEnd
             else cast newSma7Count

      hlhrows7 = hprd7

      -- Strategy signals
      kdjRight = kVal > dVal && newBarsKOnD <= 3
      bbuyVal = xlowVal && shiftedXlow && sma7Rising && kdjRight
      buyVal = (sma7Rising && kdjRight) || bbuyVal
      sellVal = (not sma7Rising) && (jVal < dVal) && (dVal < mVal) && (mVal > 65.0) && (newBarsDOnK < 3) && (st.prevLow < st.prevSma7)

      chartBar = MkChartBar
        { bar = bar, sma7 = sma7Val
        , bbm = bbmVal, bbu = bbuVal, bbl = bblVal
        , bb6u = bb6uVal, bb4u = bb4uVal, bb4l = bb4lVal, bb6l = bb6lVal
        , cmah7 = 0.0, cmal7 = 0.0, hlcmah7 = 0.0
        , k = kVal, d = dVal, j = jVal, m = mVal
        , signal = ""
        }

      newSt = MkIState
        newSma7Sum newSma7Count newSma7Window
        newBbSum newBbSumSq newBbCount newBbWindow
        sma7Val bbmVal bbuVal bblVal
        kVal dVal jVal mVal
        c lo
        newBarsKOnD newBarsDOnK
        newLowWindow newHighWindow
        (if isYangLeaf || isYinLeaf then barIdx else st.prevLeafEnd)
        isYangLeaf
      in (newSt, chartBar)

-- =========================================================================
-- computeChartBarsInc: single-pass fold, O(N) total
-- =========================================================================

public export
covering
computeChartBarsInc : {i : Interval} -> List Segment -> List (Bar i) -> List (ChartBar i)
computeChartBarsInc leaves bars =
  let (_, chartBars) = go initState 0 bars
  in chartBars
  where
    go : IState -> Integer -> List (Bar i) -> (IState, List (ChartBar i))
    go st _ [] = (st, [])
    go st idx (b :: bs) =
      let (newSt, cb) = stepBar st leaves b idx
          (_, rest) = go newSt (idx + 1) bs
      in (newSt, cb :: rest)
