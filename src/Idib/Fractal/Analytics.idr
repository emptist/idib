module Idib.Fractal.Analytics

import Data.List
import Idib.Fractal.Leaf
import Idib.Fractal.Branch

%default total

-- =========================================================================
-- SegmentMetrics: statistics for AI pattern discovery
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
-- helpers
-- =========================================================================

natToDouble : Nat -> Double
natToDouble n = cast n

barAt : List LeafBar -> Nat -> Double
barAt [] _ = 0.0
barAt (b :: bs) 0 = lbValue b
barAt (_ :: bs) (S k) = barAt bs k

-- =========================================================================
-- computeSegmentMetrics: metrics from segments + source bars
-- =========================================================================

public export
computeSegmentMetrics : List LeafBar -> List Segment -> SegmentMetrics
computeSegmentMetrics _ [] = MkSegmentMetrics 0 0 0 0.0 0.0 0 0
computeSegmentMetrics bars segs =
  let totalN : Nat
      totalN = length segs
      rising : Nat
      rising = count (\s => segKind s == Rising) segs
      falling : Nat
      falling = count (\s => segKind s == Falling) segs
      lengths : List Nat
      lengths = map segBarsCount segs
      returns : List Double
      returns = map (\s => barAt bars (segEndIdx s) - barAt bars (segStartIdx s)) segs
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
-- maxDrawdown: max drop within a segment from source bars
-- =========================================================================

public export
maxDrawdown : List LeafBar -> Segment -> Double
maxDrawdown bars seg =
  let segmentBars : List LeafBar
      segmentBars = slice bars (segStartIdx seg) (segEndIdx seg)
      endVal : Double
      endVal = barAt bars (segEndIdx seg)
      drops : List Double
      drops = map (\b => lbValue b - endVal) segmentBars
  in foldr max 0.0 drops

-- =========================================================================
-- volatility: price volatility within a segment from source bars
-- =========================================================================

public export
volatility : List LeafBar -> Segment -> Double
volatility bars seg =
  let segmentBars : List LeafBar
      segmentBars = slice bars (segStartIdx seg) (segEndIdx seg)
      vals : List Double
      vals = map lbValue segmentBars
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
-- SegmentPattern: classify for AI analysis
-- =========================================================================

public export
data SegmentPattern = Steep | Gradual | Choppy | Flat

public export
classifySegmentPattern : List LeafBar -> Segment -> SegmentPattern
classifySegmentPattern bars seg =
  let density : Nat
      density = length (slice bars (segStartIdx seg) (segEndIdx seg))
      ret : Double
      ret = abs (barAt bars (segEndIdx seg) - barAt bars (segStartIdx seg))
      len : Double
      len = natToDouble (segBarsCount seg)
  in if len == 0 then Flat
     else if density < 3 then Steep
     else if ret / len < 0.01 then Choppy
     else Gradual

-- =========================================================================
-- summarizeSegments: human-readable summary
-- =========================================================================

public export
summarizeSegments : List LeafBar -> List Segment -> String
summarizeSegments _ [] = "No segments detected"
summarizeSegments bars segs =
  let metrics = computeSegmentMetrics bars segs
      totalN = totalSegments metrics
      risingPct = if totalN > 0
                  then natToDouble (risingSegments metrics) / natToDouble totalN * 100
                  else 0.0
  in "Segments: " ++ show totalN
     ++ " (Rising: " ++ show risingPct ++ "%)"
     ++ " | Avg Length: " ++ show (avgSegLength metrics)
     ++ " | Avg Return: " ++ show (avgSegReturn metrics)
