module Idib.Fractal.Branch

import Data.List
import Data.So
import Idib.Fractal.Types
import Idib.Fractal.Leaf

%default total

-- =========================================================================
-- BranchResult: a completed branch with inner leaf structure
-- =========================================================================

public export
record BranchResult where
  constructor MkBranchResult
  brKind       : BranchKind
  brStartBar   : LeafBar
  brEndBar     : LeafBar
  brInnerLeaves : List Leaf
  brConfirmed  : Bool
  brStartIdx   : Nat
  brEndIdx     : Nat

-- =========================================================================
-- Helper: convert LeafKind to BranchKind
-- =========================================================================

leafKindToBranchKind : LeafKind -> BranchKind
leafKindToBranchKind YangLeaf = Yang
leafKindToBranchKind YinLeaf  = Yin

-- =========================================================================
-- Accessors
-- =========================================================================

public export
branchStartIndex : BranchResult -> Nat
branchStartIndex b = b.brStartIdx

public export
branchEndIndex : BranchResult -> Nat
branchEndIndex b = b.brEndIdx

public export
branchBarsCount : BranchResult -> Nat
branchBarsCount b = minus b.brEndIdx b.brStartIdx

public export
branchConfirmed : BranchResult -> Bool
branchConfirmed b = b.brConfirmed

public export
branchStartValue : BranchResult -> Double
branchStartValue b = value b.brStartBar

public export
branchEndValue : BranchResult -> Double
branchEndValue b = value b.brEndBar

-- =========================================================================
-- finalizeBranch: create BranchResult from accumulated leaves
-- =========================================================================

covering
finalizeBranch : BranchKind -> LeafBar -> LeafBar -> List Leaf -> BranchResult
finalizeBranch bk start end acc =
  MkBranchResult
    bk
    start
    end
    acc
    True
    (index start)
    (index end)

-- =========================================================================
-- extendBranchAcc: extend branch while same direction, accumulate leaves
-- Terminating: each step drops one element from the tail list
-- =========================================================================

covering
extendBranchAcc : BranchKind -> LeafBar -> List Leaf -> List Leaf
                -> (BranchResult, List Leaf)
extendBranchAcc bk start acc [] = (finalizeBranch bk start (lastLeaf acc) acc, [])
  where
    lastLeaf : List Leaf -> LeafBar
    lastLeaf [] = start
    lastLeaf (l :: ls) = lastLeaf' l ls
      where
        lastLeaf' : Leaf -> List Leaf -> LeafBar
        lastLeaf' x [] = endBar x
        lastLeaf' _ (x' :: xs) = lastLeaf' x' xs
extendBranchAcc bk start acc (f :: fs) =
  let fbk = leafKindToBranchKind (kind f)
  in if fbk == bk then
    extendBranchAcc bk start (acc ++ [f]) fs
  else
    (finalizeBranch bk start (lastLeaf acc) acc, f :: fs)
  where
    lastLeaf : List Leaf -> LeafBar
    lastLeaf [] = start
    lastLeaf (l :: ls) = lastLeaf' l ls
      where
        lastLeaf' : Leaf -> List Leaf -> LeafBar
        lastLeaf' x [] = endBar x
        lastLeaf' _ (x' :: xs) = lastLeaf' x' xs

-- =========================================================================
-- detectBranch: detect branches from a list of leaves
-- Terminating: each step drops at least one element from the list
-- =========================================================================

covering
public export
detectBranch : BranchConfig -> List Leaf -> List BranchResult
detectBranch config [] = []
detectBranch config leaves =
  let n = config.confirmationBars
  in if n == 0 then [] else go leaves

  where
    go : List Leaf -> List BranchResult
    go [] = []
    go (f :: fs) =
      let initKind = leafKindToBranchKind (kind f)
          initStart = startBar f
          initEnd = endBar f
          (finalBranch, remaining) = extendBranchAcc initKind initStart [f] fs
      in finalBranch :: go remaining

-- =========================================================================
-- backCountLeaf: count bars within a leaf
-- =========================================================================

public export
backCountLeaf : Leaf -> Nat
backCountLeaf f = minus (index (endBar f)) (index (startBar f))

-- =========================================================================
-- isBranchConfirmed: check if branch meets confirmation criteria
-- =========================================================================

public export
isBranchConfirmed : BranchConfig -> BranchResult -> Bool
isBranchConfirmed config branch =
  let required = config.confirmationBars
      count = branchBarsCount branch
  in count >= required
