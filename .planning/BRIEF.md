# idib: Idris 2 Trading System

## Vision
Rewrite glib's trading logic in Idris 2 with dependent types for correctness guarantees. glib (Gleam) serves as the rapid-prototype; idib is the production-grade implementation where types prevent entire classes of bugs.

## Core Guarantees (via Dependent Types)
1. **Bar alignment**: `Vect n Bar` — impossible to misalign OHLCV with indicators
2. **Interval safety**: `Interval` as type parameter — cannot mix 1h bars with 1d config
3. **State machine**: `Position` as indexed type — impossible to buy when long, sell when flat
4. **Window correctness**: `RollingWindow p xs` proves length = length xs, expanding for early bars
5. **Config validation**: `IndicatorConfig` with compile-time defaults, no magic numbers

## Scope
- **In scope**: All indicator math (SMA, BB, KDJ), strategy logic (buy/sell/bbuy), signal series, multi-timeframe, Fractal segment detection (research)
- **Out of scope**: IB Gateway connectivity, WebSocket server, charting frontend (reuse glib's index.html via static serve)

## Architecture
```
idib-core/          # Pure Idris 2: types, indicators, strategy, signal series, Fractal
idib-server/        # Thin Node.js wrapper: IB Gateway → idib-core → SSE
idib-frontend/      # Static files (copied from glib/priv/index.html)
```

## Key Components

### Indicators (Phase 01)
- SMA with expanding-window fallback from bar 1
- Bollinger Bands + Fibonacci lines (bb6u, bb4u, bb4l, bb6l)
- KDJ: RSV → SMA(K) → SMA(D) → SMA(M), rolling max/min with expanding fallback
- All return `Vect n Double` — same length as input, bar 1 has valid value

### Fractal Segments (Phase 01-02, Research)
- **Leaf**: Extremum-based alternating sequence (from existing glib Fish.idr)
- **Branch**: N-bar confirmation with back-counting
  - YangBranch: starts at low, TRUE start = lowest in subsequent YinLeaf (back-count at new HIGH)
  - YinBranch: starts at high, TRUE start = highest in subsequent YangLeaf (back-count at new LOW)
  - N = 2 * barsPerMonth(interval): 1mo=2, 1wk=8, 1d=40, 1h=260, 4h=64
  - **Disabled for sub-hourly** (noise makes segments unreliable)
- **Parameter-free except N** (interval-derived, not tuned) — segments are "natural"
- Research record for AI pattern discovery, combined with 3 other techniques later

### Strategy (Phase 02)
- `kdj_right = k > d && bars_k_on_d <= 3`
- `kdj_left = j < d && d < m && m > 65.0 && bars_d_on_k < 3` (combined ibOptions + glib)
- `bbuy = xlow && shifted_xlow && sma7_rising && kdj_right`
- `buy = (smas_up && cmas_up && kdj_right) || bbuy`
- `sell = (!smas_up && !cmas_up) && kdj_left && prev_low < prev_sma7`
- Multi-timeframe: monthly trend filter + daily entry

### Signal Series (Phase 03)
- `evaluateSeries : Vect n (ChartBar i) -> Vect n (TradeSignal)` with state carry
- Incremental O(N) version avoiding O(N²) recomputation

### Multi-Timeframe (Phase 04)
- `MultiTFBars` with alignment proofs (higher TF count divisible by lower TF)
- `getHigherTFIndicators` for cross-TF strategy context
- `computeAllCharts` for simultaneous multi-chart display

## Reference Implementation
glib at `../glib` — exact behavior match required. Key files:
- `../glib/src/glib/indicators/sma.gleam`
- `../glib/src/glib/indicators/kdj.gleam`
- `../glib/src/glib/indicators/bollinger_bands.gleam`
- `../glib/src/glib/trading/strategy.gleam`
- `../glib/src/glib/execution/compute.gleam`
- `../glib/Fish.idr` (Leaf reference)

## Success Criteria
- `idris2 --build` passes with zero warnings
- All indicator outputs bitwise-match glib for same input
- Strategy signals match glib for historical SPY data
- Type errors catch: misaligned bars, wrong interval config, invalid state transitions
- Fractal segments at 1h+/1d/1wk/1mo match visual rising/falling sections
