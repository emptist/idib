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
testPipeline : List (Bar Day1) -> (List ChartResult, FractalResult)
testPipeline = computeFractal {i=Day1}

main : IO ()
main = do
  let bars = [ MkBar "2024-01-01" 100.0 110.0 90.0 105.0 1000
             , MkBar "2024-01-02" 105.0 115.0 95.0 110.0 1200
             , MkBar "2024-01-03" 110.0 120.0 100.0 108.0 1100
             ]
  let (results, fractal) = testPipeline bars
  putStrLn $ "Results: " ++ show (length results)
  putStrLn $ "Leaves: " ++ show (length fractal.leaves)
  putStrLn $ "Bull: " ++ show fractal.bullMarket
  putStrLn "idib library loaded"
