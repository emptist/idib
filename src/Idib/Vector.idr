module Idib.Vector

import Data.List

%default total

-- =========================================================================
-- Indexed: pair each element with its integer index
-- =========================================================================

public export
indexed : List a -> List (Integer, a)
indexed xs = go 0 xs
  where
    go : Integer -> List a -> List (Integer, a)
    go _ [] = []
    go i (x :: rest) = (i, x) :: go (i + 1) rest

-- =========================================================================
-- Helper: compute window start and size for expanding/rolling
-- =========================================================================

windowParams : (i : Integer) -> (period : Nat) -> (start : Nat ** size : Nat ** ())
windowParams i period =
  let iPos = i + 1
      periodI = cast {from=Nat} {to=Integer} period
      windowSizeI = if iPos >= periodI then periodI else iPos
      startI = iPos - windowSizeI
      startN = cast {from=Integer} {to=Nat} startI
      sizeN = cast {from=Integer} {to=Nat} windowSizeI
  in (startN ** sizeN ** ())

-- =========================================================================
-- SMA: expanding-window mean — returns one value per input
-- For index i: window = xs[max(0, i-period+1)..i], mean(window)
-- =========================================================================

public export
smaSeries : (period : Nat) -> List Double -> List Double
smaSeries _ [] = []
smaSeries period xs = go 0 xs
  where
    go : Integer -> List Double -> List Double
    go _ [] = []
    go i (x :: rest) =
      let (startN ** sizeN ** _) = windowParams i period
          window = take sizeN (drop startN xs)
          s = foldl (+) 0.0 window
          avg = s / cast sizeN
      in avg :: go (i + 1) rest

-- =========================================================================
-- Mean
-- =========================================================================

public export
mean : List Double -> Double
mean [] = 0.0
mean xs = foldl (+) 0.0 xs / cast (length xs)

-- =========================================================================
-- Standard deviation (population) with fallback for single element
-- =========================================================================

public export
stdDev : (fallback : Double) -> List Double -> Double
stdDev _ [] = 0.0
stdDev _ (x :: []) = 0.1
stdDev _ xs =
  let n = length xs
      avg = mean xs
      variance = foldl (\acc, v => acc + (v - avg) * (v - avg)) 0.0 xs
  in sqrt (variance / cast n)

-- =========================================================================
-- Rolling max with expanding fallback
-- For index i: window = xs[max(0, i-period+1)..i], return max of window
-- =========================================================================

public export
rollingMax : (period : Nat) -> List Double -> List Double
rollingMax _ [] = []
rollingMax period xs = map (\(i, _) =>
    let (startN ** sizeN ** _) = windowParams i period
        window = take sizeN (drop startN xs)
    in foldl max 0.0 window
  ) (indexed xs)

-- =========================================================================
-- Rolling min with expanding fallback
-- =========================================================================

public export
rollingMin : (period : Nat) -> List Double -> List Double
rollingMin _ [] = []
rollingMin period xs = map (\(i, _) =>
    let (startN ** sizeN ** _) = windowParams i period
        window = take sizeN (drop startN xs)
    in foldl min 1.0e18 window
  ) (indexed xs)

-- =========================================================================
-- Running peak count: cumsum of (values[i] == cummax(values[i]))
-- =========================================================================

public export
runningPeakCount : List Double -> List Nat
runningPeakCount [] = []
runningPeakCount (x :: xs) = go x 1 [1] xs
  where
    go : Double -> Nat -> List Nat -> List Double -> List Nat
    go _ count acc [] = reverse acc
    go currentMax count acc (v :: rest) =
      let newMax = max v currentMax
          isPeak = abs (v - newMax) < 0.0001
          newCount = if isPeak then count + 1 else count
      in go newMax newCount (newCount :: acc) rest

-- =========================================================================
-- Rows within each group: bar index within each group (reset at boundaries)
-- =========================================================================

public export
rowsWithinEachGroup : List Nat -> List Nat
rowsWithinEachGroup [] = []
rowsWithinEachGroup (g :: gs) = go g 0 [0] gs
  where
    go : Nat -> Nat -> List Nat -> List Nat -> List Nat
    go _ _ acc [] = reverse acc
    go currentGroup rowInGroup acc (x :: rest) =
      let newRow = rowInGroup + 1
      in if x == currentGroup
         then go currentGroup newRow (newRow :: acc) rest
         else go x 0 (0 :: acc) rest

-- =========================================================================
-- Cumulative min within each group
-- =========================================================================

public export
cumulativeMinWithinGroups : List Double -> List Nat -> List Double
cumulativeMinWithinGroups [] [] = []
cumulativeMinWithinGroups [] _ = []
cumulativeMinWithinGroups _ [] = []
cumulativeMinWithinGroups (v :: vs) (g :: gs) = v :: go g v vs gs
  where
    go : Nat -> Double -> List Double -> List Nat -> List Double
    go _ _ [] [] = []
    go _ _ [] _ = []
    go _ _ _ [] = []
    go currentGroup currentMin (v :: rest) (gr :: restGr) =
      if gr == currentGroup
      then let newMin = min v currentMin
           in newMin :: go currentGroup newMin rest restGr
      else v :: go gr v rest restGr

-- =========================================================================
-- Cumulative max within each group
-- =========================================================================

public export
cumulativeMaxWithinGroups : List Double -> List Nat -> List Double
cumulativeMaxWithinGroups [] [] = []
cumulativeMaxWithinGroups [] _ = []
cumulativeMaxWithinGroups _ [] = []
cumulativeMaxWithinGroups (v :: vs) (g :: gs) = v :: go g v vs gs
  where
    go : Nat -> Double -> List Double -> List Nat -> List Double
    go _ _ [] [] = []
    go _ _ [] _ = []
    go _ _ _ [] = []
    go currentGroup currentMax (v :: rest) (gr :: restGr) =
      if gr == currentGroup
      then let newMax = max v currentMax
           in newMax :: go currentGroup newMax rest restGr
      else v :: go gr v rest restGr

-- =========================================================================
-- Running peak count against a reference series
-- =========================================================================

public export
runningPeakCountOnValues : List Double -> List Double -> List Nat
runningPeakCountOnValues [] [] = []
runningPeakCountOnValues [] _ = []
runningPeakCountOnValues _ [] = []
runningPeakCountOnValues (v :: vs) (t :: ts) =
  let initial = if abs (v - t) < 0.0001 then the Nat 1 else the Nat 0
  in initial :: go initial vs ts
  where
    go : Nat -> List Double -> List Double -> List Nat
    go _ [] [] = []
    go _ [] _ = []
    go _ _ [] = []
    go count (v :: rest) (t :: restTs) =
      let match = abs (v - t) < 0.0001
          newCount = if match then count + 1 else count
      in newCount :: go newCount rest restTs

-- =========================================================================
-- Expanding mean within each group (returns single last value)
-- =========================================================================

public export
findValuesInGroup : List (Double, Nat) -> Nat -> Double
findValuesInGroup paired target =
  let filtered = filter (\(_, g) => g == target) paired
      vals = map fst filtered
      s = foldl (+) 0.0 vals
      cnt = length vals
  in case cnt of
    0 => 0.0
    _ => s / cast cnt

public export
expandingMeanWithinGroups : List Double -> List Nat -> Double
expandingMeanWithinGroups [] _ = 0.0
expandingMeanWithinGroups _ [] = 0.0
expandingMeanWithinGroups xs groups =
  let paired = zip xs groups
      lastGroup = case reverse groups of
        [] => 0
        (g :: _) => g
  in findValuesInGroup paired lastGroup

-- =========================================================================
-- Expanding mean within each group — full series output
-- =========================================================================

public export
expandingMeanWithinGroupsSeries : List Double -> List Nat -> List (Integer, Double)
expandingMeanWithinGroupsSeries xs groups = go (zip xs groups) [] 0.0 0 (-1)
  where
    go : List (Double, Nat) -> List (Integer, Double) -> Double -> Nat -> Integer -> List (Integer, Double)
    go [] acc _ _ _ = reverse acc
    go ((val, group) :: rest) acc runningSum runningCount lastGroup =
      let idx = cast {from=Int} {to=Integer} (cast (length acc))
          grpInt = cast {from=Nat} {to=Integer} group
      in if grpInt == lastGroup
         then let newSum = runningSum + val
                  newCount = runningCount + 1
                  m = newSum / cast newCount
              in go rest ((idx, m) :: acc) newSum newCount lastGroup
         else go rest ((idx, val) :: acc) val 1 grpInt
