module Idib.Types

import Data.Vect

%default total

-- =========================================================================
-- Interval: time-bar phantom type for compile-time safety
-- =========================================================================

public export
data Interval = Min1 | Min5 | Min15 | Min30 | Hour1 | Hour4 | Day1 | Week1 | Month1 | Month3

public export
Show Interval where
  show Min1 = "1m"
  show Min5 = "5m"
  show Min15 = "15m"
  show Min30 = "30m"
  show Hour1 = "1h"
  show Hour4 = "4h"
  show Day1 = "1d"
  show Week1 = "1wk"
  show Month1 = "1mo"
  show Month3 = "3mo"

public export
Eq Interval where
  (==) Min1 Min1 = True
  (==) Min5 Min5 = True
  (==) Min15 Min15 = True
  (==) Min30 Min30 = True
  (==) Hour1 Hour1 = True
  (==) Hour4 Hour4 = True
  (==) Day1 Day1 = True
  (==) Week1 Week1 = True
  (==) Month1 Month1 = True
  (==) Month3 Month3 = True
  (==) _ _ = False

-- =========================================================================
-- Bar: OHLCV bar indexed by interval
-- =========================================================================

public export
record Bar (i : Interval) where
  constructor MkBar
  date       : String
  opn        : Double
  high       : Double
  low        : Double
  close      : Double
  volume     : Nat

-- =========================================================================
-- ChartBar: Bar with all indicators precomputed
-- =========================================================================

public export
record ChartBar (i : Interval) where
  constructor MkChartBar
  bar      : Bar i
  sma7     : Double
  bbm      : Double
  bbu      : Double
  bbl      : Double
  bb6u     : Double
  bb4u     : Double
  bb4l     : Double
  bb6l     : Double
  cmah7    : Double
  cmal7    : Double
  hlcmah7  : Double
  k        : Double
  d        : Double
  j        : Double
  m        : Double
  signal   : String

-- =========================================================================
-- IndicatorConfig: compile-time defaults, no magic numbers
-- =========================================================================

public export
record IndicatorConfig where
  constructor MkConfig
  sma_period      : Nat
  kdj_period      : Nat
  kdj_k_period    : Nat
  kdj_d_period    : Nat
  kdj_m_period    : Nat
  bb_multiplier   : Double
  bb_std_fallback : Double

public export
defaultConfig : IndicatorConfig
defaultConfig = MkConfig 7 14 3 2 10 2.0 0.1

-- =========================================================================
-- Interval -> BB MA window mapping (equivalence to days)
-- =========================================================================

public export
bbMAWindow : Interval -> Nat
bbMAWindow Day1   = 140
bbMAWindow Week1  = 28
bbMAWindow Month1 = 7
bbMAWindow Month3 = 3
bbMAWindow Hour4  = 560
bbMAWindow Hour1  = 2240
bbMAWindow Min30  = 4480
bbMAWindow Min15  = 8960
bbMAWindow Min5   = 26880
bbMAWindow Min1   = 134400

-- =========================================================================
-- BarsPerMonth for Fish detection (interval-derived N)
-- =========================================================================

public export
barsPerMonth : Interval -> Nat
barsPerMonth Month1 = 1
barsPerMonth Month3 = 1
barsPerMonth Week1  = 4
barsPerMonth Day1   = 20
barsPerMonth Hour1  = 130
barsPerMonth Hour4  = 32
barsPerMonth Min30  = 0
barsPerMonth Min15  = 0
barsPerMonth Min5   = 0
barsPerMonth Min1   = 0

-- =========================================================================
-- Result types: full series output from indicator computation
-- =========================================================================

public export
record SmaResult (n : Nat) where
  constructor MkSmaResult
  sma7           : Double
  prev_sma7      : Double
  sma7_series    : Vect n Double
  cmah7          : Double
  cmal7          : Double
  hlcmah7        : Double
  cmah7_series   : Vect n Double
  cmal7_series   : Vect n Double
  hlcmah7_series : Vect n Double

public export
record BBResult (n : Nat) where
  constructor MkBBResult
  bbm  : Vect n Double
  bbu  : Vect n Double
  bbl  : Vect n Double
  bb6u : Vect n Double
  bb4u : Vect n Double
  bb4l : Vect n Double
  bb6l : Vect n Double

public export
record KDJResult (n : Nat) where
  constructor MkKDJResult
  k : Vect n Double
  d : Vect n Double
  j : Vect n Double
  m : Vect n Double

-- =========================================================================
-- Indicators: per-bar snapshot for strategy evaluation
-- =========================================================================

public export
record Indicators where
  constructor MkIndicators
  sma7       : Double
  prev_sma7  : Double
  bbm        : Double
  prev_bbm   : Double
  bbu        : Double
  bbl        : Double
  bb6u       : Double
  bb4u       : Double
  bb4l       : Double
  bb6l       : Double
  k          : Double
  d          : Double
  j          : Double
  prev_j     : Double
  m          : Double
  cmah7      : Double
  hlcmah7    : Double
  smas_up    : Bool
  cmas_up    : Bool
  bars_k_on_d : Nat
  bars_d_on_k : Nat
  xlow       : Bool
  hlrows     : Nat
  hlhlrows   : Nat
  bbuy       : Bool
