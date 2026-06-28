module Idib.Fractal.Branch

import Data.List
import Idib.Fractal.Leaf
import Idib.Fractal.Types

%default total

-- =========================================================================
-- finalizeBranch: emit a BranchSeg from accumulated leaf segments
-- recognIdx = startIdx + confirmationBars (where we confirmed it)
-- =========================================================================

covering
finalizeBranch : Nat -> SegmentKind -> Nat -> Nat -> List Segment -> Segment
finalizeBranch confirmBars sk startIdx endIdx acc =
  BranchSeg (MkFractal sk startIdx (startIdx + confirmBars) endIdx) True

-- =========================================================================
-- extendBranchAcc: accumulate consecutive same-kind leaves into a branch
-- When an opposite-kind leaf appears, finalize and return remainder.
-- =========================================================================

covering
extendBranchAcc : Nat -> SegmentKind -> Nat -> List Segment -> List Segment
               -> (Segment, List Segment)
extendBranchAcc confirmBars sk startIdx acc [] =
  (finalizeBranch confirmBars sk startIdx (lastEndIdx acc) acc, [])
  where
    lastEndIdx : List Segment -> Nat
    lastEndIdx [] = startIdx
    lastEndIdx (s :: ss) = lastEndIdx' s ss
      where
        lastEndIdx' : Segment -> List Segment -> Nat
        lastEndIdx' x [] = segEndIdx x
        lastEndIdx' _ (x' :: xs) = lastEndIdx' x' xs
extendBranchAcc confirmBars sk startIdx acc (s :: ss) =
  if segKind s == sk then
    extendBranchAcc confirmBars sk startIdx (acc ++ [s]) ss
  else
    (finalizeBranch confirmBars sk startIdx (lastEndIdx acc) acc, s :: ss)
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
-- =========================================================================

covering
public export
detectBranch : BranchConfig -> List Segment -> List Segment
detectBranch config [] = []
detectBranch config segs =
  let n = config.confirmationBars
  in if n == 0 then [] else go n segs

  where
    go : Nat -> List Segment -> List Segment
    go _ [] = []
    go n (s :: ss) =
      let sk = segKind s
          startIdx = segStartIdx s
          (branch, remaining) = extendBranchAcc n sk startIdx [s] ss
      in branch :: go n remaining

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
