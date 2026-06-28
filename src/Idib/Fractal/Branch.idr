module Idib.Fractal.Branch

import Data.List
import Idib.Fractal.Leaf
import Idib.Fractal.Types

%default total

-- =========================================================================
-- Helpers
-- =========================================================================

barAt : List LeafBar -> Nat -> Double
barAt [] _ = 0.0
barAt (b :: bs) 0 = lbValue b
barAt (_ :: bs) (S k) = barAt bs k

leafEndVal : List LeafBar -> Segment -> Double
leafEndVal bars leaf = barAt bars (segEndIdx leaf)

-- =========================================================================
-- detectBranch: detect branch-level segments from leaf segments
--
-- Yang Branch: leaf end breaks above previous peak
--   startIdx  = previous trough leaf's end
--   recognIdx = breakout leaf's end
--   endIdx    = next trough leaf's end
--
-- Yin Branch: leaf end breaks below previous trough
--   startIdx  = previous peak leaf's end
--   recognIdx = breakout leaf's end
--   endIdx    = next peak leaf's end
-- =========================================================================

mutual
  covering
  lookYang : List LeafBar -> Nat -> Double -> Double -> Nat -> Nat
          -> List Segment -> List Segment -> List Segment
  lookYang bars idx prevPeak prevTrough peakIdx troughIdx acc [] = reverse acc
  lookYang bars idx prevPeak prevTrough peakIdx troughIdx acc (leaf :: leaves) =
    let val = leafEndVal bars leaf
        leafIdx = segEndIdx leaf
    in if idx == 0 then
      lookYang bars 1 val val leafIdx leafIdx acc leaves
    else if val > prevPeak then
      endYang bars (idx + 1) prevPeak prevTrough val peakIdx troughIdx leafIdx acc leaves
    else
      lookYang bars (idx + 1) (max prevPeak val) val peakIdx troughIdx acc leaves

  covering
  endYang : List LeafBar -> Nat -> Double -> Double -> Double -> Nat -> Nat
         -> Nat -> List Segment -> List Segment -> List Segment
  endYang bars idx peak trough prevTrough peakIdx troughIdx recognIdx acc [] = reverse acc
  endYang bars idx peak trough prevTrough peakIdx troughIdx recognIdx acc (leaf :: leaves) =
    let val = leafEndVal bars leaf
        leafIdx = segEndIdx leaf
    in if val < prevTrough then
      let startIdx = troughIdx
          branch = BranchSeg (MkFractal Rising startIdx leafIdx) recognIdx True
      in lookYin bars (idx + 1) val val leafIdx leafIdx (branch :: acc) leaves
    else
      endYang bars (idx + 1) (max peak val) (min trough val) prevTrough
        peakIdx troughIdx recognIdx acc leaves

  covering
  lookYin : List LeafBar -> Nat -> Double -> Double -> Nat -> Nat
         -> List Segment -> List Segment -> List Segment
  lookYin bars idx prevPeak prevTrough peakIdx troughIdx acc [] = reverse acc
  lookYin bars idx prevPeak prevTrough peakIdx troughIdx acc (leaf :: leaves) =
    let val = leafEndVal bars leaf
        leafIdx = segEndIdx leaf
    in if val < prevTrough then
      endYin bars (idx + 1) prevPeak prevTrough val peakIdx troughIdx leafIdx acc leaves
    else
      lookYin bars (idx + 1) val (min prevTrough val) peakIdx troughIdx acc leaves

  covering
  endYin : List LeafBar -> Nat -> Double -> Double -> Double -> Nat -> Nat
        -> Nat -> List Segment -> List Segment -> List Segment
  endYin bars idx peak trough prevPeak peakIdx troughIdx recognIdx acc [] = reverse acc
  endYin bars idx peak trough prevPeak peakIdx troughIdx recognIdx acc (leaf :: leaves) =
    let val = leafEndVal bars leaf
        leafIdx = segEndIdx leaf
    in if val > prevPeak then
      let startIdx = peakIdx
          branch = BranchSeg (MkFractal Falling startIdx leafIdx) recognIdx True
      in lookYang bars (idx + 1) val val leafIdx leafIdx (branch :: acc) leaves
    else
      endYin bars (idx + 1) (max peak val) (min trough val) prevPeak
        peakIdx troughIdx recognIdx acc leaves

public export
covering
detectBranch : BranchConfig -> List LeafBar -> List Segment -> List Segment
detectBranch config bars [] = []
detectBranch config bars leaves = lookYang bars 0 0.0 0.0 0 0 [] leaves

-- =========================================================================

public export
backCountSegment : Segment -> Nat
backCountSegment s = segBarsCount s

public export
isSegmentConfirmed : Segment -> Bool
isSegmentConfirmed = segConfirmed
