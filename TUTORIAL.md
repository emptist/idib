# Idris 2 Tutorial — for the `idib` Trading Engine

This tutorial is the minimum Idris 2 you need to read and write `idib`. It is
not a general language tour — it focuses on the features we use to replace
`glib`'s Gleam code: **dependent types**, **totality**, **proof-carrying
data**, and **Node.js FFI**.

Examples are drawn from trading-engine domain (bars, indicators, fish
sequences, risk checks) so the mapping to `../glib/src/glib/**.gleam` is
direct.

---

## 0. Install and verify

```bash
brew install chez-scheme
git clone https://github.com/idris-lang/Idris2.git
cd Idris2 && make bootstrap SCHEME=chez && make install
idris2 --version
```

Start a REPL:

```bash
idris2
```

Type `:q` to quit, `:t expr` for a type, `:doc Name` for docs.

---

## 1. Hello, Idris

```idris
module Main

main : IO ()
main = putStrLn "Hello, idib"
```

Save as `src/Main.idr`. Compile and run:

```bash
idris2 src/Main.idr -o hello
./build/exec/hello
```

A `.ipkg` file replaces Gleam's `gleam.toml`:

```ipkg
package idib
version = "0.1.0"
authors = "idib"
sourcedir = "src"
modules = Main
        , Idib.Types
        , Idib.Indicators.SMA
executable = idib
main = Main.main
opts = "--cg node"
```

Build the whole package:

```bash
idris2 --build idib.ipkg
```

---

## 2. Built-in types you will use daily

| Idris 2 | Gleam equivalent | Notes |
|---|---|---|
| `Int`, `Integer`, `Nat` | `Int` | `Nat` is non-negative, structurally |
| `Double` | `Float` | 64-bit IEEE 754 |
| `Bool`, `True`, `False` | `Bool` | |
| `String` | `String` | UTF-8 |
| `Char` | – | |
| `List a` | `List(a)` | |
| `Vect n a` | – | Length-indexed, **use this everywhere you can** |
| `Maybe a` | `Option(a)` | `Nothing` / `Just x` |
| `Either e a` | `Result(a, e)` | Note argument order: `Either err val` |
| `Result e a` | – | `Failure e` / `Success a` (stdlib) |
| `Pair a b` / `(a, b)` | `#(a, b)` | |

Note: Idris uses `Either err val` (error first). We will define a project-local
alias if Gleam's `Result(a, e)` order is more natural in a module.

---

## 3. Functions, definitions, types

```idris
-- Explicit type, then definition
square : Double -> Double
square x = x * x

-- Multiple arguments, curried
add : Int -> Int -> Int
add x y = x + y

-- Pattern matching on literals
parity : Int -> String
parity 0 = "zero"
parity n = if mod n 2 == 0 then "even" else "odd"

-- Anonymous functions
doubleAll : List Int -> List Int
doubleAll = map (\x => x * 2)
```

Top-level definitions are order-independent within a module.

### Where-clauses and `let`

```idris
hypot : Double -> Double -> Double
hypot x y =
  let sx = x * x
      sy = y * y
  in sqrt (sx + sy)
```

---

## 4. Records

A Gleam custom type with named fields maps directly to an Idris `record`:

```idris
-- glib: pub type Bar { Bar(date: String, open: Float, close: Float, ...) }
record Bar where
  constructor MkBar
  date  : String
  open  : Double
  high  : Double
  low   : Double
  close : Double
  volume : Integer

-- Automatic accessors:
barClose : Bar -> Double
barClose b = close b

-- Update syntax (record update):
withClose : Bar -> Double -> Bar
withClose b c = record { close = c } b
```

`MkBar` is the constructor; `close`, `open`, etc. are auto-generated projection
functions. Records may be polymorphic and indexed (see §8).

---

## 5. Algebraic data types

### Sum types

```idris
data MarketSession = RTH | ETH | OTH | CLOSED

data Interval = D1 | H1 | W1 | M1 | M30 | M15
```

### Parameterised

```idris
data TradeSignal
  = Buy  String Double    -- symbol, price
  | Sell String Double
  | Watch String
  | NoSignal
```

### Pattern matching

```idris
describe : TradeSignal -> String
describe (Buy  s p) = "Buy "  ++ s ++ " @ " ++ show p
describe (Sell s p) = "Sell " ++ s ++ " @ " ++ show p
describe (Watch s)  = "Watch " ++ s
describe NoSignal   = "No signal"
```

### Totality

Idris 2 will warn (or error, with `%default partial`) if a function is not
total. For this project we keep **`%default total`** so the compiler rejects
any uncovered case:

```idris
%default total

describe : TradeSignal -> String
describe (Buy s _) = "buy"   -- WARNING: not covering Sell/Watch/NoSignal
```

Always end a pattern match with the catch-all when you genuinely mean "the
rest", or — better — enumerate the cases so the compiler tracks them.

---

## 6. `List` vs `Vect` — the dependent-type upgrade

`List a` has no length information. `Vect n a` carries the length `n` in the
type:

```idris
data Vect : Nat -> Type -> Type where
  Nil  : Vect 0 a
  (::) : a -> Vect n a -> Vect (S n) a
```

### Why this matters for indicators

In `glib/indicators/sma.gleam`, a 7-period SMA is computed by `list.window`
and the *result's* length depends on the input's length minus 6. In Idris:

```idris
import Data.Vect

-- A 7-period SMA preserves the *count* of bars but shifts semantics:
-- the first 6 outputs are partial. We model that as a separate type.
sma7 : Vect n Double -> Vect (minus n 6) Double
sma7 xs = ?todo
```

The compiler now checks, at every call site, that the input has at least 7
bars. A future refactor that changes the period breaks at compile time.

### Common `Vect` operations

```idris
import Data.Vect

vlen : Vect 3 Int
vlen = [1, 2, 3]

headVect : Vect (S n) a -> a
headVect (x :: _) = x

tailVect : Vect (S n) a -> Vect n a
tailVect (_ :: xs) = xs

-- Append: lengths add ( Vect (n + m) a )
(++) : Vect n a -> Vect m a -> Vect (n + m) a
(++) []       ys = ys
(++) (x::xs) ys = x :: (xs ++ ys)
```

---

## 7. Proofs in code: `So` and `Dec`

`Data.So` lifts a `Bool` proposition into a type:

```idris
data So : Bool -> Type where
  Oh : So True
```

A value of type `So p` can only be constructed when `p` evaluates to `True`.
This lets a function **demand a proof** that some predicate holds:

```idris
import Data.So

-- "Take the head of a non-empty list, please bring your own proof."
safeHead : (xs : List a) -> {auto 0 prf : So (not (isNil xs))} -> a
safeHead (x :: _) = x
```

Callers must either pass `Oh` explicitly or have it inferred when the
predicate reduces to `True`.

### Risk decisions that carry their reason

This is how `idib` will model risk checks (replacing `glib`'s string-tagged
results):

```idris
data RiskReason
  = NetLiqBelow Double
  | PDTTriggered
  | PositionTooLarge Double
  | OrderIntervalTooShort
  | DailyLossExceeded
  | DrawdownExceeded
  | ExposureExceeded

data RiskDecision
  = RiskApproved
  | RiskBlocked RiskReason Double   -- reason, current value

-- A risk check that the compiler proves total:
netLiqCheck : Double -> Double -> RiskDecision
netLiqCheck threshold netLiq =
  if netLiq < threshold
    then RiskBlocked (NetLiqBelow netLiq) netLiq
    else RiskApproved
```

A `RiskBlocked` value *witnesses* its reason; callers can pattern match and
the compiler checks every `RiskReason` is handled.

---

## 8. GADTs — invariants encoded in the type

Idris 2 lets a `data` declaration refer to its own type indices. This is how
`../glib/Fish.idr` makes alternation unforgeable (we call this pattern Leaf/Branch):

```idris
data BranchKind = Yang | Yin

opposite : BranchKind -> BranchKind
opposite Yang = Yin
opposite Yin  = Yang

data BranchSeq : BranchKind -> Type where
  FSSingle : (f : Leaf)
          -> {auto prfKind : kind f = k}
          -> BranchSeq k
  FSCons   : (f : Leaf)
          -> {auto prfKind : kind f = k}
          -> BranchSeq (opposite k)
          -> BranchSeq k
```

`BranchSeq Yang` cannot contain two consecutive `Yang` leaves: the `FSCons`
constructor's tail has type `BranchSeq (opposite k)`. This is a guarantee the
*type* gives you for free — no runtime check, no unit test, no comment.

### Another example: a sorted list

```idris
data SortedList : (a -> a -> Bool) -> Type where
  SNil  : SortedList le
  SCons : (x : a) -> SortedList le -> {auto 0 ok : So (isLE x rest)} -> SortedList le
```

(Here `isLE x rest` is a function the caller must discharge.) Insertion can
return a new `SortedList le` only if the proof is produced.

---

## 9. `Either`, `Maybe`, and our project-local `Result`

Idris's stdlib `Result` is `Either err val` flavoured. We define:

```idris
module Idib.Result

public export
data Result e a
  = Err e
  | Ok a

mapOk : (a -> b) -> Result e a -> Result e b
mapOk f (Ok x)  = Ok (f x)
mapOk f (Err e) = Err e

bindOk : Result e a -> (a -> Result e b) -> Result e b
bindOk (Ok x)  f = f x
bindOk (Err e) f = Err e
```

Use `Ok`/`Err` for fallible operations; reserve `Maybe` for "absence is not
an error" (as in Gleam).

---

## 10. `IO` and side effects

Pure code is the default. Side-effecting code lives in `IO`:

```idris
readBars : IO (List Bar)
readBars = do
  s <- readFile "bars.json"
  pure (decodeBars s)

main : IO ()
main = do
  bars <- readBars
  putStrLn ("Loaded " ++ show (length bars) ++ " bars")
```

`do`-notation works as in Haskell. `pure` lifts a value into `IO`.

### Other effects (lightning tour)

For this project we mostly use plain `IO` plus `Maybe`/`Result`. If you need
finer-grained effects, Idris 2 has `Control.Linear.LIO` for linear,
state-tracking effects — useful when modelling "an order can only be placed
once".

---

## 11. Node.js FFI

`glib` calls into `@stoqey/ib` and a Node HTTP server through `.mjs` files.
In Idris 2 the same pattern is `%foreign` annotations.

### Calling a JS function

```idris
module Idib.FFI.Node

%foreign "node:lambda: (x) => console.log(x)"
prim__log : String -> PrimIO ()
```

The `node:` prefix selects the Node backend; the rest is a JS expression that
will be applied to the Idris arguments.

### Wrapping it in `IO`

```idris
log : String -> IO ()
log s = primIO (prim__log s)
```

### A more realistic example — calling `@stoqey/ib`

Assume `ffi/ib_ffi.mjs` exports `connect(host, port)`:

```idris
module Idib.FFI.IB

%foreign "node:lambda: (host, port) => import('./ffi/ib_ffi.mjs').then(m => m.connect(host, port))"
prim__ibConnect : String -> Int -> PrimIO ()

ibConnect : String -> Int -> IO ()
ibConnect host port = primIO (prim__ibConnect host port)
```

For values that cross the FFI boundary in either direction, the rule is the
same as in Gleam: **decode at the boundary** into safe Idris types. Use
`Data.List`, `Maybe`, and our `Idib.Result` types.

### Selecting a backend

Build with the Node codegen for FFI parity with `glib`:

```bash
idris2 --build idib.ipkg --cg node
```

(The default on most installs is the Chez Scheme backend; specify `--cg node`
explicitly when the project uses Node FFI.)

---

## 12. Testing

Idris 2 tests live in a `test/` module and are declared in the `.ipkg`:

```idris
module Main

import Idib.Indicators.SMA

%default total

test_sma7_single : IO ()
test_sma7_single =
  let xs = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
      expected = 4.0
      actual   = sma7 xs
  in if abs (actual - expected) < 1.0e-9
       then putStrLn "ok"
       else putStrLn ("FAIL: " ++ show actual)
```

Run:

```bash
idris2 --testpkg idib.ipkg
```

### Property-style tests with `So`

Because proofs are first-class, many "tests" become theorems:

```idris
-- Compiler-checked: sma of a constant series equals that constant.
sma7_const : (c : Double) -> So (abs (sma7 (replicate 7 c) - c) < 1.0e-9)
sma7_const c = Oh   -- only type-checks if the proposition reduces to True
```

If a future change breaks this property, the *build* fails — no test run
needed.

---

## 13. The unified `ChartBar` model — and what it lets us type

`glib`'s `feat/unified-chartbar` branch (current HEAD) moved all per-bar
indicator values *into* the bar type. Instead of a `Bar` plus separate
`BollingerBands`, `KDJ`, `SmaResult` records that you have to zip together,
there is one `ChartBar` carrying OHLCV **and** the 16 indicator values inline.

### 13.1 Direct port of `ChartBar`

```idris
module Idib.Types

%default total

-- A bare OHLCV bar — what crosses the FFI boundary.
record Bar where
  constructor MkBar
  date   : String
  open   : Double
  high   : Double
  low    : Double
  close  : Double
  volume : Integer

-- A bar with all indicators computed inline.
-- This is the type that flows through the strategy, the dashboard, and the
-- chart — never the bare Bar.
record ChartBar where
  constructor MkChartBar
  -- raw OHLCV (date stays as String for IB/JSON compatibility)
  date   : String
  open, high, low, close : Double
  volume : Integer
  -- SMA7
  sma7 : Double
  -- Bollinger band stack (middle/upper/lower + Fibonacci-retracement bands)
  bbm, bbu, bbl, bb6u, bb4u, bb4l, bb6l : Double
  -- CMA high/low/hl series (segment-tracking outputs)
  cmah7, cmal7, hlcmah7 : Double
  -- KDJM
  k, d, j, m : Double
  -- Per-bar signal string (e.g. "buy", "sell", "watch", "")
  signal : String
```

### 13.2 The `Indicators` snapshot is *derived*, not stored

In `glib`, `Indicators` is a 35-field record with `prev_*` and `*_up` boolean
fields, populated by `compute_indicators_for_interval_with_config`. It looks
like state but it's really a **projection** of `(lastBar, prevBar)`.

In Idris 2 we make that explicit:

```idris
record Indicators where
  constructor MkIndicators
  sma7, prev_sma7 : Double
  bbm,  prev_bbm  : Double
  bbu, bbl, bbp, bb6u, bb4u, bb4l, bb6l : Double
  k, d, j, m, prev_k, prev_j : Double
  hrows7, lrows7, hprd7, lprd7, hlhrows7 : Int
  cmah7, cmal7, prev_hlcmah7 : Double
  cnst7, velo7, cnsvel7, bias : Double
  smas_up, cmas_up, xlow : Bool
  bars_k_on_d, bars_d_on_k, hlrows, hlhlrows : Int

-- Derived from two consecutive ChartBars. The type makes the "prev_*"
-- dependency impossible to forget.
indicatorsFromPair : ChartBar -> Maybe ChartBar -> Indicators
indicatorsFromPair cur prev =
  let prev_sma7 = maybe sma7 sma7 prev
      prev_bbm  = maybe bbm  bbm  prev
      prev_k    = maybe k   k   prev
      prev_j    = maybe j   j   prev
      smas_up   = sma7 cur > prev_sma7 && bbm cur > prev_bbm
      cmas_up   = hlcmah7 cur > maybe (hlcmah7 cur) hlcmah7 prev
               && sma7 cur > prev_sma7
      -- … remaining fields
  in MkIndicators { sma7 = sma7 cur, prev_sma7, bbm = bbm cur, prev_bbm, … }
```

No `prev_*` field is ever silently zero-filled again — the `Maybe ChartBar`
forces the caller to say what "previous bar" means.

### 13.3 `Vect n` makes the whole pipeline length-proven

`glib`'s `compute_chart_bars` does N independent `list.drop(idx).first()`
lookups to attach each indicator value to its bar. If any indicator series
is the wrong length, the bar gets a silent `0.0`. In Idris 2:

```idris
import Data.Vect

-- A single fold that produces a length-matched vector of ChartBars.
-- Type signature *proves* input and output have the same length.
computeChartBars : Vect n Bar -> Vect n ChartBar
computeChartBars bars = ?todo   -- real implementation in Compute.idr
```

The compiler now refuses any implementation that produces a different-length
output. The `list.drop(idx).first()` lookups vanish — the fold carries the
indicator accumulators forward in lockstep with the bars.

### 13.4 The shared core `glib` is missing — `WindowedSMA`

`glib`'s REVIEW_REFERENCE.md identifies the root structural problem: SMA is
reimplemented three times (BB middle, SMA7, KDJ rolling), with no shared
abstraction and inconsistent fallback behaviour. In `idib` this is one type:

```idris
module Idib.Core.WindowedSMA

import Data.Vect
import Data.List

%default total

-- A windowed SMA with expanding-window fallback for early bars.
-- (mirrors ibOptions: rolling window → CMA fallback for first `window-1` bars)
record WindowedSMA (n : Nat) where
  constructor MkWindowedSMA
  window   : Nat           -- the rolling window size
  values   : Vect n Double -- one SMA value per input bar
  -- Proof that values is non-empty when n > 0 is carried by `Vect n`.

-- The single totality-checked computation every indicator reuses.
smaSeries : (window : Nat) -> Vect n Double -> Vect n Double
smaSeries window xs = ?todo   -- rolling mean with expanding fallback

-- BB middle, SMA7, KDJ rolling max/min all become:
--   bbmSeries  = smaSeries bbWindow closes
--   sma7Series = smaSeries 7         closes
--   hhSeries   = smaSeries kdjPeriod highs   -- (max rather than mean; same shape)
```

Once `WindowedSMA` exists, the three indicator modules (`Bollinger`,
`SMA7`, `KDJ`) become thin wrappers, and the "expanding-window fallback
missing" bugs that `glib` has in three separate places are fixed in one.

### 13.5 `Leaf` / `Branch` as dependent types

The same REVIEW_REFERENCE.md notes that `glib`'s `sma7` segment tracking
(hrows7, cmah7, …) *is* Leaf on SMA7, but never named as such. `idib` makes
the abstraction first-class — `Fish.idr` already exists in `../glib` as a
prototype (we call it Leaf/Branch). Its alternation invariant (`BranchSeq Yang` cannot hold two
consecutive Yang leaves) is enforced by the GADT's constructor signatures;
no runtime check, no unit test, no comment.

---

## 14. Cheat-sheet for Gleam refugees

| Gleam | Idris 2 |
|---|---|
| `pub fn f(x: Int) -> Int { x + 1 }` | `f : Int -> Int; f x = x + 1` |
| `pub type Color { Red; Green; Blue }` | `data Color = Red \| Green \| Blue` |
| `pub type Bar { Bar(name: String) }` | `record Bar where constructor MkBar; name : String` |
| `case x { Ok(v) -> v; Err(e) -> 0 }` | `case x of Ok v => v; Err _ => 0` |
| `list.map(xs, f)` | `map f xs` |
| `result.try(a, b)` | `bindOk a b` (project-local) |
| `fn(x) { x }` | `\x => x` |
| `let assert Ok(v) = result` | `let Ok v = result` — partial; avoid under `%default total` |
| `gleam test` | `idris2 --testpkg idib.ipkg` |
| `gleam build` | `idris2 --build idib.ipkg` |
| `gleam.toml` | `idib.ipkg` |
| `.mjs` FFI | `%foreign "node:lambda: ..."` |
| `todo` | `?todo` (hole, type-checks and REPL-inspectable) |
| `panic` | `idris_crash` — *only at the FFI boundary, never in core logic* |

---

## 15. Next steps for `idib`

1. Read `../glib/Fish.idr` end-to-end. It already uses every technique above.
2. Port `../glib/src/glib/types.gleam` to `src/Idib/Types.idr` — `Bar` (OHLCV
   only) and `ChartBar` (OHLCV + 16 indicator fields inline), as in §13.1.
3. Port `../glib/src/glib/execution/compute.gleam`'s `compute_chart_bars` to
   `src/Idib/Execution/Compute.idr` as `Vect n Bar -> Vect n ChartBar` — a
   single fold, not N `list.drop(idx).first()` lookups.
4. Implement `src/Idib/Core/WindowedSMA.idr` (§13.4) **before** the indicator
   modules, then port `bollinger_bands.gleam` / `sma.gleam` / `kdj.gleam` as
   thin wrappers around it.
5. Add a `test/` module with both unit tests (§12) and a `So`-proof property.

When in doubt, prefer the typed version. The whole point of moving from Gleam
to Idris 2 is to push invariants out of tests and comments and into the types.
