// idib FFI wrapper: clean API over compiled Idris 2 functions
// Usage:
//   import { detectLeaf, detectBranch } from './idib-ffi.mjs'
//   const leaves = detectLeaf([{index: 0, value: 10.0}, ...])
//   const branches = detectBranch({interval: 'Day1'}, bars, leaves)

import {
  natToNumber, numberToNat,
  idrisListToArray, arrayToList,
  jsonToLeafBar, leafBarToJson,
  segmentToJson, jsonToSegment,
  jsonToBranchConfig,
  jsonToBar, barToJson, chartBarToJson
} from '../support/js/idib_support.js'

// --- Import compiled Idris module ---
// The compiled idib.mjs defines functions in global scope.
// We need to import it as a side-effect module.

// Import the compiled module by executing it
const idibModule = await import('../idib.mjs')

// --- Internal: call compiled Idris functions ---

function callDetectLeaf(barsJson) {
  const idrisBars = arrayToList(barsJson.map(jsonToLeafBar));
  const result = idibModule.Idib_Fractal_LeafDetect_detectLeaf(idrisBars);
  return idrisListToArray(result).map(segmentToJson);
}

function callDetectBranch(configJson, barsJson, leavesJson) {
  const idrisConfig = jsonToBranchConfig(configJson);
  const idrisBars = arrayToList(barsJson.map(jsonToLeafBar));
  const idrisLeaves = arrayToList(leavesJson.map(jsonToSegment));
  const result = idibModule.Idib_Fractal_Branch_detectBranch(
    idrisConfig, idrisBars, idrisLeaves
  );
  return idrisListToArray(result).map(segmentToJson);
}

// --- Public API ---

/**
 * Detect leaf-level segments from price bars.
 * @param {Array<{index: number, value: number}>} bars - Price bars
 * @returns {Array<{kind: 'YangLeaf'|'YinLeaf', startIdx: number, endIdx: number}>}
 */
export function detectLeaf(bars) {
  return callDetectLeaf(bars);
}

/**
 * Detect branch-level segments from leaf segments.
 * @param {{interval: string, valueSeries?: string}} config - Branch config
 * @param {Array<{index: number, value: number}>} bars - Source price bars
 * @param {Array} leaves - Leaf segments from detectLeaf
 * @returns {Array<{kind: 'YangBranch'|'YinBranch', startIdx: number, endIdx: number, recognIdx: number}>}
 */
export function detectBranch(config, bars, leaves) {
  return callDetectBranch(config, bars, leaves);
}

/**
 * Full fractal pipeline: bars → leaves → branches.
 * @param {Array<{index: number, value: number}>} bars - Price bars
 * @param {{interval: string}} config - Branch config
 * @returns {{leaves: Array, branches: Array}}
 */
export function detectFractal(bars, config = { interval: 'Day1' }) {
  const leaves = detectLeaf(bars);
  const branches = detectBranch(config, bars, leaves);
  return { leaves, branches };
}

/**
 * Compute all indicators incrementally using fractal leaves.
 * O(N) total, O(1) per bar — no recomputation.
 * @param {Array} leaves - Leaf segments from detectLeaf
 * @param {Array<{date:string, opn:number, high:number, low:number, close:number, volume:number}>} bars - OHLCV bars
 * @returns {Array<{bar, sma7, bbm, bbu, bbl, bb6u, bb4u, bb4l, bb6l, k, d, j, m, signal}>}
 */
export function computeChartBarsInc(leaves, bars) {
  const idrisLeaves = arrayToList(leaves.map(jsonToSegment));
  const idrisBars = arrayToList(bars.map(jsonToBar));
  const result = idibModule.Idib_Indicators_Incremental_computeChartBarsInc(
    6, idrisLeaves, idrisBars  // 6 = Day1 interval tag
  );
  return idrisListToArray(result).map(chartBarToJson);
}
