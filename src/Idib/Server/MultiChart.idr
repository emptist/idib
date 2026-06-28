module Idib.Server.MultiChart

import Data.List
import Idib.Types
import Idib.MultiTF
import Idib.Indicators.ChartBar

%default total

-- =========================================================================
-- ChartDataBar: phantom-type-erased bar data for frontend
-- =========================================================================

public export
record ChartDataBar where
  constructor MkChartDataBar
  date   : String
  opn    : Double
  high   : Double
  low    : Double
  close  : Double
  volume : Nat
  sma7   : Double
  bbm    : Double
  bbu    : Double
  bbl    : Double
  bb6u   : Double
  bb4u   : Double
  bb4l   : Double
  bb6l   : Double
  k      : Double
  d      : Double
  j      : Double
  m      : Double
  signal : String

-- =========================================================================
-- ChartData: interval + bars for frontend display
-- =========================================================================

public export
record ChartData where
  constructor MkChartData
  interval : String
  bars     : List ChartDataBar

-- =========================================================================
-- convertChartBar: ChartBar i -> ChartDataBar (erases phantom type)
-- =========================================================================

convertChartBar : ChartBar i -> ChartDataBar
convertChartBar cb =
  MkChartDataBar
    { date = cb.bar.date
    , opn = cb.bar.opn
    , high = cb.bar.high
    , low = cb.bar.low
    , close = cb.bar.close
    , volume = cb.bar.volume
    , sma7 = cb.sma7
    , bbm = cb.bbm
    , bbu = cb.bbu
    , bbl = cb.bbl
    , bb6u = cb.bb6u
    , bb4u = cb.bb4u
    , bb4l = cb.bb4l
    , bb6l = cb.bb6l
    , k = cb.k
    , d = cb.d
    , j = cb.j
    , m = cb.m
    , signal = cb.signal
    }

-- =========================================================================
-- computeAllChartData: compute chart data for all intervals
-- =========================================================================

public export
computeAllChartData : IndicatorConfig -> MultiTFRawBars -> List ChartData
computeAllChartData config rawBars =
  let mtf = computeAllChartsFromRaw config rawBars
  in [ MkChartData "3mo" (map convertChartBar mtf.month3Bars)
     , MkChartData "1mo" (map convertChartBar mtf.month1Bars)
     , MkChartData "1wk" (map convertChartBar mtf.week1Bars)
     , MkChartData "1d"  (map convertChartBar mtf.day1Bars)
     , MkChartData "4h"  (map convertChartBar mtf.hour4Bars)
     , MkChartData "1h"  (map convertChartBar mtf.hour1Bars)
     ]
