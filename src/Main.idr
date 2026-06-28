module Main

import Idib.Types
import Idib.Fractal.Leaf
import Idib.Fractal.LeafDetect
import Idib.Fractal.Branch
import Idib.Fractal.Types
import Idib.Indicators.Incremental
import Idib.Strategy.Position

%default total

covering
testInc : List Segment -> List (Bar Day1) -> List (ChartBar Day1)
testInc = computeChartBarsInc {i=Day1}

main : IO ()
main = do
  let bars = [MkLeafBar 0 10.0, MkLeafBar 1 12.0, MkLeafBar 2 8.0, MkLeafBar 3 11.0]
  let leaves = detectLeaf bars
  putStrLn $ "Leaves: " ++ show (length leaves)
  let dayBars = [MkBar "2024-01-01" 100.0 110.0 90.0 105.0 1000
                , MkBar "2024-01-02" 105.0 115.0 95.0 110.0 1200
                , MkBar "2024-01-03" 110.0 120.0 100.0 108.0 1100]
  let chartBars = testInc leaves dayBars
  putStrLn $ "ChartBars: " ++ show (length chartBars)
  putStrLn "idib library loaded"
