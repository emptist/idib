module Idib.Fractal.LeafDetect

import Data.List
import Data.So
import Idib.Fractal.Leaf

%default total

-- =========================================================================
-- Helpers
-- =========================================================================

lastWithDefault : List a -> a -> a
lastWithDefault [] fallback = fallback
lastWithDefault (x :: xs) fallback = lastWithDefault xs x

safeTail : List a -> List a
safeTail [] = []
safeTail (_ :: xs) = xs

-- =========================================================================
-- detectLeaf: detect alternating leaf sequence from a list of bars
-- Matches glib's running peak/trough count logic
-- =========================================================================

public export
detectLeaf : List LeafBar -> List Leaf
detectLeaf [] = []
detectLeaf (x :: xs) = go x x 1 [x] xs
  where
    go : LeafBar -> LeafBar -> Nat -> List LeafBar -> List LeafBar -> List Leaf
    go startY currentMax count acc [] =
      [MkLeaf YangLeaf startY (lastWithDefault acc currentMax) (reverse (safeTail acc))]
    go startY currentMax count acc (b :: rest) =
      if b.value > currentMax.value then
        let endBar = lastWithDefault acc currentMax
            innerBars = reverse (safeTail acc)
            leaf = MkLeaf YangLeaf startY endBar innerBars
        in leaf :: go b b 1 [b] rest
      else if b.value < startY.value then
        let endBar = lastWithDefault acc currentMax
            innerBars = reverse (safeTail acc)
            leaf = MkLeaf YinLeaf startY endBar innerBars
        in leaf :: go b b 1 [b] rest
      else
        go startY (if b.value > currentMax.value then b else currentMax) (count + 1) (b :: acc) rest
