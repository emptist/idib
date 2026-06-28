module Idib.Strategy.MultiTF

import Data.List
import Idib.Types
import Idib.MultiTF
import Idib.Strategy.Position

%default total

-- =========================================================================
-- MultiTFIndicators: current bar indicators + higher-TF context
-- =========================================================================

public export
record MultiTFIndicators where
  constructor MkMultiTFIndicators
  current : Indicators
  month1  : Maybe Indicators
  week1   : Maybe Indicators
  day1    : Maybe Indicators

-- =========================================================================
-- Internal helpers (defined before use)
-- =========================================================================

-- Entry evaluation with multi-TF
evaluateEntryMTF : (bar : Bar i) -> (buy : Bool) -> (bcall : Bool) -> (bput : Bool) -> (watch : Bool) -> String
evaluateEntryMTF bar buy bcall bput watch =
  if bcall then "buy"
  else if buy then "buy"
  else if bput then "sell"
  else if watch then "watch"
  else "hold"

-- Exit evaluation with multi-TF
evaluateExitMTF : (bar : Bar i) -> (sell : Bool) -> (bput : Bool) -> String
evaluateExitMTF bar sell bput =
  if bput then "sell"
  else if sell then "sell"
  else "holding"

-- =========================================================================
-- evaluateBarMTF: strategy with multi-TF context
-- =========================================================================

public export
evaluateBarMTF : StrategyState -> (bar : Bar i) -> (prevBar : Bar i) -> MultiTFIndicators -> (StrategyState, String)
evaluateBarMTF state bar prevBar mtfInd =
  let ind = mtfInd.current

      -- Basic conditions (same as single-TF)
      smasUp = ind.smas_up
      cmasUp = ind.cmas_up
      avrgsBull = smasUp && cmasUp
      avrgsBear = not smasUp && not cmasUp

      kdjRight = ind.k > ind.d && ind.bars_k_on_d <= 3
      kdjLeft = ind.j < ind.d && ind.d < ind.m && ind.m > 65.0 && ind.bars_d_on_k < 3

      buy = (avrgsBull && kdjRight) || ind.bbuy
      sell = avrgsBear && kdjLeft && bar.low < ind.prev_sma7

      -- Multi-TF filter: higher TF must be bullish
      higherTFBullish = case mtfInd.month1 of
        Nothing => True
        Just m1 => m1.smas_up && m1.cmas_up

      -- Adjusted signals with multi-TF filter
      filteredBuy = buy && higherTFBullish
      filteredSell = sell

      bcall = (filteredBuy && (bar.opn <= ind.bbu || bar.close <= ind.bbu)) || ind.bbuy
      bput = filteredSell && (bar.opn >= ind.bbl || bar.close >= ind.bbl)

      watch = ind.prev_j < 8.0 && ind.j > ind.prev_j && bar.close > ind.bbm && ind.bbm > ind.prev_bbm

      signal = case state.position of
        0 => evaluateEntryMTF bar filteredBuy bcall bput watch
        _ => evaluateExitMTF bar filteredSell bput

      newState = updateState state signal bar.close
  in (newState, signal)
