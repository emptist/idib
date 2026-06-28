# idib: Idris 2 Trading System

**Status**: Planning phase — see `.planning/`

## Overview
Idris 2 rewrite of glib's trading logic with dependent types for correctness guarantees.

- **glib** (Gleam): Rapid prototype, visual iteration
- **idib** (Idris 2): Production core, type-enforced correctness

## Core Guarantees
| Guarantee | Mechanism |
|-----------|-----------|
| Bar alignment | `Vect n Bar` — length-indexed vectors |
| Interval safety | Phantom `Interval` on `Bar i` / `ChartBar i` |
| State validity | Indexed `Position` type (Flat \| Long \| Short) |
| Window correctness | Dependent `RollingWindow` proofs |
| No magic numbers | `IndicatorConfig` with compile-time defaults |

## Architecture
```
idib/
├── .planning/           # Planning artifacts (BRIEF, ROADMAP, phase plans)
├── src/
│   ├── Idib/
│   │   ├── Types.idr           # Core types (Bar, ChartBar, Interval, Config, etc.)
│   │   ├── Vector.idr          # Vect helpers (zip, take, drop, indexed)
│   │   ├── Indicators/
│   │   │   ├── SMA.idr              # SMA + expanding window
│   │   │   ├── BollingerBands.idr   # BB + Fibonacci lines
│   │   │   ├── KDJ.idr              # RSV → SMA(K/D/M), rolling max/min
│   │   │   └── ChartBar.idr         # Unified computeChartBars
│   │   ├── Leaf/                      # Leaf/Branch segment detection
│   │   │   ├── Types.idr            # Branch types, interval-gated N
│   │   │   ├── Leaf.idr             # Leaf (extremum-based, from glib)
│   │   │   ├── LeafDetect.idr       # Leaf detection
│   │   │   ├── Branch.idr           # Branch with N-bar confirmation
│   │   │   └── Analytics.idr        # Branch metrics for AI pattern discovery
│   │   ├── Strategy/
│   │   │   ├── Position.idr         # Indexed Position state machine
│   │   │   ├── Evaluate.idr         # evaluateBar (kdj_right/left, bbuy, buy, sell)
│   │   │   ├── MultiTF.idr          # Multi-TF strategy context
│   │   │   └── SignalSeries.idr     # evaluateSeries with state carry
│   │   ├── MultiTF.idr              # MultiTFBars with alignment proofs
│   │   └── Server/                  # FFI exports for Node.js
└── idib.ipkg
```

## Key Design Decisions

### Indicators
- All SMA-based (no RMA) per user requirement
- Expanding-window fallback: bar 1 returns value, not `Nothing`
- Output: `Vect n Double` — same length as input, no alignment issues

### Leaf/Branch Segments (Research)
- **Leaf**: Extremum-based alternating sequence (ported from glib's `Fish.idr`)
- **Branch**: Two-level detection with N-bar confirmation + back-counting
  - YangBranch: TRUE start = lowest in subsequent YinLeaf (found at new HIGH)
  - YinBranch: TRUE start = highest in subsequent YangLeaf (found at new LOW)
  - N = 2 × barsPerMonth(interval): 1mo=2, 1wk=8, 1d=40, 1h=260, 4h=64
  - **Disabled for sub-hourly** (Min1/5/15/30 return 0 barsPerMonth)
- **Parameter-free except N** (interval-derived, not tuned) — "natural" segments
- Research record for AI pattern discovery, combined with 3 other techniques later

### Multi-Timeframe
- `MultiTFBars` with `Aligned` proof: higher TF count divisible by lower TF
- `evaluateBarMTF` receives higher-TF `Indicators` for cross-TF conditions
- `computeAllCharts` exports all intervals for simultaneous display

## Development

### Prerequisites
- Idris 2 (latest)
- Node.js (for server wrapper)

### Build
```bash
cd idib
idris2 --build idib.ipkg
```

### Test Vectors
Export from glib: SPY 1mo/1wk/1d/1h bars → JSON → compare bitwise with idib outputs.

## Roadmap
| Milestone | Phases | Target |
|-----------|--------|--------|
| v0.1 | 01-04 | Complete indicator pipeline + strategy + signal series + multi-TF |
| v0.2 | 05-07 | Node.js FFI, IB Gateway bridge, SSE server |
| v0.3 | 08-10 | Frontend integration, regression testing, docs |

See `.planning/ROADMAP.md` for detailed phase breakdown.

## Reference
- glib prototype: `../glib`
- ibOptions (Python reference): `../ibOptions/toolfuncs.py`
