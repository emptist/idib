// idib FFI support: JSON ↔ Idris 2 data structure marshalling

// --- Nat ↔ number ---

function natToNumber(n) {
  if (typeof n === 'bigint') return Number(n);
  let result = 0;
  let x = n;
  while (x && x.h === undefined) {
    result++;
    x = x.a2;
  }
  return result;
}

function numberToNat(n) {
  return BigInt(n);
}

// --- List ↔ array ---

function idrisListToArray(list) {
  const result = [];
  let x = list;
  while (x && x.h === undefined) {
    result.push(x.a1);
    x = x.a2;
  }
  return result;
}

function arrayToList(arr) {
  let result = { h: 0 };
  for (let i = arr.length - 1; i >= 0; i--) {
    result = { a1: arr[i], a2: result };
  }
  return result;
}

// --- LeafBar marshalling ---
// Idris record is compiled as pair: {a1: lbIndex, a2: lbValue}
// lbIndex is a Nat (bigint), lbValue is a Double

function jsonToLeafBar(json) {
  return { a1: numberToNat(json.index), a2: json.value };
}

function leafBarToJson(bar) {
  return {
    index: natToNumber(bar.a1),
    value: bar.a2
  };
}

// --- Segment marshalling ---
// YangLeaf(fractal)   → {h: 0, a1: fractal}
// YinLeaf(fractal)    → {h: 1, a1: fractal}
// YangBranch(fractal, recognIdx) → {h: 2, a1: fractal, a2: recognIdx}
// YinBranch(fractal, recognIdx)  → {h: 3, a1: fractal, a2: recognIdx}
// Fractal = pair: {a1: startIdx_nat, a2: endIdx_nat}

function segmentToJson(seg) {
  const fractal = seg.a1;
  const startIdx = natToNumber(fractal.a1);
  const endIdx = natToNumber(fractal.a2);
  switch (seg.h) {
    case 0: return { kind: 'YangLeaf', startIdx, endIdx };
    case 1: return { kind: 'YinLeaf', startIdx, endIdx };
    case 2: return { kind: 'YangBranch', startIdx, endIdx, recognIdx: natToNumber(seg.a2) };
    case 3: return { kind: 'YinBranch', startIdx, endIdx, recognIdx: natToNumber(seg.a2) };
    default: return { kind: 'Unknown', startIdx, endIdx, tag: seg.h };
  }
}

function jsonToSegment(json) {
  const fractal = { a1: numberToNat(json.startIdx), a2: numberToNat(json.endIdx) };
  switch (json.kind) {
    case 'YangLeaf':   return { h: 0, a1: fractal };
    case 'YinLeaf':    return { h: 1, a1: fractal };
    case 'YangBranch': return { h: 2, a1: fractal, a2: numberToNat(json.recognIdx) };
    case 'YinBranch':  return { h: 3, a1: fractal, a2: numberToNat(json.recognIdx) };
  }
}

// --- BranchConfig marshalling ---
// Interval is an enum: Min1=0, Min5=1, Min15=2, Min30=3, Hour1=5, Hour4=6, Day1=7, Week1=8, Month1=9, Month3=10

function jsonToBranchConfig(json) {
  const intervalMap = {
    'Min1': 0, 'Min5': 1, 'Min15': 2, 'Min30': 3,
    'Hour1': 5, 'Hour4': 6, 'Day1': 7, 'Week1': 8,
    'Month1': 9, 'Month3': 10
  };
  return {
    a1: { h: intervalMap[json.interval] || 7 },
    a2: json.valueSeries || 'SMA7'
  };
}

export {
  natToNumber,
  numberToNat,
  idrisListToArray,
  arrayToList,
  jsonToLeafBar,
  leafBarToJson,
  segmentToJson,
  jsonToSegment,
  jsonToBranchConfig
};
