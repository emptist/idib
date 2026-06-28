module Idib.Fractal.Types

import Idib.Types

%default total

-- =========================================================================
-- BranchConfig: configuration for branch-level detection
-- No confirmationBars — recognition point determined by algorithm
-- =========================================================================

public export
record BranchConfig where
  constructor MkBranchConfig
  interval         : Interval
  valueSeries      : String

-- =========================================================================
-- defaultBranchConfig: default configuration for an interval
-- =========================================================================

public export
defaultBranchConfig : Interval -> BranchConfig
defaultBranchConfig interval =
  MkBranchConfig interval "SMA7"
