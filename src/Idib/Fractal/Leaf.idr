module Idib.Fractal.Leaf

import Data.List

%default total

-- =========================================================================
-- SegmentKind: direction of a fractal segment
-- Replaces both LeafKind and BranchKind — one type for all levels
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
-- LeafBar: a single price point with index
-- =========================================================================

public export
record LeafBar where
  constructor MkLeafBar
  lbIndex : Nat
  lbValue : Double

-- =========================================================================
-- Fractal: the common record shared by all segment levels
-- In OOP this would be the abstract superclass of Branch and Leaf
-- =========================================================================

public export
record Fractal where
  constructor MkFractal
  fKind     : SegmentKind
  fStart    : LeafBar
  fEnd      : LeafBar
  fInner    : List LeafBar

-- =========================================================================
-- Segment: the recursive ADT — two constructors, same base shape
--   LeafSeg    — leaf-level extremum segment
--   BranchSeg  — higher-level segment containing inner Segments
-- =========================================================================

public export
data Segment : Type where
  LeafSeg   : Fractal -> Segment
  BranchSeg : Fractal -> List Segment -> Bool -> Segment

-- =========================================================================
-- Segment accessors: pattern-match to extract common fields
-- =========================================================================

public export
segKind : Segment -> SegmentKind
segKind (LeafSeg f)       = fKind f
segKind (BranchSeg f _ _) = fKind f

public export
segStart : Segment -> LeafBar
segStart (LeafSeg f)       = fStart f
segStart (BranchSeg f _ _) = fStart f

public export
segEnd : Segment -> LeafBar
segEnd (LeafSeg f)       = fEnd f
segEnd (BranchSeg f _ _) = fEnd f

public export
segStartIdx : Segment -> Nat
segStartIdx s = lbIndex (segStart s)

public export
segEndIdx : Segment -> Nat
segEndIdx s = lbIndex (segEnd s)

public export
segStartValue : Segment -> Double
segStartValue s = lbValue (segStart s)

public export
segEndValue : Segment -> Double
segEndValue s = lbValue (segEnd s)

public export
segBarsCount : Segment -> Nat
segBarsCount s = minus (segEndIdx s) (segStartIdx s)

-- =========================================================================
-- Leaf-specific helpers
-- =========================================================================

public export
segInnerBars : Segment -> List LeafBar
segInnerBars (LeafSeg f)       = fInner f
segInnerBars (BranchSeg f _ _) = fInner f

public export
isLeaf : Segment -> Bool
isLeaf (LeafSeg _)       = True
isLeaf (BranchSeg _ _ _) = False

public export
isBranch : Segment -> Bool
isBranch (LeafSeg _)       = False
isBranch (BranchSeg _ _ _) = True

-- =========================================================================
-- Branch-specific helpers
-- =========================================================================

public export
segConfirmed : Segment -> Bool
segConfirmed (LeafSeg _)         = False
segConfirmed (BranchSeg _ _ c)   = c

public export
segInnerSegments : Segment -> List Segment
segInnerSegments (LeafSeg _)         = []
segInnerSegments (BranchSeg _ ss _)  = ss

-- =========================================================================
-- isExtremal: check if a bar is an extremum within a list
-- Yang (Rising) = minimum, Yin (Falling) = maximum
-- =========================================================================

public export
isExtremal : SegmentKind -> LeafBar -> List LeafBar -> Bool
isExtremal Rising  s bars = all (\b => lbValue s <= lbValue b) bars
isExtremal Falling s bars = all (\b => lbValue s >= lbValue b) bars

-- =========================================================================
-- newSegmentTriggered: check if a new bar triggers a new segment
-- =========================================================================

public export
newSegmentTriggered : LeafBar -> Segment -> Bool
newSegmentTriggered b s =
  case segKind s of
    Rising  => lbValue b > lbValue (segStart s)
    Falling => lbValue b < lbValue (segStart s)

-- =========================================================================
-- leafValue: extract value from a LeafBar
-- =========================================================================

public export
leafValue : LeafBar -> Double
leafValue = lbValue
