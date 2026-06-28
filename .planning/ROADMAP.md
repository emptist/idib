# idib Roadmap

## Milestone v0.1: Complete Indicator Pipeline (All from Bar 1)
**Target**: Pure Idris 2 library with SMA, BB, KDJ — all with expanding fallbacks from first bar, bitwise match glib

| Phase | Name | Description |
|-------|------|-------------|
| 01 | Foundation + Indicators | Types + SMA + BB + KDJ all in one — expanding windows from bar 1 |
| 02 | Strategy Logic | `kdj_right`, `kdj_left`, `bbuy`, `buy`, `sell`, `bcall`, `bput`, `watch` |
| 03 | Signal Series | `evaluate_series : Vect n ChartBar -> Vect n Signal` with state carry |
| 04 | Multi-Timeframe | `MultiTF (intervals : List Interval)` with alignment proofs |

## Milestone v0.2: Server Integration
**Target**: Thin Node.js wrapper calling Idris 2 via FFI

| Phase | Name | Description |
|-------|------|-------------|
| 05 | Idris 2 → Node FFI | Compile core to JS, export `computeChartBars`, `generateSignal` |
| 06 | IB Gateway Bridge | Subscribe, historical requests, bar aggregation |
| 07 | SSE Server | Multi-interval chart_data, indicators, signals, position |

## Milestone v0.3: Frontend & Polish
**Target**: Reuse glib's chart, verify end-to-end

| Phase | Name | Description |
|-------|------|-------------|
| 08 | Frontend Integration | Copy glib/priv/index.html, connect to idib SSE |
| 09 | Regression Testing | Compare idib vs glib outputs for SPY 1mo/1w/1d/1h |
| 10 | Documentation | Type signatures as docs, API reference |

---

## Phase Status
- [ ] 01-foundation-indicators
- [ ] 02-strategy-logic
- [ ] 03-signal-series
- [ ] 04-multi-timeframe
- [ ] 05-ffi-node
- [ ] 06-ib-gateway-bridge
- [ ] 07-sse-server
- [ ] 08-frontend-integration
- [ ] 09-regression-testing
- [ ] 10-documentation

---

## Next Action
Plan Phase 01: Foundation types + ALL indicators (SMA, BB, KDJ) with expanding fallbacks from bar 1
