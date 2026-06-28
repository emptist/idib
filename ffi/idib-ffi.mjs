// idib FFI wrapper: clean API over compiled Idris 2 functions
//
// Pipeline: bars → indicators → fractal leaves → branches → regime → signals
// O(N) total, O(1) per bar — no recomputation

import {
  natToNumber, numberToNat,
  idrisListToArray, arrayToList,
  jsonToLeafBar, leafBarToJson,
  segmentToJson, jsonToSegment,
  jsonToBranchConfig,
  jsonToBar, barToJson, chartBarToJson
} from '../support/js/idib_support.js'

const idibModule = await import('../idib.mjs')

// --- Helpers ---

const intervalTag = {
  '1m': 0, '5m': 1, '15m': 2, '30m': 3,
  '1h': 5, '4h': 6, '1d': 7, '1w': 8, '1mo': 9, '3mo': 10
}

// --- Public API ---

/**
 * Compute all indicators + fractal pipeline in one pass.
 * @param {string} interval - '1m', '5m', '15m', '30m', '1h', '4h', '1d', '1w'
 * @param {Array<{date:string, opn:number, high:number, low:number, close:number, volume:number}>} bars
 * @returns {{chartResults: Array, fractal: {leaves, branches, bullMarket, sma7Series}}}
 */
export function computeFractal(interval, bars) {
  const tag = intervalTag[interval] || 7
  const idrisBars = arrayToList(bars.map(jsonToBar))
  const idrisPair = idibModule.Idib_Indicators_Incremental_computeFractal(tag, idrisBars)
  const idrisResults = idrisPair.a1
  const idrisFractal = idrisPair.a2

  const chartResults = idrisListToArray(idrisResults).map(cr => ({
    sma7: cr.a1,
    bbm: cr.a2,
    bbu: cr.a3,
    bbl: cr.a4,
    bb6u: cr.a5,
    bb4u: cr.a6,
    bb4l: cr.a7,
    bb6l: cr.a8,
    k: cr.a9,
    d: cr.a10,
    j: cr.a11,
    m: cr.a12,
  }))

  // FractalResult record: {a1: leaves, a2: branches, a3: bullMarket, a4: sma7Series}
  const fractal = {
    leaves: idrisListToArray(idrisFractal.a1).map(segmentToJson),
    branches: idrisListToArray(idrisFractal.a2).map(segmentToJson),
    bullMarket: idrisFractal.a3,
    sma7Series: idrisListToArray(idrisFractal.a4),
  }

  return { chartResults, fractal }
}

/**
 * Detect leaf segments from SMA7 values.
 * @param {Array<number>} sma7Values
 * @returns {Array<{kind, startIdx, endIdx}>}
 */
export function detectLeaf(sma7Values) {
  const leafBars = arrayToList(sma7Values.map((v, i) => ({ a1: numberToNat(i), a2: v })))
  const result = idibModule.Idib_Fractal_LeafDetect_detectLeaf(leafBars)
  return idrisListToArray(result).map(segmentToJson)
}
