module Idib.MultiTF

import Data.List
import Idib.Types
import Idib.Indicators.ChartBar

%default total

-- =========================================================================
-- MultiTFBars: holds computed ChartBars for multiple intervals
-- =========================================================================

public export
record MultiTFBars where
  constructor MkMultiTFBars
  month3Bars : List (ChartBar Month3)
  month1Bars : List (ChartBar Month1)
  week1Bars  : List (ChartBar Week1)
  day1Bars   : List (ChartBar Day1)
  hour4Bars  : List (ChartBar Hour4)
  hour1Bars  : List (ChartBar Hour1)

-- =========================================================================
-- MultiTFRawBars: holds raw bars for multiple intervals
-- =========================================================================

public export
record MultiTFRawBars where
  constructor MkMultiTFRawBars
  month3Bars : List (Bar Month3)
  month1Bars : List (Bar Month1)
  week1Bars  : List (Bar Week1)
  day1Bars   : List (Bar Day1)
  hour4Bars  : List (Bar Hour4)
  hour1Bars  : List (Bar Hour1)

-- =========================================================================
-- computeAllChartsFromRaw: compute ChartBars for all intervals from raw bars
-- =========================================================================

public export
computeAllChartsFromRaw : IndicatorConfig -> MultiTFRawBars -> MultiTFBars
computeAllChartsFromRaw config rawBars =
  MkMultiTFBars
    { month3Bars = computeChartBars Month3 config rawBars.month3Bars
    , month1Bars = computeChartBars Month1 config rawBars.month1Bars
    , week1Bars  = computeChartBars Week1  config rawBars.week1Bars
    , day1Bars   = computeChartBars Day1   config rawBars.day1Bars
    , hour4Bars  = computeChartBars Hour4  config rawBars.hour4Bars
    , hour1Bars  = computeChartBars Hour1  config rawBars.hour1Bars
    }
