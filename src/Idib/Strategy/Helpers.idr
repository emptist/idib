module Idib.Strategy.Helpers

import Data.List

%default total

-- Helper: get Nat from list by index
natAt : Nat -> List Nat -> Nat
natAt _ [] = 0
natAt 0 (x :: _) = x
natAt (S k) (_ :: rest) = natAt k rest

-- Helper: get Bool from list by index
boolAt : Nat -> List Bool -> Bool
boolAt _ [] = False
boolAt 0 (x :: _) = x
boolAt (S k) (_ :: rest) = boolAt k rest

-- Helper: zip with index
zipWithIndex : List a -> Integer -> List (a, Integer)
zipWithIndex [] _ = []
zipWithIndex (x :: xs) i = (x, i) :: zipWithIndex xs (i + 1)

-- =========================================================================
-- shiftedBoolean: check if xlow was true at shifted-back positions
-- For each bar i: check xlow at (i - hlrows[i]) OR (i - hlhlrows[i])
-- Matches glib's shifted_boolean
-- =========================================================================

public export
shiftedBoolean : List Bool -> List Nat -> List Nat -> List Bool
shiftedBoolean [] _ _ = []
shiftedBoolean xlowValues hlrowsValues hlhlrowsValues =
  let len = length xlowValues
      indexed = zipWithIndex xlowValues 0
  in map (checkAt len) indexed
  where
    checkAt : Nat -> (Bool, Integer) -> Bool
    checkAt len (xlow, idx) =
      let hlrows = natAt (cast idx) hlrowsValues
          hlhlrows = natAt (cast idx) hlhlrowsValues
          pos1 = idx - cast hlrows
          pos2 = idx - cast hlhlrows
          val1 = if pos1 >= 0 && pos1 < cast len
                 then boolAt (cast pos1) xlowValues
                 else False
          val2 = if pos2 >= 0 && pos2 < cast len
                 then boolAt (cast pos2) xlowValues
                 else False
      in val1 || val2
