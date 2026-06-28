module Idib.Fractal.Analytics

import Data.List
import Idib.Fractal.Types
import Idib.Fractal.Leaf
import Idib.Fractal.Branch

%default total

-- =========================================================================
-- BranchMetrics: statistics of a branch for AI pattern discovery
-- =========================================================================

public export
record BranchMetrics where
  constructor MkBranchMetrics
  totalBranches   : Nat
  yangBranches    : Nat
  yinBranches     : Nat
  avgBranchLength : Double
  avgBranchReturn : Double
  maxBranchLength : Nat
  minBranchLength : Nat

-- =========================================================================
-- helper: cast Nat to Double
-- =========================================================================

natToDouble : Nat -> Double
natToDouble n = cast n

-- =========================================================================
-- computeBranchMetrics: compute metrics from a list of branches
-- =========================================================================

public export
computeBranchMetrics : List BranchResult -> BranchMetrics
computeBranchMetrics [] = MkBranchMetrics 0 0 0 0.0 0.0 0 0
computeBranchMetrics branches =
  let totalB : Nat
      totalB = length branches
      yangCount : Nat
      yangCount = count (\b => brKind b == Yang) branches
      yinCount : Nat
      yinCount = count (\b => brKind b == Yin) branches
      lengths : List Nat
      lengths = map branchBarsCount branches
      returns : List Double
      returns = map (\b => branchEndValue b - branchStartValue b) branches
      totalLen : Nat
      totalLen = foldr (+) 0 lengths
      totalRet : Double
      totalRet = foldr (+) 0.0 returns
      avgLen : Double
      avgLen = if totalB > 0
               then natToDouble totalLen / natToDouble totalB
               else 0.0
      avgRet : Double
      avgRet = if totalB > 0
               then totalRet / natToDouble totalB
               else 0.0
      maxLen : Nat
      maxLen = foldr max 0 lengths
      minLen : Nat
      minLen = foldr min 0 lengths
  in MkBranchMetrics totalB yangCount yinCount avgLen avgRet maxLen minLen

-- =========================================================================
-- leafCount: count leaves within a branch
-- =========================================================================

public export
leafCount : BranchResult -> Nat
leafCount branch = length (brInnerLeaves branch)

-- =========================================================================
-- maxDrawdown: compute maximum drawdown within a branch
-- =========================================================================

public export
maxDrawdown : BranchResult -> Double
maxDrawdown branch =
  let allLeaves : List Leaf
      allLeaves = brInnerLeaves branch
      endVal : Double
      endVal = branchEndValue branch
      drops : List Double
      drops = map (\l => value (startBar l) - endVal) allLeaves
  in foldr max 0.0 drops

-- =========================================================================
-- volatility: compute price volatility within a branch
-- =========================================================================

public export
volatility : BranchResult -> Double
volatility branch =
  let allLeaves : List Leaf
      allLeaves = brInnerLeaves branch
      vals : List Double
      vals = map (\l => value (startBar l)) allLeaves
      n : Nat
      n = length vals
      sum : Double
      sum = foldr (+) 0.0 vals
      meanVal : Double
      meanVal = if n > 0 then sum / natToDouble n else 0.0
      variance : Double
      variance = foldr (\x, acc => acc + (x - meanVal) * (x - meanVal)) 0.0 vals
      varianceNorm : Double
      varianceNorm = if n > 0 then variance / natToDouble n else 0.0
  in sqrt varianceNorm

-- =========================================================================
-- branchPattern: classify branch pattern for AI analysis
-- =========================================================================

public export
data BranchPattern = Steep | Gradual | Choppy | Flat

public export
classifyBranchPattern : BranchResult -> BranchPattern
classifyBranchPattern branch =
  let density = leafCount branch
      ret = abs (branchEndValue branch - branchStartValue branch)
      len = natToDouble (branchBarsCount branch)
  in if len == 0 then Flat
     else if density < 3 then Steep
     else if ret / len < 0.01 then Choppy
     else Gradual

-- =========================================================================
-- summarizeBranches: generate human-readable summary
-- =========================================================================

public export
summarizeBranches : List BranchResult -> String
summarizeBranches [] = "No branches detected"
summarizeBranches branches =
  let metrics = computeBranchMetrics branches
      totalB = totalBranches metrics
      yangPct = if totalB > 0
                then natToDouble (yangBranches metrics) / natToDouble totalB * 100
                else 0.0
  in "Branches: " ++ show totalB
     ++ " (Yang: " ++ show yangPct ++ "%)"
     ++ " | Avg Length: " ++ show (avgBranchLength metrics)
     ++ " | Avg Return: " ++ show (avgBranchReturn metrics)
