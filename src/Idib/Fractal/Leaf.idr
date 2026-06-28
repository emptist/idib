module Idib.Fractal.Leaf

import Data.List
import Data.So

%default total

-- =========================================================================
-- LeafKind: Yang (rising from low) or Yin (falling from high)
-- =========================================================================

public export
data LeafKind = YangLeaf | YinLeaf

public export
opposite : LeafKind -> LeafKind
opposite YangLeaf = YinLeaf
opposite YinLeaf  = YangLeaf

-- =========================================================================
-- LeafBar: a single value with index
-- =========================================================================

public export
record LeafBar where
  constructor MkLeafBar
  index : Nat
  value : Double

-- =========================================================================
-- Leaf: a verified segment with extremum proof
-- =========================================================================

public export
isExtremal : LeafKind -> LeafBar -> List LeafBar -> Bool
isExtremal YangLeaf s bars = all (\b => s.value <= b.value) bars
isExtremal YinLeaf  s bars = all (\b => s.value >= b.value) bars

public export
record Leaf where
  constructor MkLeaf
  kind      : LeafKind
  startBar  : LeafBar
  endBar    : LeafBar
  innerBars : List LeafBar

-- =========================================================================
-- LeafSeq: alternating leaf sequence (fractal structure)
-- =========================================================================

public export
data LeafSeq : LeafKind -> Type where
  LFSSingle : (f : Leaf) -> {auto prfKind : kind f = k} -> LeafSeq k
  LFSCons   : (f : Leaf) -> {auto prfKind : kind f = k}
           -> LeafSeq (opposite k)
           -> LeafSeq k

-- =========================================================================
-- Helper functions
-- =========================================================================

public export
leafValue : LeafBar -> Double
leafValue b = b.value

public export
isNewHigh : LeafBar -> Leaf -> Bool
isNewHigh b f = b.value > f.startBar.value

public export
isNewLow : LeafBar -> Leaf -> Bool
isNewLow b f = b.value < f.startBar.value

public export
newLeafTriggered : LeafBar -> Leaf -> Bool
newLeafTriggered b f =
  case kind f of
    YangLeaf => isNewHigh b f  -- new high → spawn YinLeaf
    YinLeaf  => isNewLow  b f  -- new low  → spawn YangLeaf

-- =========================================================================
-- Helper functions
-- =========================================================================
