module Idib.Fractal.Types

import Data.List
import Data.So
import Idib.Types
import Idib.Fractal.Leaf

%default total

-- =========================================================================
-- BranchKind: Yang (rising) or Yin (falling)
-- =========================================================================

public export
data BranchKind = Yang | Yin

public export
Eq BranchKind where
  (==) Yang Yang = True
  (==) Yin Yin = True
  (==) _ _ = False

public export
oppositeBranch : BranchKind -> BranchKind
oppositeBranch Yang = Yin
oppositeBranch Yin  = Yang

-- =========================================================================
-- BranchConfig: configuration for branch detection
-- =========================================================================

public export
record BranchConfig where
  constructor MkBranchConfig
  confirmationBars : Nat  -- N = 2 * barsPerMonth(interval), or 0 if disabled
  interval         : Interval
  valueSeries      : String

-- =========================================================================
-- branchBarsPerMonth: interval-derived N for branch detection
-- Disabled for sub-hourly (Min1/5/15/30 return 0)
-- =========================================================================

public export
branchBarsPerMonth : Interval -> Nat
branchBarsPerMonth Month1 = 1
branchBarsPerMonth Month3 = 1
branchBarsPerMonth Week1  = 4
branchBarsPerMonth Day1   = 20
branchBarsPerMonth Hour1  = 130
branchBarsPerMonth Hour4  = 32
branchBarsPerMonth Min30  = 0   -- DISABLED
branchBarsPerMonth Min15  = 0   -- DISABLED
branchBarsPerMonth Min5   = 0   -- DISABLED
branchBarsPerMonth Min1   = 0   -- DISABLED

-- =========================================================================
-- branchEnabled: only run detection if confirmationBars > 0
-- =========================================================================

public export
branchEnabled : BranchConfig -> Bool
branchEnabled config = config.confirmationBars > 0

-- =========================================================================
-- defaultBranchConfig: default configuration for an interval
-- =========================================================================

public export
defaultBranchConfig : Interval -> BranchConfig
defaultBranchConfig interval =
  let bp = branchBarsPerMonth interval
  in MkBranchConfig (if bp == 0 then 0 else 2 * bp) interval "SMA7"

-- =========================================================================
-- Branch: cross-leaf segment with confirmation
-- =========================================================================

public export
record Branch where
  constructor MkBranch
  kind        : BranchKind
  startIndex  : Nat
  endIndex    : Nat
  startValue  : Double
  endValue    : Double
  bars        : List LeafBar
  confirmed   : Bool

-- =========================================================================
-- BranchSeq: alternating branch sequence
-- =========================================================================

public export
data BranchSeq : BranchKind -> Type where
  FSSingle : (f : Branch) -> {auto prf : kind f = k} -> BranchSeq k
  FSCons   : (f : Branch) -> {auto prf : kind f = k}
           -> BranchSeq (oppositeBranch k)
           -> BranchSeq k

-- =========================================================================
-- Helper functions
-- =========================================================================

public export
branchStartValue : Branch -> Double
branchStartValue b = b.startValue

public export
branchEndValue : Branch -> Double
branchEndValue b = b.endValue

public export
branchLength : Branch -> Nat
branchLength b = minus b.endIndex b.startIndex
