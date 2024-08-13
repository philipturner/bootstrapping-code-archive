//
//  Workspace4.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/31/24.
//

import Foundation
import HDL
import xTB

// MARK: - Thoughts about Potential New Simulator

// Begin the design of a new simulator. Many things that were previously
// inaccessible, should be possible to study. This includes the stability of
// tripods at various temperatures. In addition, steric issues when placing
// silyl groups on silicon carbide.
//
// Design goals:
// - Centered around pre-specification of a topology
//   - Everything is embedded into a Si(111) lattice
//   - Deterministic structure, known beforehand
// - 3-layer ONIOM
//   - Ergonomic way to split the system into subregions
//   - Ergonomic way to select link atoms and redistribute forces
//   - Keep the surface fully hydrogenated in the MM4 region
// - Multiple energy minimizations
//   - Displacements followed by a small number of FIRE iterations (~30)
// - Low-temperature molecular dynamics
//   - Stability analysis
//   - Quantification of operating ranges at 20 K and 77 K
//   - Bulk vibrations or resonant modes
//
// Precursor tasks:
// - Complete the build sequence you will study with the simulator.
// - Clean up the workspace and archive/deactivate code used to design the
//   build sequence.
// - Quantify the complexity of the software, compared to the HDL.
//   - Both the simulator and the parts (tripods, 2nd gen tooltip, etc.).
//   - Transplanting a trajectory to a different system.
//   - New data compression and disk I/O.
//   - DSLs for build sequences, APIs for scripting the simulator.
// - Is it computationally tractable to simulate an entire build sequence,
//   in an overnight simulation?
//   - How many reactions could be simulated in sequence? 300 to 5000
//   - How does number of timesteps scale with size of simulation region?
//     - 30 atoms -> 670 timesteps (1.7 ps)
//     - 100 atoms -> 1000 timesteps (2.5 ps)
//     - 300 atoms -> 1400 timesteps (3.5 ps)
//     - 1000 atoms -> 2200 timesteps (5.5 ps)
//     - 3000 atoms -> 3100 timesteps (7.8 ps)
//     - 10000 atoms -> 4600 timesteps (11 ps)
//     - 30000 atoms -> 6700 timesteps (17 ps)
//   - What is the minimum number of xTB orbitals to get qualitatively correct
//     results for the sterically obstructed SiH3 donation?
//     - If second neighbors can throw off covalent bond energies, the reaction
//       is extremely sensitive to modeling error and should be discarded.
//     - 147 orbitals / 44 atoms
//     - Conservative estimate: 50 ms/timestep
//   - Appears very likely that the GFN-FF level can be made to have negligible
//     compute cost (~150 atoms), if treated as a minimal "glue" between the
//     xTB and MM4 levels.
//   - Assuming no more than 10,000 atoms at the MM4 level.
//   - The number of timesteps/reaction jumps from 1000 to 5000.
//     - 155 ms * 1000 timesteps = 2.6 minutes
//     - 50 ms * 5000 timesteps = 4.2 minutes
//     - Less than a factor of 2 difference in latency
//   - In a six-hour overnight session:
//     - 350 mechanosynthetic operations at 4 * 60 timesteps quality
//     - 180 mechanosynthetic operations at 8 * 60 timesteps quality
//     - 90 mechanosynthetic operations at 16 * 60 timesteps quality
//
// This would take a very long time to code. Is there a faster way to get the
// animation done? Perhaps ignore the unresolved issue of steric congestion.
