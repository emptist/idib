// Test idib FFI wrapper
import { detectLeaf, detectBranch, detectFractal } from './idib-ffi.mjs'

const bars = [
  { index: 0, value: 10.0 },
  { index: 1, value: 12.0 },
  { index: 2, value: 8.0 },
  { index: 3, value: 11.0 },
  { index: 4, value: 14.0 },
  { index: 5, value: 9.0 },
  { index: 6, value: 13.0 },
]

console.log('=== idib FFI Test ===')
console.log('Bars:', bars.length)

// Test detectLeaf
const leaves = detectLeaf(bars)
console.log('\nLeaves:', leaves.length)
leaves.forEach(l => console.log(`  ${l.kind}: [${l.startIdx}..${l.endIdx}]`))

// Test detectBranch
const config = { interval: 'Day1', valueSeries: 'SMA7' }
const branches = detectBranch(config, bars, leaves)
console.log('\nBranches:', branches.length)
branches.forEach(b => console.log(`  ${b.kind}: [${b.startIdx}..${b.endIdx}] recogn=${b.recognIdx}`))

// Test detectFractal (full pipeline)
const result = detectFractal(bars, config)
console.log('\nFull pipeline:')
console.log(`  Leaves: ${result.leaves.length}, Branches: ${result.branches.length}`)
