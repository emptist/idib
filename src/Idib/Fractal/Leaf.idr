module Idib.Fractal.Leaf

import Data.List

%default total

-- =========================================================================
-- SegmentKind: direction of a fractal segment
-- =========================================================================

public export
data SegmentKind = Rising | Falling

public export
Eq SegmentKind where
  (==) Rising Rising = True
  (==) Falling Falling = True
  (==) _ _ = False

public export
opposite : SegmentKind -> SegmentKind
opposite Rising = Falling
opposite Falling = Rising

-- =========================================================================
-- LeafBar: a single price point with index (source data element)
-- =========================================================================

public export
record LeafBar where
  constructor MkLeafBar
  lbIndex : Nat
  lbValue : Double

-- =========================================================================
-- Fractal: index range into source bars — the superclass record
-- No bar data stored. Source bars are the single truth.
-- =========================================================================

public export
record Fractal where
  constructor MkFractal
  fKind      : SegmentKind
  fStartIdx  : Nat
  fRecognIdx : Nat  -- where we recognize this segment (0 for leaves)
  fEndIdx    : Nat

-- =========================================================================
-- Segment: the recursive ADT
--   LeafSeg   — leaf-level extremum segment
--   BranchSeg — higher-level segment grouping consecutive same-kind leaves
-- =========================================================================

public export
data Segment : Type where
  LeafSeg   : Fractal -> Segment
  BranchSeg : Fractal -> Bool -> Segment

-- =========================================================================
-- Segment accessors
-- =========================================================================

public export
segKind : Segment -> SegmentKind
segKind (LeafSeg f)       = fKind f
segKind (BranchSeg f _)   = fKind f

public export
segStartIdx : Segment -> Nat
segStartIdx (LeafSeg f)       = fStartIdx f
segStartIdx (BranchSeg f _)   = fStartIdx f

public export
segRecognIdx : Segment -> Nat
segRecognIdx (LeafSeg f)       = fRecognIdx f
segRecognIdx (BranchSeg f _)   = fRecognIdx f

public export
segEndIdx : Segment -> Nat
segEndIdx (LeafSeg f)       = fEndIdx f
segEndIdx (BranchSeg f _)   = fEndIdx f

public export
segBarsCount : Segment -> Nat
segBarsCount s = minus (segEndIdx s) (segStartIdx s)

public export
isLeaf : Segment -> Bool
isLeaf (LeafSeg _)       = True
isLeaf (BranchSeg _ _)   = False

public export
isBranch : Segment -> Bool
isBranch (LeafSeg _)       = False
isBranch (BranchSeg _ _)   = True

public export
segConfirmed : Segment -> Bool
segConfirmed (LeafSeg _)       = False
segConfirmed (BranchSeg _ c)   = c

-- =========================================================================
-- slice: extract sub-list by index range
-- =========================================================================

public export
slice : List a -> Nat -> Nat -> List a
slice xs start end = take (minus end start) (drop start xs)

-- =========================================================================
-- Value helpers: look up bar value at segment start/end from source
-- =========================================================================

barAt : List LeafBar -> Nat -> Double
barAt [] _ = 0.0
barAt (b :: bs) 0 = lbValue b
barAt (_ :: bs) (S k) = barAt bs k

public export
segStartValue : List LeafBar -> Segment -> Double
segStartValue bars seg = barAt bars (segStartIdx seg)

public export
segEndValue : List LeafBar -> Segment -> Double
segEndValue bars seg = barAt bars (segEndIdx seg)
