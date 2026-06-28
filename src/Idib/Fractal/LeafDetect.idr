module Idib.Fractal.LeafDetect

import Data.List
import Idib.Fractal.Leaf

%default total

-- =========================================================================
-- Helpers
-- =========================================================================

atIdx : List LeafBar -> Nat -> LeafBar
atIdx [] _ = MkLeafBar 0 0.0
atIdx (x :: _) 0 = x
atIdx (_ :: xs) (S k) = atIdx xs k

-- =========================================================================
-- detectLeaf: detect leaf-level segments from source bars
--
-- Uses running peak/trough logic (matches glib).
-- Returns List Segment — all YangLeaf/YinLeaf with index ranges.
-- Source bars remain the single truth.
-- =========================================================================

covering
public export
detectLeaf : List LeafBar -> List Segment
detectLeaf [] = []
detectLeaf bars = go 0 0 (lbValue (head bars)) 0 bars
  where
    head : List LeafBar -> LeafBar
    head [] = MkLeafBar 0 0.0
    head (x :: _) = x

    go : Nat -> Nat -> Double -> Nat -> List LeafBar -> List Segment
    go _ _ _ _ [] = []
    go startIdx extremumIdx extremumVal count bars =
      case bars of
        [] => []
        (b :: bs) =>
          let currentIdx = count
              currentVal = lbValue b
          in if currentVal > extremumVal then
            let leaf = YangLeaf (MkFractal startIdx currentIdx)
            in leaf :: go currentIdx currentIdx currentVal (count + 1) bs
          else if currentVal < lbValue (atIdx bars startIdx) then
            let leaf = YinLeaf (MkFractal startIdx currentIdx)
            in leaf :: go currentIdx currentIdx currentVal (count + 1) bs
          else
            let (newExtremumIdx, newExtremumVal) =
                  if currentVal > extremumVal
                    then (currentIdx, currentVal)
                    else (extremumIdx, extremumVal)
            in go startIdx newExtremumIdx newExtremumVal (count + 1) bs
