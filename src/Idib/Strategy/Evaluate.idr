module Idib.Strategy.Evaluate

import Idib.Types
import Idib.Strategy.Position

%default total

-- =========================================================================
-- evaluateEntry: when flat, decide what signal to emit
-- =========================================================================

evaluateEntry : (bar : Bar i) -> (buy : Bool) -> (bcall : Bool) -> (bput : Bool) -> (watch : Bool) -> String
evaluateEntry bar buy bcall bput watch =
  if bcall then "buy"
  else if buy then "buy"
  else if bput then "sell"
  else if watch then "watch"
  else "hold"

-- =========================================================================
-- evaluateExit: when in position, decide exit signal
-- =========================================================================

evaluateExit : (bar : Bar i) -> (sell : Bool) -> (bput : Bool) -> String
evaluateExit bar sell bput =
  if bput then "sell"
  else if sell then "sell"
  else "holding"

-- =========================================================================
-- evaluateBar: core strategy logic
-- Matches glib's evaluate_bar exactly
-- =========================================================================

public export
evaluateBar : StrategyState -> (bar : Bar i) -> (prevBar : Bar i) -> Indicators -> (StrategyState, String)
evaluateBar state bar prevBar ind =
  let smasUp = ind.smas_up
      cmasUp = ind.cmas_up
      avrgsBull = smasUp && cmasUp
      avrgsBear = not smasUp && not cmasUp

      kdjRight = ind.k > ind.d && ind.bars_k_on_d <= 3
      kdjLeft = ind.j < ind.d && ind.d < ind.m && ind.m > 65.0 && ind.bars_d_on_k < 3

      buy = (avrgsBull && kdjRight) || ind.bbuy
      sell = avrgsBear && kdjLeft && prevBar.low < ind.prev_sma7

      bcall = (buy && (bar.opn <= ind.bbu || bar.close <= ind.bbu)) || ind.bbuy
      bput = sell && (bar.opn >= ind.bbl || bar.close >= ind.bbl)

      watch = ind.prev_j < 8.0 && ind.j > ind.prev_j && bar.close > ind.bbm && ind.bbm > ind.prev_bbm

      signal = case state.position of
        0 => evaluateEntry bar buy bcall bput watch
        _ => evaluateExit bar sell bput

      newState = updateState state signal bar.close
  in (newState, signal)
