module Idib.Strategy.Position

import Idib.Types

%default total

-- =========================================================================
-- Position: indexed state machine (simplified from plan)
-- Using Nat position like glib: 0 = flat, >0 = long count, <0 = short
-- =========================================================================

public export
record StrategyState where
  constructor MkStrategyState
  position   : Int
  entryPrice : Double
  lastSignal : String

public export
createStrategy : StrategyState
createStrategy = MkStrategyState 0 0.0 "initial"

-- =========================================================================
-- Update state based on signal
-- =========================================================================

public export
updateState : StrategyState -> (signalType : String) -> (price : Double) -> StrategyState
updateState state signalType price =
  let newPos = case signalType of
        "buy" => state.position + 1
        "sell" => state.position - 1
        _ => state.position
      newEntry = case signalType of
        "buy" => price
        _ => state.entryPrice
  in MkStrategyState newPos newEntry signalType
