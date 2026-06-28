module Idib.Fractal.Branch

import Data.List
import Idib.Fractal.Leaf
import Idib.Fractal.Types

%default total

-- =========================================================================
-- finalizeBranch: emit a BranchSeg from accumulated leaf segments
-- recognIdx = endIdx of the first leaf in the group (recognition point)
-- =========================================================================

covering
finalizeBranch : SegmentKind -> Nat -> Nat -> Nat -> List Segment -> Segment
finalizeBranch sk startIdx recognIdx endIdx acc =
  BranchSeg (MkFractal sk startIdx endIdx) recognIdx True

-- =========================================================================
-- extendBranchAcc: accumulate consecutive same-kind leaves into a branch
-- When an opposite-kind leaf appears, finalize and return remainder.
-- recognIdx = endIdx of the first leaf (that's when we know it's a branch)
-- =========================================================================

covering
extendBranchAcc : SegmentKind -> Nat -> List Segment -> List Segment
               -> (Segment, List Segment)
extendBranchAcc sk startIdx acc [] =
  (finalizeBranch sk startIdx startIdx (lastEndIdx acc) acc, [])
  where
    lastEndIdx : List Segment -> Nat
    lastEndIdx [] = startIdx
    lastEndIdx (s :: ss) = lastEndIdx' s ss
      where
        lastEndIdx' : Segment -> List Segment -> Nat
        lastEndIdx' x [] = segEndIdx x
        lastEndIdx' _ (x' :: xs) = lastEndIdx' x' xs
extendBranchAcc sk startIdx acc (s :: ss) =
  if segKind s == sk then
    extendBranchAcc sk startIdx (acc ++ [s]) ss
  else
    (finalizeBranch sk startIdx startIdx (lastEndIdx acc) acc, s :: ss)
  where
    lastEndIdx : List Segment -> Nat
    lastEndIdx [] = startIdx
    lastEndIdx (x :: xs) = lastEndIdx' x xs
      where
        lastEndIdx' : Segment -> List Segment -> Nat
        lastEndIdx' x [] = segEndIdx x
        lastEndIdx' _ (x' :: xs) = lastEndIdx' x' xs

-- =========================================================================
-- detectBranch: group leaf segments into branch-level segments
-- No confirmationBars — algorithm determines recognition from data.
-- A branch is recognized when consecutive same-kind leaves form a group.
-- =========================================================================

covering
public export
detectBranch : BranchConfig -> List Segment -> List Segment
detectBranch config [] = []
detectBranch config segs = go segs

  where
    go : List Segment -> List Segment
    go [] = []
    go (s :: ss) =
      let sk = segKind s
          startIdx = segStartIdx s
          (branch, remaining) = extendBranchAcc sk startIdx [s] ss
      in branch :: go remaining

-- =========================================================================
-- backCountSegment: count bars from segment start to end
-- =========================================================================

public export
backCountSegment : Segment -> Nat
backCountSegment s = segBarsCount s

-- =========================================================================
-- isSegmentConfirmed: check if branch is confirmed
-- =========================================================================

public export
isSegmentConfirmed : Segment -> Bool
isSegmentConfirmed = segConfirmed
