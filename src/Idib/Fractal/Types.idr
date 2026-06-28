module Idib.Fractal.Types

import Idib.Types
import Idib.Fractal.Leaf

%default total

-- =========================================================================
-- BranchConfig: configuration for branch-level detection
-- =========================================================================

public export
record BranchConfig where
  constructor MkBranchConfig
  confirmationBars : Nat
  interval         : Interval
  valueSeries      : String

-- =========================================================================
-- branchBarsPerMonth: interval-derived N for branch detection
-- Sub-hourly returns 0 (disabled)
-- =========================================================================

public export
branchBarsPerMonth : Interval -> Nat
branchBarsPerMonth Month1 = 1
branchBarsPerMonth Month3 = 1
branchBarsPerMonth Week1  = 4
branchBarsPerMonth Day1   = 20
branchBarsPerMonth Hour1  = 130
branchBarsPerMonth Hour4  = 32
branchBarsPerMonth Min30  = 0
branchBarsPerMonth Min15  = 0
branchBarsPerMonth Min5   = 0
branchBarsPerMonth Min1   = 0

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
