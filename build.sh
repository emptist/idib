#!/bin/bash
# Build idib: compile Idris 2 to JavaScript, post-process to add exports

set -e

echo "Compiling Idris 2 → JavaScript..."
idris2 --codegen node --whole-program --output idib.mjs --source-dir src src/Main.idr

echo "Post-processing: adding exports..."
# Strip shebang and add exports
tail -n +2 build/exec/idib.mjs > idib.mjs

cat >> idib.mjs << 'EXPORTS'

// --- Exports for FFI consumption ---
export {
  Idib_Fractal_LeafDetect_detectLeaf,
  Idib_Indicators_Incremental_computeFractal,
  Idib_Indicators_Incremental_computeIndicators,
  Idib_Indicators_Incremental_stepBar
}
EXPORTS

echo "Built: idib.mjs ($(wc -l < idib.mjs) lines)"
