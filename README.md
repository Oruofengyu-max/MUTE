# MUTE
MUTE can automati- cally generate TOD vulnerabilities across four distinct subcategories.

## Required Environment
- Truffle v5.6.9 (core: 5.6.9)
- Ganache v7.5.0
- Solidity v0.5.16 (solc-js)
- Node v14.20.0
- solc-select v1.0.4
- Web3.js v1.7.4

## Code Overview

### vulnerability_detection.py
### extractMapper.py
Extract assertion state‑dependent function pairs.

### Navigate to the `Fuzzer/mutate` Directory


### create_truffle_project.py
### compile_solidity.py
### compile_truffle.py
Host and compile contracts using Truffle.

### remove_requires_from_function_inTruffle.py
### remove_requires_from_function.py
### deleteRequireInTransfer.py
Mutate smart contracts by removing requirement checks.

### Main.py
Generate test cases for vulnerability detection.

### executeSuit.py
Execute the generated test suites.

### classify.py
Classify the detected vulnerabilities.
