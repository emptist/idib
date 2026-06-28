module Idib.Fractal.LeafDetect

import Data.List
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
-- Detects leaf-level segments using running peak/trough.
-- Matches glib's running peak/trough logic.
--
-- Algorithm:
--   Track current segment start and extremum.
--   When a bar exceeds the extremum → finalize current leaf, start new one.
--   Always starts with a Rising (Yang) leaf — first bar is a trough.
--
-- Returns: List Segment (all LeafSeg)
-- =========================================================================

public export
detectLeaf : List LeafBar -> List Segment
detectLeaf [] = []
detectLeaf (x :: xs) = go x x 1 [x] xs
  where
    mkLeaf : SegmentKind -> LeafBar -> LeafBar -> List LeafBar -> Segment
    mkLeaf sk s e inner = LeafSeg (MkFractal sk s e inner)

    go : LeafBar -> LeafBar -> Nat -> List LeafBar -> List LeafBar -> List Segment
    go startY currentMax count acc [] =
      [mkLeaf Rising startY (lastWithDefault acc currentMax) (reverse (safeTail acc))]
    go startY currentMax count acc (b :: rest) =
      if lbValue b > lbValue currentMax then
        let leaf = mkLeaf Rising startY (lastWithDefault acc currentMax) (reverse (safeTail acc))
        in leaf :: go b b 1 [b] rest
      else if lbValue b < lbValue startY then
        let leaf = mkLeaf Falling startY (lastWithDefault acc currentMax) (reverse (safeTail acc))
        in leaf :: go b b 1 [b] rest
      else
        let newMax = if lbValue b > lbValue currentMax then b else currentMax
        in go startY newMax (count + 1) (b :: acc) rest
