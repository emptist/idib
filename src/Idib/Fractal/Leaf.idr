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
-- =========================================================================

public export
record Fractal where
  constructor MkFractal
  fKind     : SegmentKind
  fStartIdx : Nat
  fEndIdx   : Nat

-- =========================================================================
-- Segment: the recursive ADT
--   LeafSeg   — leaf-level extremum segment (no recognition delay)
--   BranchSeg — higher-level segment with recognIdx
-- =========================================================================

public export
data Segment : Type where
  LeafSeg   : Fractal -> Segment
  BranchSeg : Fractal -> Nat -> Bool -> Segment
  --                     ^recognIdx

-- =========================================================================
-- Segment accessors
-- =========================================================================

public export
segKind : Segment -> SegmentKind
segKind (LeafSeg f)         = fKind f
segKind (BranchSeg f _ _)   = fKind f

public export
segStartIdx : Segment -> Nat
segStartIdx (LeafSeg f)         = fStartIdx f
segStartIdx (BranchSeg f _ _)   = fStartIdx f

public export
segEndIdx : Segment -> Nat
segEndIdx (LeafSeg f)         = fEndIdx f
segEndIdx (BranchSeg f _ _)   = fEndIdx f

public export
segBarsCount : Segment -> Nat
segBarsCount s = minus (segEndIdx s) (segStartIdx s)

public export
isLeaf : Segment -> Bool
isLeaf (LeafSeg _)         = True
isLeaf (BranchSeg _ _ _)   = False

public export
isBranch : Segment -> Bool
isBranch (LeafSeg _)         = False
isBranch (BranchSeg _ _ _)   = True

public export
segRecognIdx : Segment -> Nat
segRecognIdx (LeafSeg f)         = fStartIdx f  -- leaves: same as start
segRecognIdx (BranchSeg _ r _)   = r

public export
segConfirmed : Segment -> Bool
segConfirmed (LeafSeg _)         = False
segConfirmed (BranchSeg _ _ c)   = c

-- =========================================================================
-- slice: extract sub-list by index range
-- =========================================================================

public export
slice : List a -> Nat -> Nat -> List a
slice xs start end = take (minus end start) (drop start xs)

-- =========================================================================
-- Value helpers: look up bar value from source bars by index
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
