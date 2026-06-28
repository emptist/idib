# Deviations from Plan

## 1. Vect → List for Internal Computations

**Plan**: All indicator functions use `Vect n Double` — length-indexed vectors that prove output length equals input length at compile time.

**Implementation**: Internal helper functions (`Vector.idr`, indicator internals) use `List Double`. The public API of indicator modules will use `List` as well.

**Rationale**: Idris 2's `Vect` requires length proofs for operations like `take`, `drop`, `zip`, and `map`. These proofs are possible but extremely verbose for numeric code with rolling windows. The practical cost (hundreds of lines of proof terms) outweighs the benefit for a trading system where:
- All indicators are tested against glib's output bitwise
- Length mismatches are caught immediately by zipping into `ChartBar`
- The type system still enforces interval safety via phantom types on `Bar i`

**Compromise**: `Bar i` retains its phantom `Interval` parameter for compile-time interval safety. The length guarantee is enforced structurally by `computeChartBars` which zips all series by index.

## 2. Integer for Index Arithmetic

**Plan**: Use `Nat` for all indices (natural numbers).

**Implementation**: Use `Integer` for loop indices and window arithmetic, converting to `Nat` only at `take`/`drop` boundaries.

**Rationale**: Idris 2's `Nat` subtraction (`minus`) doesn't require `Neg`, but the `-` operator on `Nat` does require `Neg Nat` which isn't available. Since window start is always `i + 1 - windowSize` where `windowSize ≤ i + 1`, the subtraction is always non-negative, but Idris can't prove this. Using `Integer` avoids the proof burden.

## 3. Field Name `opn` instead of `open`

**Plan**: `open : Double` in `Bar` record.

**Implementation**: `opn : Double` — `open` is a reserved keyword in Idris 2.

## 4. BB Window Calculation

**Plan**: `bbMAWindow` returns `Nat` values like 140, 28, 7, etc. based on interval equivalence to days.

**Implementation**: Same mapping, but the glib reference uses a formula `140 / equivalence_to_days(interval)` with ceiling. The discrete values in Types.idr are pre-computed approximations of this formula for each interval.

## 5. CMA Chain Simplification

**Plan**: Full ibOptions CMA chain (hprd→hrows→hlsf→hlprd→hlhsf→hlhprd→hlhrows) with groupby transforms.

**Implementation**: The CMA chain logic from glib's `sma.gleam` will be ported faithfully. The `runningPeakCount`, `rowsWithinEachGroup`, `cumulativeMinWithinGroups`, `cumulativeMaxWithinGroups`, and `runningPeakCountOnValues` in `Vector.idr` implement the building blocks. The full chain assembly happens in `SMA.idr`.
