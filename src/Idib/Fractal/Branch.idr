module Idib.Fractal.Branch

import Data.List
import Idib.Fractal.Leaf
import Idib.Fractal.Types

%default total

-- =========================================================================
-- finalizeBranch: create a BranchSeg from accumulated leaf segments
-- =========================================================================

covering
finalizeBranch : SegmentKind -> LeafBar -> LeafBar -> List Segment -> Segment
finalizeBranch sk start end acc =
  BranchSeg (MkFractal sk start end []) acc True

-- =========================================================================
-- extendBranchAcc: accumulate consecutive same-kind leaf segments
-- into one BranchSeg. When a leaf of opposite kind appears, stop.
-- Terminating: each step consumes one element from the tail.
-- =========================================================================

covering
extendBranchAcc : SegmentKind -> LeafBar -> List Segment -> List Segment
               -> (Segment, List Segment)
extendBranchAcc sk start acc [] =
  (finalizeBranch sk start (segEnd (lastSeg acc)) acc, [])
  where
    lastSeg : List Segment -> Segment
    lastSeg [] = LeafSeg (MkFractal sk start start [])
    lastSeg (s :: ss) = lastSeg' s ss
      where
        lastSeg' : Segment -> List Segment -> Segment
        lastSeg' x [] = x
        lastSeg' _ (x' :: xs) = lastSeg' x' xs
extendBranchAcc sk start acc (s :: ss) =
  if segKind s == sk then
    extendBranchAcc sk start (acc ++ [s]) ss
  else
    (finalizeBranch sk start (segEnd (lastSeg acc)) acc, s :: ss)
  where
    lastSeg : List Segment -> Segment
    lastSeg [] = LeafSeg (MkFractal sk start start [])
    lastSeg (x :: xs) = lastSeg' x xs
      where
        lastSeg' : Segment -> List Segment -> Segment
        lastSeg' x [] = x
        lastSeg' _ (x' :: xs) = lastSeg' x' xs

-- =========================================================================
-- detectBranch: group leaf segments into branch-level segments
--
-- Input:  List Segment (from detectLeaf — all LeafSeg)
-- Output: List Segment (BranchSeg wrapping groups of same-kind leaves)
--
-- Each BranchSeg contains its inner LeafSegs as children.
-- The recursive Segment type means branches can nest.
-- =========================================================================

covering
public export
detectBranch : BranchConfig -> List Segment -> List Segment
detectBranch config [] = []
detectBranch config segs =
  let n = config.confirmationBars
  in if n == 0 then [] else go segs

  where
    go : List Segment -> List Segment
    go [] = []
    go (s :: ss) =
      let sk = segKind s
          startB = segStart s
          (branch, remaining) = extendBranchAcc sk startB [s] ss
      in branch :: go remaining

-- =========================================================================
-- backCountSegment: count bars from segment start to end
-- =========================================================================

public export
backCountSegment : Segment -> Nat
backCountSegment s = segBarsCount s

-- =========================================================================
-- isSegmentConfirmed: check if branch meets confirmation criteria
-- =========================================================================

public export
isSegmentConfirmed : BranchConfig -> Segment -> Bool
isSegmentConfirmed config branch =
  config.confirmationBars <= segBarsCount branch
