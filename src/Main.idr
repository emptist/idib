module Main

import Idib.Types
import Idib.Indicators.ChartBar
import Idib.Strategy.SignalSeries
import Idib.Fractal.Leaf
import Idib.Fractal.LeafDetect
import Idib.Fractal.Branch
import Idib.Fractal.Analytics
import Idib.Fractal.Types

%default total

covering
testDetectLeaf : List LeafBar -> List Segment
testDetectLeaf = detectLeaf

covering
testDetectBranch : BranchConfig -> List LeafBar -> List Segment -> List Segment
testDetectBranch = detectBranch

main : IO ()
main = do
  let bars = [MkLeafBar 0 10.0, MkLeafBar 1 12.0, MkLeafBar 2 8.0, MkLeafBar 3 11.0]
  let leaves = testDetectLeaf bars
  putStrLn $ "Leaves: " ++ show (length leaves)
  let config = MkBranchConfig Day1 "SMA7"
  let branches = testDetectBranch config bars leaves
  putStrLn $ "Branches: " ++ show (length branches)
  putStrLn "idib library loaded"
