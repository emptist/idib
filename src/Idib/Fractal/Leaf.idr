module Idib.Fractal.Leaf

import Data.List

%default total

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
  fStartIdx : Nat
  fEndIdx   : Nat

-- =========================================================================
-- Segment: four constructors, one per direction × level
--   No direction variable — direction is structural in the type.
--   Pattern matching tells you exactly what you have.
-- =========================================================================

public export
data Segment : Type where
  YangLeaf   : Fractal -> Segment
  YinLeaf    : Fractal -> Segment
  YangBranch : Fractal -> Nat -> Segment  -- recognIdx
  YinBranch  : Fractal -> Nat -> Segment  -- recognIdx

-- =========================================================================
-- Segment accessors — pattern match, no equality check needed
-- =========================================================================

public export
segStartIdx : Segment -> Nat
segStartIdx (YangLeaf f)       = fStartIdx f
segStartIdx (YinLeaf f)        = fStartIdx f
segStartIdx (YangBranch f _)   = fStartIdx f
segStartIdx (YinBranch f _)    = fStartIdx f

public export
segEndIdx : Segment -> Nat
segEndIdx (YangLeaf f)       = fEndIdx f
segEndIdx (YinLeaf f)        = fEndIdx f
segEndIdx (YangBranch f _)   = fEndIdx f
segEndIdx (YinBranch f _)    = fEndIdx f

public export
segBarsCount : Segment -> Nat
segBarsCount s = minus (segEndIdx s) (segStartIdx s)

public export
isLeaf : Segment -> Bool
isLeaf (YangLeaf _)     = True
isLeaf (YinLeaf _)      = True
isLeaf (YangBranch _ _) = False
isLeaf (YinBranch _ _)  = False

public export
isBranch : Segment -> Bool
isBranch (YangLeaf _)     = False
isBranch (YinLeaf _)      = False
isBranch (YangBranch _ _) = True
isBranch (YinBranch _ _)  = True

public export
segRecognIdx : Segment -> Nat
segRecognIdx (YangLeaf f)       = fStartIdx f  -- leaves: no delay
segRecognIdx (YinLeaf f)        = fStartIdx f
segRecognIdx (YangBranch _ r)   = r
segRecognIdx (YinBranch _ r)    = r

-- =========================================================================
-- slice: extract sub-list by index range
-- =========================================================================

public export
slice : List a -> Nat -> Nat -> List a
slice xs start end = take (minus end start) (drop start xs)

-- =========================================================================
-- Value helpers
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
