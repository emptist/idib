module Idib.Fractal.Analytics

import Data.List
import Idib.Fractal.Leaf
import Idib.Fractal.Branch

%default total

-- =========================================================================
-- SegmentMetrics: statistics of segments for AI pattern discovery
-- =========================================================================

public export
record SegmentMetrics where
  constructor MkSegmentMetrics
  totalSegments   : Nat
  risingSegments  : Nat
  fallingSegments : Nat
  avgSegLength    : Double
  avgSegReturn    : Double
  maxSegLength    : Nat
  minSegLength    : Nat

-- =========================================================================
-- helper: cast Nat to Double
-- =========================================================================

natToDouble : Nat -> Double
natToDouble n = cast n

-- =========================================================================
-- computeSegmentMetrics: compute metrics from a list of segments
-- =========================================================================

public export
computeSegmentMetrics : List Segment -> SegmentMetrics
computeSegmentMetrics [] = MkSegmentMetrics 0 0 0 0.0 0.0 0 0
computeSegmentMetrics segs =
  let totalN : Nat
      totalN = length segs
      rising : Nat
      rising = count (\s => segKind s == Rising) segs
      falling : Nat
      falling = count (\s => segKind s == Falling) segs
      lengths : List Nat
      lengths = map segBarsCount segs
      returns : List Double
      returns = map (\s => segEndValue s - segStartValue s) segs
      totalLen : Nat
      totalLen = foldr (+) 0 lengths
      totalRet : Double
      totalRet = foldr (+) 0.0 returns
      avgLen : Double
      avgLen = if totalN > 0 then natToDouble totalLen / natToDouble totalN else 0.0
      avgRet : Double
      avgRet = if totalN > 0 then totalRet / natToDouble totalN else 0.0
      maxLen : Nat
      maxLen = foldr max 0 lengths
      minLen : Nat
      minLen = foldr min 0 lengths
  in MkSegmentMetrics totalN rising falling avgLen avgRet maxLen minLen

-- =========================================================================
-- segmentCount: count all segments (recursive into branches)
-- =========================================================================

covering
public export
segmentCount : List Segment -> Nat
segmentCount segs = foldr (\s, acc => acc + 1 + segmentCount (segInnerSegments s)) 0 segs

-- =========================================================================
-- maxDrawdown: compute maximum drawdown within a segment
-- =========================================================================

public export
maxDrawdown : Segment -> Double
maxDrawdown seg =
  let bars : List LeafBar
      bars = segInnerBars seg
      endVal : Double
      endVal = segEndValue seg
      drops : List Double
      drops = map (\b => lbValue b - endVal) bars
  in foldr max 0.0 drops

-- =========================================================================
-- volatility: compute price volatility within a segment
-- =========================================================================

public export
volatility : Segment -> Double
volatility seg =
  let bars : List LeafBar
      bars = segInnerBars seg
      vals : List Double
      vals = map lbValue bars
      n : Nat
      n = length vals
      sum : Double
      sum = foldr (+) 0.0 vals
      meanVal : Double
      meanVal = if n > 0 then sum / natToDouble n else 0.0
      variance : Double
      variance = foldr (\x, acc => acc + (x - meanVal) * (x - meanVal)) 0.0 vals
      varianceNorm : Double
      varianceNorm = if n > 0 then variance / natToDouble n else 0.0
  in sqrt varianceNorm

-- =========================================================================
-- SegmentPattern: classify segment pattern for AI analysis
-- =========================================================================

public export
data SegmentPattern = Steep | Gradual | Choppy | Flat

public export
classifySegmentPattern : Segment -> SegmentPattern
classifySegmentPattern seg =
  let density : Nat
      density = length (segInnerBars seg)
      ret : Double
      ret = abs (segEndValue seg - segStartValue seg)
      len : Double
      len = natToDouble (segBarsCount seg)
  in if len == 0 then Flat
     else if density < 3 then Steep
     else if ret / len < 0.01 then Choppy
     else Gradual

-- =========================================================================
-- summarizeSegments: generate human-readable summary
-- =========================================================================

public export
summarizeSegments : List Segment -> String
summarizeSegments [] = "No segments detected"
summarizeSegments segs =
  let metrics = computeSegmentMetrics segs
      totalN = totalSegments metrics
      risingPct = if totalN > 0
                  then natToDouble (risingSegments metrics) / natToDouble totalN * 100
                  else 0.0
  in "Segments: " ++ show totalN
     ++ " (Rising: " ++ show risingPct ++ "%)"
     ++ " | Avg Length: " ++ show (avgSegLength metrics)
     ++ " | Avg Return: " ++ show (avgSegReturn metrics)
