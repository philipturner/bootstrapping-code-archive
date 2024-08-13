//
//  ONIOMTooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/7/24.
//

import HDL
import MM4
import Numerics
import xTB

// A crossbar tooltip compatible with the ONIOM level of theory.
struct ONIOMTooltip {
  var dimer: [Entity]
  var reactiveSite: [Entity]
  var nearFramework: [Entity]
  var farFramework: [Entity]
  
  // Indices are within the respective array.
  // [inner atom, outer atom]
  var innerOuterBoundary: [SIMD2<UInt32>] = []
  var outerAnchorBoundary: [SIMD2<UInt32>] = []
  
  init() {
    // Maps the atom ID to its position within the new array.
    func createMap(_ input: [UInt32]) -> [UInt32: UInt32] {
      var output: [UInt32: UInt32] = [:]
      for slotID in input.indices {
        let atomID = input[slotID]
        output[UInt32(atomID)] = UInt32(slotID)
      }
      return output
    }
    
    // Extract bonds, with indices in the order [inner atom, outer atom].
    func createONIOMBoundary(
      inner: [UInt32], outer: [UInt32], bonds: [SIMD2<UInt32>]
    ) -> [SIMD2<UInt32>] {
      let innerSet = Set(inner)
      let outerSet = Set(outer)
      
      var output: [SIMD2<UInt32>] = []
      for bond in bonds {
        var innerAtomID: UInt32?
        var outerAtomID: UInt32?
        for laneID in 0..<2 {
          let atomID = bond[laneID]
          if innerSet.contains(atomID) {
            innerAtomID = atomID
          }
          if outerSet.contains(atomID) {
            outerAtomID = atomID
          }
        }
        guard let innerAtomID,
              let outerAtomID else {
          continue
        }
        output.append(SIMD2(innerAtomID, outerAtomID))
      }
      return output
    }
    
    var tooltipDesc = CrossbarTooltipDescriptor()
    tooltipDesc.material = .elemental(.silicon)
    var tooltip = CrossbarTooltip(descriptor: tooltipDesc)
    
    let dimerIDs = tooltip.detachDimer()
    let reactiveSiteIDs = tooltip.detachReactiveSite()
    let nearFrameworkIDs = tooltip.detachNearFramework()
    let farFrameworkIDs = tooltip.detachFarFramework()
    
    let bonds = tooltip.rigidBody.parameters.bonds.indices
    let innerOuterBoundary = createONIOMBoundary(
      inner: reactiveSiteIDs, outer: nearFrameworkIDs, bonds: bonds)
    let outerAnchorBoundary = createONIOMBoundary(
      inner: nearFrameworkIDs, outer: farFrameworkIDs, bonds: bonds)
    
    // Minimize and position the tooltip.
    tooltip.minimize()
    tooltip.rigidBody.rotate(
      angle: 144.74 * .pi / 180,
      axis: SIMD3(-1, 0, 1) / Double(2).squareRoot())
    tooltip.rigidBody.rotate(
      angle: 45 * .pi / 180,
      axis: SIMD3(0, 1, 0))
    do {
      var accumulator: SIMD3<Float> = .zero
      guard dimerIDs.count == 2 else {
        fatalError("This should never happen.")
      }
      for atomID in dimerIDs {
        let position = tooltip.rigidBody.positions[Int(atomID)]
        accumulator += position
      }
      accumulator /= 2
      tooltip.rigidBody.centerOfMass -= SIMD3(accumulator)
    }
    
    // Now, separate the atoms.
    var atoms: [Entity] = []
    for atomID in tooltip.rigidBody.positions.indices {
      let parameters = tooltip.rigidBody.parameters
      let atomicNumber = parameters.atoms.atomicNumbers[Int(atomID)]
      let position = tooltip.rigidBody.positions[Int(atomID)]
      let atom = Entity(storage: SIMD4(position, Float(atomicNumber)))
      atoms.append(atom)
    }
    dimer = dimerIDs.map { atoms[Int($0)] }
    reactiveSite = reactiveSiteIDs.map { atoms[Int($0)] }
    nearFramework = nearFrameworkIDs.map { atoms[Int($0)] }
    farFramework = farFrameworkIDs.map { atoms[Int($0)] }
    
    let reactiveSiteMap = createMap(reactiveSiteIDs)
    let nearFrameworkMap = createMap(nearFrameworkIDs)
    let farFrameworkMap = createMap(farFrameworkIDs)
    self.innerOuterBoundary = innerOuterBoundary.map {
      SIMD2(reactiveSiteMap[$0.x]!,
            nearFrameworkMap[$0.y]!)
    }
    self.outerAnchorBoundary = outerAnchorBoundary.map {
      SIMD2(nearFrameworkMap[$0.x]!,
            farFrameworkMap[$0.y]!)
    }
  }
}

extension ONIOMTooltip {
  var centerOfMass: SIMD3<Float> {
    var accumulator: SIMD3<Double> = .zero
    var mass: Double = .zero
    
    let atoms = dimer + reactiveSite + nearFramework + farFramework
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      accumulator += SIMD3(atom.position)
      mass += Double(1)
    }
    return SIMD3<Float>(accumulator / mass)
  }
  
  var dimerCenterOfMass: SIMD3<Float> {
    var output: SIMD3<Float> = .zero
    output += dimer[0].position
    output += dimer[1].position
    output /= 2
    return output
  }
  
  var germaniumCenterOfMass: SIMD3<Float> {
    var accumulator: SIMD3<Float> = .zero
    var mass: Int = .zero
    for atom in reactiveSite {
      if atom.atomicNumber == 32 {
        accumulator += atom.position
        mass += 1
      }
    }
    guard mass == 2 else {
      fatalError("Failed to find two germaniums.")
    }
    return accumulator / 2
  }
  
  mutating func translate(offset: SIMD3<Float>) {
    func translate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        atom.position += offset
        fragment[atomID] = atom
      }
    }
    translate(fragment: &dimer)
    translate(fragment: &reactiveSite)
    translate(fragment: &nearFramework)
    translate(fragment: &farFramework)
  }
  
  mutating func rotate(angle: Float, axis: SIMD3<Float>) {
    let rotation = Quaternion<Float>(angle: angle, axis: axis)
    let centerOfMass = self.centerOfMass
    
    func rotate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        var delta = atom.position - centerOfMass
        delta = rotation.act(on: delta)
        atom.position = centerOfMass + delta
        fragment[atomID] = atom
      }
    }
    rotate(fragment: &dimer)
    rotate(fragment: &reactiveSite)
    rotate(fragment: &nearFramework)
    rotate(fragment: &farFramework)
  }
}

// MARK: - Minimize

extension ONIOMTooltip {
  mutating func minimize() {
    var innerHighCalculator: xTB_Calculator
    var innerLowCalculator: xTB_Calculator
    var outerLowCalculator: xTB_Calculator
    
    // Set up the xTB calculator.
    do {
      var initialAtoms: [Entity] = []
      initialAtoms += self.dimer
      initialAtoms += self.reactiveSite
      initialAtoms += createInnerOuterBoundaryAtoms()
      
      // Create the calculator.
      var calculatorDesc = xTB_CalculatorDescriptor()
      calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
      calculatorDesc.hamiltonian = .tightBinding
      let calculator = xTB_Calculator(descriptor: calculatorDesc)
      
      // Report the energy.
      calculator.molecule.positions = initialAtoms.map(\.position)
      guard calculator.energy != 0 else {
        fatalError("Failed to create calculator.")
      }
      innerHighCalculator = calculator
    }
    
    // WARNING: This function assumes there is only void underneath. This will
    // not be true when there is a build plate.
    func modifyForceFieldParameterization(
      atoms: inout [Entity], forward: Bool
    ) {
      let sign: Float = forward ? 1 : -1
      atoms[0].position.y -= sign * 2
      atoms[1].position.y -= sign * 2
      if atoms[0].atomicNumber == 1 {
        atoms[0].position.x -= sign * 2
      }
      if atoms[1].atomicNumber == 1 {
        atoms[1].position.x += sign * 2
      }
    }
    
    // Set up the GFN-FF calculator (inner).
    do {
      var initialAtoms: [Entity] = []
      initialAtoms += self.dimer
      initialAtoms += self.reactiveSite
      initialAtoms += createInnerOuterBoundaryAtoms()
      modifyForceFieldParameterization(atoms: &initialAtoms, forward: true)
      
      // Create the calculator.
      var calculatorDesc = xTB_CalculatorDescriptor()
      calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
      calculatorDesc.hamiltonian = .forceField
      calculatorDesc.positions = initialAtoms.map(\.position)
      let calculator = xTB_Calculator(descriptor: calculatorDesc)
      
      // Report the energy.
      modifyForceFieldParameterization(atoms: &initialAtoms, forward: false)
      calculator.molecule.positions = initialAtoms.map(\.position)
      guard calculator.energy != 0 else {
        fatalError("Failed to create calculator.")
      }
      innerLowCalculator = calculator
    }
    
    // Set up the GFN-FF calculator (outer).
    do {
      var initialAtoms: [Entity] = []
      initialAtoms += self.dimer
      initialAtoms += self.reactiveSite
      initialAtoms += self.nearFramework
      initialAtoms += createOuterAnchorBoundaryAtoms()
      modifyForceFieldParameterization(atoms: &initialAtoms, forward: true)
      
      // Create the calculator.
      var calculatorDesc = xTB_CalculatorDescriptor()
      calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
      calculatorDesc.hamiltonian = .forceField
      calculatorDesc.positions = initialAtoms.map(\.position)
      let calculator = xTB_Calculator(descriptor: calculatorDesc)
      
      // Report the energy.
      modifyForceFieldParameterization(atoms: &initialAtoms, forward: false)
      calculator.molecule.positions = initialAtoms.map(\.position)
      guard calculator.energy != 0 else {
        fatalError("Failed to create calculator.")
      }
      outerLowCalculator = calculator
    }
    
    // Sum the forces across the atoms.
    func getForces() -> [SIMD3<Float>] {
      var forces = outerLowCalculator.molecule.forces
      do {
        var atomCount: Int = .zero
        atomCount += self.dimer.count
        atomCount += self.reactiveSite.count
        atomCount += self.nearFramework.count
        forces.removeLast(forces.count - atomCount)
      }
      do {
        var atomCount: Int = .zero
        atomCount += self.dimer.count
        atomCount += self.reactiveSite.count
        for atomID in 0..<atomCount {
          let innerHighForce = innerHighCalculator.molecule.forces[atomID]
          let innerLowForce = innerLowCalculator.molecule.forces[atomID]
          forces[atomID] += innerHighForce - innerLowForce
        }
      }
      
      // Include the link atom forces.
      do {
        var atomCount: Int = .zero
        atomCount += self.dimer.count
        atomCount += self.reactiveSite.count
        
        let reactiveSiteOffset = self.dimer.count
        let nearFrameworkOffset = self.dimer.count + self.reactiveSite.count
        for bondID in self.innerOuterBoundary.indices {
          let bond = self.innerOuterBoundary[bondID]
          let innerAtom = self.reactiveSite[Int(bond[0])]
          let outerAtom = self.nearFramework[Int(bond[1])]
          
          // Source: MM4Parameters
          guard innerAtom.atomicNumber == 6,
                outerAtom.atomicNumber == 14 else {
            fatalError("Unexpected boundary bond.")
          }
          let d1: Float = 1.1120 / 10
          let d2: Float = 1.876 / 10
          let k = d1 / d2
          
          let linkAtomID = atomCount + bondID
          let innerHighForce = innerHighCalculator.molecule.forces[linkAtomID]
          let innerLowForce = innerLowCalculator.molecule.forces[linkAtomID]
          let hydrogenForce = innerHighForce - innerLowForce
          forces[reactiveSiteOffset + Int(bond[0])] += (1 - k) * hydrogenForce
          forces[nearFrameworkOffset + Int(bond[1])] += k * hydrogenForce
        }
      }
      do {
        var atomCount: Int = .zero
        atomCount += self.dimer.count
        atomCount += self.reactiveSite.count
        atomCount += self.nearFramework.count
        
        let nearFrameworkOffset = self.dimer.count + self.reactiveSite.count
        for bondID in self.outerAnchorBoundary.indices {
          let bond = self.outerAnchorBoundary[bondID]
          let innerAtom = self.nearFramework[Int(bond[0])]
          let outerAtom = self.farFramework[Int(bond[1])]
          
          // Source: MM4Parameters
          guard innerAtom.atomicNumber == 14,
                outerAtom.atomicNumber == 14 else {
            fatalError("Unexpected boundary bond.")
          }
          let d1: Float = 1.483 / 10
          let d2: Float = 2.322 / 10
          let k = d1 / d2
          
          let linkAtomID = atomCount + bondID
          let outerLowForce = outerLowCalculator.molecule.forces[linkAtomID]
          forces[nearFrameworkOffset + Int(bond[0])] += (1 - k) * outerLowForce
        }
      }
      return forces
    }
    
    // Create an energy minimization.
    var minimization: FIREMinimization
    do {
      var atoms: [Entity] = []
      atoms += self.dimer
      atoms += self.reactiveSite
      atoms += self.nearFramework
      
      var minimizationDesc = FIREMinimizationDescriptor()
      minimizationDesc.masses = atoms.map {
        if $0.atomicNumber == 1 {
          return Float(4.0 * MM4YgPerAmu)
        } else {
          return Float(12.011 * MM4YgPerAmu)
        }
      }
      minimizationDesc.positions = atoms.map(\.position)
      minimization = FIREMinimization(descriptor: minimizationDesc)
    }
    
    var frames: [[Entity]] = []
    frames.append(
      self.dimer + self.reactiveSite + self.nearFramework +
      createOuterAnchorBoundaryAtoms())
    
    // Run the first step and visualize the results.
    for trialID in 0..<500 {
      // Set the positions.
      do {
        var atoms: [Entity] = []
        atoms += self.dimer
        atoms += self.reactiveSite
        atoms += createInnerOuterBoundaryAtoms()
        innerHighCalculator.molecule.positions = atoms.map(\.position)
      }
      do {
        var atoms: [Entity] = []
        atoms += self.dimer
        atoms += self.reactiveSite
        atoms += createInnerOuterBoundaryAtoms()
        innerLowCalculator.molecule.positions = atoms.map(\.position)
      }
      do {
        var atoms: [Entity] = []
        atoms += self.dimer
        atoms += self.reactiveSite
        atoms += self.nearFramework
        atoms += createOuterAnchorBoundaryAtoms()
        outerLowCalculator.molecule.positions = atoms.map(\.position)
      }
      
      // Query the forces.
      let forces = getForces()
      var maximumForce: Float = .zero
      for atomID in forces.indices {
        if minimization.anchors.contains(UInt32(atomID)) {
          fatalError("This should never happen.")
        }
        let force = forces[atomID]
        let forceMagnitude = (force * force).sum().squareRoot()
        maximumForce = max(maximumForce, forceMagnitude)
      }
      
      // Sum the energies.
      var energy: Double = .zero
      energy += outerLowCalculator.energy
      energy += (innerHighCalculator.energy - innerLowCalculator.energy)
      
      print("time: \(Format.time(minimization.time))", terminator: " | ")
      print("energy: \(Format.energy(energy))", terminator: " | ")
      print("max force: \(Format.force(maximumForce))", terminator: " | ")
      
      let converged = minimization.step(forces: forces)
      if !converged {
        print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
      }
      print()
      
      
      var cursor: Int = .zero
      for atomID in self.dimer.indices {
        var atom = self.dimer[atomID]
        atom.position = minimization.positions[cursor]
        cursor += 1
        self.dimer[atomID] = atom
      }
      for atomID in self.reactiveSite.indices {
        var atom = self.reactiveSite[atomID]
        atom.position = minimization.positions[cursor]
        cursor += 1
        self.reactiveSite[atomID] = atom
      }
      for atomID in self.nearFramework.indices {
        var atom = self.nearFramework[atomID]
        atom.position = minimization.positions[cursor]
        cursor += 1
        self.nearFramework[atomID] = atom
      }
      
      frames.append(
        self.dimer + self.reactiveSite + self.nearFramework +
        createOuterAnchorBoundaryAtoms())
      
      if converged {
        break
      } else if trialID == 499 {
        print("failed to converge!")
      }
    }
  }
  
  // Maps the boundary bonds to atoms.
  func createInnerOuterBoundaryAtoms() -> [Entity] {
    var boundaryHydrogens: [Entity] = []
    for bond in self.innerOuterBoundary {
      let innerAtom = self.reactiveSite[Int(bond[0])]
      let outerAtom = self.nearFramework[Int(bond[1])]
      
      // Source: MM4Parameters
      guard innerAtom.atomicNumber == 6,
            outerAtom.atomicNumber == 14 else {
        fatalError("Unexpected boundary bond.")
      }
      let d1: Float = 1.1120 / 10
      let d2: Float = 1.876 / 10
      
      let delta = outerAtom.position - innerAtom.position
      let hydrogenPosition = innerAtom.position + (d1 / d2) * delta
      let hydrogen = Entity(
        position: hydrogenPosition, type: .atom(.hydrogen))
      boundaryHydrogens.append(hydrogen)
    }
    return boundaryHydrogens
  }
  
  // Maps the boundary bonds to atoms.
  func createOuterAnchorBoundaryAtoms() -> [Entity] {
    var boundaryHydrogens: [Entity] = []
    for bond in self.outerAnchorBoundary {
      let innerAtom = self.nearFramework[Int(bond[0])]
      let outerAtom = self.farFramework[Int(bond[1])]
      
      // Source: MM4Parameters
      guard innerAtom.atomicNumber == 14,
            outerAtom.atomicNumber == 14 else {
        fatalError("Unexpected boundary bond.")
      }
      let d1: Float = 1.483 / 10
      let d2: Float = 2.322 / 10
      
      let delta = outerAtom.position - innerAtom.position
      let hydrogenPosition = innerAtom.position + (d1 / d2) * delta
      let hydrogen = Entity(
        position: hydrogenPosition, type: .atom(.hydrogen))
      boundaryHydrogens.append(hydrogen)
    }
    return boundaryHydrogens
  }
}

// MARK: - Import

extension ONIOMTooltip {
  // Import a set of minimized atoms.
  mutating func `import`(atoms: [Entity]) {
    var cursor: Int = .zero
    for atomID in self.dimer.indices {
      var atom = self.dimer[atomID]
      atom = atoms[cursor]
      cursor += 1
      self.dimer[atomID] = atom
    }
    for atomID in self.reactiveSite.indices {
      var atom = self.reactiveSite[atomID]
      atom = atoms[cursor]
      cursor += 1
      self.reactiveSite[atomID] = atom
    }
    for atomID in self.nearFramework.indices {
      var atom = self.nearFramework[atomID]
      atom = atoms[cursor]
      cursor += 1
      self.nearFramework[atomID] = atom
    }
  }
  
  static let carbonTipMinimizedAtoms: [Entity] = [
    Entity(position: SIMD3( 0.0620, 0.0088, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0620, 0.0088, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3592, 0.1457, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1451, 0.1710, -0.2852), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0774, 0.2550, -0.1753), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0774, 0.2550,  0.1753), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1451, 0.1710,  0.2852), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1584, 0.1725, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.1451, 0.1710, -0.2852), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0774, 0.2549, -0.1753), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0774, 0.2549,  0.1753), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1451, 0.1710,  0.2852), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1585, 0.1725, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3592, 0.1456, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2527, 0.1821, -0.2712), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3854, 0.0874, -0.0877), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1204, 0.0658, -0.2718), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3854, 0.0874,  0.0877), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2527, 0.1821,  0.2712), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1204, 0.0658,  0.2718), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1204, 0.0657, -0.2718), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1204, 0.0657,  0.2718), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3854, 0.0873, -0.0877), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3854, 0.0873,  0.0877), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2527, 0.1821, -0.2712), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2527, 0.1821,  0.2712), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.8039, 0.4987, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7334, 0.6234, -0.1818), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7906, 0.5799, -0.3081), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7334, 0.6234,  0.1818), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7906, 0.5799,  0.3081), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6951, 0.2926, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7425, 0.2083, -0.1081), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7425, 0.2083,  0.1081), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3940, 0.4248, -0.1825), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4384, 0.3502, -0.2984), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4265, 0.7466, -0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4843, 0.7047, -0.5016), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1145, 0.2131, -0.4659), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1637, 0.0963, -0.5378), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3940, 0.4248,  0.1825), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4384, 0.3502,  0.2984), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4265, 0.7466,  0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4843, 0.7047,  0.5015), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1145, 0.2131,  0.4659), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1637, 0.0963,  0.5378), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5028, 0.6298, -0.1916), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4623, 0.3013, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.5028, 0.6298,  0.1916), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4335, 0.7407, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1619, 0.4270, -0.1871), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1149, 0.5491, -0.3772), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2042, 0.7645, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154, 0.8635, -0.1880), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154, 0.8635,  0.1880), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1619, 0.4270,  0.1871), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1149, 0.5491,  0.3772), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1142, 0.5521, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1143, 0.5521, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1620, 0.4270, -0.1871), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2043, 0.7645, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1620, 0.4270,  0.1871), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4623, 0.3012, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1955, 0.4038, -0.9348), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3356, 0.4012, -0.9743), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548, 0.2692, -0.9729), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, 0.7337, -0.7516), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3314, 0.7488, -0.7761), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1162, 0.5135, -0.7459), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1908, 0.4161, -0.5491), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3352, 0.4246, -0.5382), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1955, 0.4038, -0.9348), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1548, 0.2692, -0.9729), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3357, 0.4011, -0.9743), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1163, 0.5135, -0.7459), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1145, 0.2130, -0.4659), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1637, 0.0963, -0.5378), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1972, 0.7645, -0.3790), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1150, 0.8582, -0.5719), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1152, 0.8582, -0.5719), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1908, 0.4160, -0.5491), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3353, 0.4245, -0.5382), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1150, 0.5491, -0.3772), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1891, 0.7337, -0.7516), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3315, 0.7487, -0.7761), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1155, 0.8635, -0.1880), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1973, 0.7645, -0.3790), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5029, 0.6297, -0.1916), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4266, 0.7465, -0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4844, 0.7046, -0.5015), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3941, 0.4247, -0.1825), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4385, 0.3501, -0.2984), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, 0.7337,  0.7516), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3314, 0.7488,  0.7761), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1955, 0.4038,  0.9348), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3356, 0.4012,  0.9743), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548, 0.2692,  0.9729), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1908, 0.4161,  0.5491), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3352, 0.4246,  0.5382), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1162, 0.5135,  0.7459), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1163, 0.5135,  0.7459), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1955, 0.4038,  0.9348), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1548, 0.2692,  0.9729), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3357, 0.4011,  0.9743), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1972, 0.7645,  0.3790), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1150, 0.8582,  0.5719), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1155, 0.8635,  0.1880), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1150, 0.5491,  0.3772), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1908, 0.4160,  0.5491), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3353, 0.4245,  0.5382), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1973, 0.7645,  0.3790), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5029, 0.6297,  0.1916), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1152, 0.8582,  0.5719), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1891, 0.7337,  0.7516), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3315, 0.7487,  0.7761), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4266, 0.7465,  0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4844, 0.7046,  0.5015), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1145, 0.2130,  0.4659), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1637, 0.0963,  0.5378), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3941, 0.4247,  0.1825), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4385, 0.3501,  0.2984), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4336, 0.7406, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.8040, 0.4986, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7335, 0.6233, -0.1818), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7907, 0.5798, -0.3081), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6951, 0.2925, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7426, 0.2082, -0.1081), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7426, 0.2082,  0.1081), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7335, 0.6233,  0.1818), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7907, 0.5798,  0.3081), type: .atom(.hydrogen)),
  ]
  
  static let hydrogenTipMinimizedAtoms: [Entity] = [
    Entity(position: SIMD3( 0.1193, 0.0228, -0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1193, 0.0228, -0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3548, 0.1539, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1456, 0.1686, -0.2842), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0782, 0.2514, -0.1732), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0782, 0.2514,  0.1732), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1456, 0.1686,  0.2842), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1544, 0.1713, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.1456, 0.1685, -0.2842), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0782, 0.2514, -0.1732), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0782, 0.2514,  0.1732), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1456, 0.1685,  0.2842), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1544, 0.1712, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3549, 0.1538, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2531, 0.1800, -0.2704), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3830, 0.0958, -0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1216, 0.0630, -0.2716), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3830, 0.0958,  0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2531, 0.1800,  0.2704), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1216, 0.0630,  0.2716), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1217, 0.0629, -0.2716), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1217, 0.0629,  0.2716), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3831, 0.0957, -0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3831, 0.0957,  0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2531, 0.1800, -0.2704), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2531, 0.1800,  0.2704), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.8039, 0.4992, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7335, 0.6236, -0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7907, 0.5803, -0.3083), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7335, 0.6236,  0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7907, 0.5803,  0.3083), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6928, 0.2943, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7389, 0.2093, -0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7389, 0.2093,  0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3929, 0.4274, -0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4390, 0.3508, -0.2988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4260, 0.7470, -0.3758), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4842, 0.7052, -0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1144, 0.2116, -0.4646), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1630, 0.0951, -0.5372), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3929, 0.4274,  0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4390, 0.3508,  0.2988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4260, 0.7470,  0.3758), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4842, 0.7052,  0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1144, 0.2116,  0.4646), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1630, 0.0951,  0.5372), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5029, 0.6316, -0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4602, 0.3076, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.5029, 0.6316,  0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4330, 0.7411, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1608, 0.4248, -0.1875), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1148, 0.5480, -0.3773), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2035, 0.7631, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154, 0.8634, -0.1878), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154, 0.8634,  0.1878), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1608, 0.4248,  0.1875), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1148, 0.5480,  0.3773), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1143, 0.5501, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1143, 0.5501, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1608, 0.4248, -0.1875), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2036, 0.7631, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1608, 0.4248,  0.1875), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4602, 0.3075, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1953, 0.4039, -0.9347), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3355, 0.4013, -0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548, 0.2693, -0.9727), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1885, 0.7334, -0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3310, 0.7485, -0.7757), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1162, 0.5131, -0.7454), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1904, 0.4145, -0.5489), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3348, 0.4234, -0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1954, 0.4039, -0.9347), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1549, 0.2693, -0.9727), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3356, 0.4012, -0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1163, 0.5131, -0.7454), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1145, 0.2116, -0.4646), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1630, 0.0951, -0.5372), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1965, 0.7638, -0.3789), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1150, 0.8582, -0.5717), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1151, 0.8581, -0.5717), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, 0.4144, -0.5489), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3348, 0.4233, -0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1149, 0.5480, -0.3773), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1886, 0.7334, -0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3311, 0.7484, -0.7757), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1155, 0.8634, -0.1878), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1967, 0.7638, -0.3789), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5030, 0.6315, -0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4261, 0.7470, -0.3758), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4843, 0.7051, -0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3930, 0.4273, -0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4391, 0.3508, -0.2988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1885, 0.7334,  0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3310, 0.7485,  0.7757), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1953, 0.4039,  0.9347), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3355, 0.4013,  0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548, 0.2693,  0.9727), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1904, 0.4145,  0.5489), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3348, 0.4234,  0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1162, 0.5131,  0.7454), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1163, 0.5131,  0.7454), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1954, 0.4039,  0.9347), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1549, 0.2693,  0.9727), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3356, 0.4012,  0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1965, 0.7638,  0.3789), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1150, 0.8582,  0.5717), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1155, 0.8634,  0.1878), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1149, 0.5480,  0.3773), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, 0.4144,  0.5489), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3348, 0.4233,  0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1967, 0.7638,  0.3789), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5030, 0.6315,  0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1151, 0.8581,  0.5717), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1886, 0.7334,  0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3311, 0.7484,  0.7757), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4261, 0.7470,  0.3758), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4843, 0.7051,  0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1145, 0.2116,  0.4646), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1630, 0.0951,  0.5372), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3930, 0.4273,  0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4391, 0.3507,  0.2988), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4331, 0.7410, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.8040, 0.4991, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7336, 0.6235, -0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7908, 0.5802, -0.3083), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6928, 0.2942, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7390, 0.2092, -0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7390, 0.2092,  0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7336, 0.6235,  0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7908, 0.5802,  0.3083), type: .atom(.hydrogen)),
  ]
  
  static let phosphorusTipMinimizedAtoms: [Entity] = [
    Entity(position: SIMD3( 0.1021, -0.0612, -0.0000), type: .atom(.phosphorus)),
    Entity(position: SIMD3(-0.1021, -0.0612, -0.0000), type: .atom(.phosphorus)),
    Entity(position: SIMD3( 0.3557,  0.1521, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1455,  0.1697, -0.2858), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0777,  0.2527, -0.1755), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0777,  0.2527,  0.1755), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1455,  0.1697,  0.2858), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1540,  0.1672, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.1456,  0.1696, -0.2858), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0778,  0.2527, -0.1755), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0778,  0.2527,  0.1755), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1456,  0.1696,  0.2858), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1541,  0.1672, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3557,  0.1521, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2530,  0.1808, -0.2714), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3837,  0.0938, -0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1212,  0.0639, -0.2741), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3837,  0.0938,  0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2530,  0.1808,  0.2714), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1212,  0.0639,  0.2741), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1212,  0.0639, -0.2741), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1212,  0.0639,  0.2741), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3837,  0.0938, -0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3837,  0.0938,  0.0874), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2531,  0.1808, -0.2714), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2531,  0.1808,  0.2714), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.8039,  0.4989, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7337,  0.6235, -0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7910,  0.5803, -0.3083), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7337,  0.6235,  0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7910,  0.5803,  0.3083), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6927,  0.2940, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7390,  0.2091, -0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7390,  0.2091,  0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3939,  0.4267, -0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4395,  0.3502, -0.2991), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4262,  0.7470, -0.3756), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4842,  0.7052, -0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1145,  0.2128, -0.4662), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1636,  0.0966, -0.5388), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3939,  0.4267,  0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4395,  0.3502,  0.2991), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4262,  0.7470,  0.3756), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4842,  0.7052,  0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1145,  0.2128,  0.4662), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1636,  0.0966,  0.5388), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5032,  0.6313, -0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4601,  0.3064, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.5032,  0.6313,  0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4333,  0.7409, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1618,  0.4250, -0.1869), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1149,  0.5484, -0.3763), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2038,  0.7633, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154,  0.8635, -0.1876), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154,  0.8635,  0.1876), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1618,  0.4250,  0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1149,  0.5484,  0.3763), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1142,  0.5506, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1143,  0.5505, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1619,  0.4250, -0.1869), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2039,  0.7633, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1619,  0.4250,  0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4602,  0.3063, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1954,  0.4041, -0.9346), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3356,  0.4014, -0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548,  0.2695, -0.9725), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1888,  0.7339, -0.7514), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3313,  0.7489, -0.7758), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1162,  0.5137, -0.7455), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1906,  0.4161, -0.5488), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3351,  0.4246, -0.5380), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1954,  0.4041, -0.9346), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1549,  0.2694, -0.9725), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3356,  0.4014, -0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1163,  0.5137, -0.7455), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1145,  0.2128, -0.4662), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1636,  0.0966, -0.5388), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1968,  0.7641, -0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1150,  0.8582, -0.5716), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1151,  0.8582, -0.5716), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1907,  0.4161, -0.5488), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3352,  0.4245, -0.5380), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1149,  0.5484, -0.3763), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1890,  0.7338, -0.7514), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3314,  0.7488, -0.7758), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1155,  0.8635, -0.1876), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1969,  0.7641, -0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5033,  0.6312, -0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4263,  0.7469, -0.3756), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4843,  0.7052, -0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3939,  0.4266, -0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4396,  0.3502, -0.2991), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1888,  0.7339,  0.7514), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3313,  0.7489,  0.7758), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1954,  0.4041,  0.9346), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3356,  0.4014,  0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548,  0.2695,  0.9725), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1906,  0.4161,  0.5488), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3351,  0.4246,  0.5380), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1162,  0.5137,  0.7455), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1163,  0.5137,  0.7455), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1954,  0.4041,  0.9346), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1549,  0.2694,  0.9725), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3356,  0.4014,  0.9740), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1968,  0.7641,  0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1150,  0.8582,  0.5715), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1155,  0.8635,  0.1876), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1149,  0.5484,  0.3763), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1907,  0.4161,  0.5488), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3352,  0.4245,  0.5380), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1969,  0.7641,  0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5033,  0.6312,  0.1921), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1151,  0.8582,  0.5715), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1890,  0.7338,  0.7514), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3314,  0.7488,  0.7758), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4263,  0.7469,  0.3756), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4843,  0.7052,  0.5023), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1145,  0.2128,  0.4662), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1636,  0.0966,  0.5388), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3939,  0.4266,  0.1848), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4396,  0.3502,  0.2991), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4334,  0.7408, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.8040,  0.4988, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7338,  0.6234, -0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7911,  0.5802, -0.3083), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6928,  0.2939, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7390,  0.2089, -0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7390,  0.2090,  0.1082), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7338,  0.6234,  0.1820), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7911,  0.5802,  0.3083), type: .atom(.hydrogen)),
  ]
  
  static let boroCarbonTipMinimizedAtoms: [Entity] = [
    Entity(position: SIMD3( 0.0611, -0.0110,  0.0000), type: .atom(.boron)),
    Entity(position: SIMD3(-0.0749, -0.0034,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3553,  0.1480,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1453,  0.1710, -0.2851), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0775,  0.2538, -0.1743), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0775,  0.2538,  0.1743), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1453,  0.1710,  0.2851), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1522,  0.1649,  0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.1454,  0.1715, -0.2853), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0773,  0.2548, -0.1752), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0773,  0.2548,  0.1752), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1454,  0.1715,  0.2853), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1553,  0.1701,  0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3567,  0.1461,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2528,  0.1823, -0.2709), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3835,  0.0901, -0.0876), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1208,  0.0654, -0.2730), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3835,  0.0901,  0.0876), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2528,  0.1823,  0.2709), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1208,  0.0654,  0.2730), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1219,  0.0660, -0.2718), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1219,  0.0660,  0.2718), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3832,  0.0879, -0.0877), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3832,  0.0879,  0.0877), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2528,  0.1837, -0.2714), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2528,  0.1837,  0.2714), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.8038,  0.4983, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7338,  0.6234, -0.1817), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7909,  0.5801, -0.3080), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7338,  0.6234,  0.1817), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7909,  0.5801,  0.3080), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6924,  0.2934,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7393,  0.2087, -0.1080), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7393,  0.2087,  0.1080), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3941,  0.4255, -0.1836), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4387,  0.3499, -0.2988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4265,  0.7468, -0.3751), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4843,  0.7050, -0.5018), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1148,  0.2137, -0.4657), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1642,  0.0972, -0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3941,  0.4255,  0.1836), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4387,  0.3499,  0.2988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4265,  0.7468,  0.3751), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4843,  0.7050,  0.5018), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1148,  0.2137,  0.4657), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1642,  0.0972,  0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5032,  0.6304, -0.1918), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4595,  0.3027,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.5032,  0.6304,  0.1918), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4337,  0.7408,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1621,  0.4258, -0.1859), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1152,  0.5486, -0.3758), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2044,  0.7646, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154,  0.8636, -0.1878), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1154,  0.8636,  0.1878), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1621,  0.4258,  0.1859), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1152,  0.5486,  0.3758), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1142,  0.5522, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1142,  0.5522,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1617,  0.4268, -0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2043,  0.7646,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1617,  0.4268,  0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4605,  0.3014,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1954,  0.4040, -0.9347), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3356,  0.4013, -0.9742), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548,  0.2694, -0.9726), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1889,  0.7339, -0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3314,  0.7489, -0.7759), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1163,  0.5137, -0.7456), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1910,  0.4168, -0.5486), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3355,  0.4251, -0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1954,  0.4039, -0.9348), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1547,  0.2693, -0.9729), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3356,  0.4012, -0.9743), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1161,  0.5136, -0.7458), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1141,  0.2131, -0.4660), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1632,  0.0963, -0.5378), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1971,  0.7643, -0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1151,  0.8582, -0.5716), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1151,  0.8582, -0.5717), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1905,  0.4162, -0.5490), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3349,  0.4245, -0.5381), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1147,  0.5490, -0.3769), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1889,  0.7337, -0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3314,  0.7487, -0.7759), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1154,  0.8636, -0.1879), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1972,  0.7644, -0.3789), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5029,  0.6299, -0.1916), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4265,  0.7467, -0.3748), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4842,  0.7047, -0.5015), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3938,  0.4250, -0.1828), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4383,  0.3501, -0.2985), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1889,  0.7339,  0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3314,  0.7489,  0.7759), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1954,  0.4040,  0.9347), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3356,  0.4013,  0.9742), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1548,  0.2694,  0.9726), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1910,  0.4168,  0.5486), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3355,  0.4251,  0.5379), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1163,  0.5137,  0.7456), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1161,  0.5136,  0.7458), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1954,  0.4039,  0.9348), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1547,  0.2693,  0.9729), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3356,  0.4012,  0.9743), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1971,  0.7643,  0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1151,  0.8582,  0.5716), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1154,  0.8636,  0.1879), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1147,  0.5490,  0.3769), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1905,  0.4162,  0.5490), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3349,  0.4245,  0.5381), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1972,  0.7644,  0.3789), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5029,  0.6299,  0.1916), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1151,  0.8582,  0.5717), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1889,  0.7337,  0.7515), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3314,  0.7487,  0.7759), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4265,  0.7467,  0.3748), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4842,  0.7047,  0.5015), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1141,  0.2131,  0.4660), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1632,  0.0963,  0.5378), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3938,  0.4250,  0.1828), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4383,  0.3501,  0.2985), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4336,  0.7407, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.8039,  0.4983, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7335,  0.6234, -0.1816), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7906,  0.5799, -0.3079), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6934,  0.2929, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7406,  0.2084, -0.1080), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7406,  0.2084,  0.1080), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7335,  0.6234,  0.1816), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7906,  0.5799,  0.3079), type: .atom(.hydrogen)),
  ]
  
  static let boronTipMinimizedAtoms: [Entity] = [
    Entity(position: SIMD3( 0.0613,  0.0000,  0.0000), type: .atom(.boron)),
    Entity(position: SIMD3(-0.0613, -0.0000, -0.0000), type: .atom(.boron)),
    Entity(position: SIMD3( 0.3507,  0.1469,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1474,  0.1684, -0.2906), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0831,  0.2553, -0.1712), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0831,  0.2553,  0.1712), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1474,  0.1684,  0.2906), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1535,  0.1730,  0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.1475,  0.1684, -0.2906), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0831,  0.2553, -0.1712), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0831,  0.2553,  0.1712), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1475,  0.1684,  0.2906), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1535,  0.1730, -0.0000), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3507,  0.1469, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2580,  0.1664, -0.2794), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787,  0.0853, -0.0882), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1164,  0.0626, -0.2765), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787,  0.0853,  0.0882), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2580,  0.1664,  0.2794), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1164,  0.0626,  0.2765), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1164,  0.0626, -0.2765), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1164,  0.0626,  0.2765), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3787,  0.0853, -0.0882), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3787,  0.0853,  0.0882), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2581,  0.1664, -0.2794), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2581,  0.1663,  0.2794), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7971,  0.5018,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7274,  0.6212, -0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7747,  0.5509, -0.3105), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7274,  0.6212,  0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7747,  0.5509,  0.3105), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.6975,  0.2871,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.7428,  0.2106, -0.1200), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.7428,  0.2106,  0.1200), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4042,  0.4165, -0.1904), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4503,  0.3416, -0.3115), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4253,  0.7432, -0.3765), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4728,  0.6721, -0.4995), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1144,  0.2069, -0.4751), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1668,  0.0974, -0.5618), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4042,  0.4165,  0.1904), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4503,  0.3416,  0.3115), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4253,  0.7432,  0.3765), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4728,  0.6721,  0.4995), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1144,  0.2069,  0.4751), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1668,  0.0974,  0.5618), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4960,  0.6294, -0.1883), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4636,  0.3031,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4960,  0.6294,  0.1883), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4241,  0.7430,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1741,  0.4275, -0.1829), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1138,  0.5380, -0.3729), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1949,  0.7571,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1155,  0.8611, -0.1884), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1155,  0.8611,  0.1884), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1741,  0.4275,  0.1829), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1138,  0.5380,  0.3729), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1122,  0.5460, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1123,  0.5460,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1742,  0.4275, -0.1829), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1950,  0.7571, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1742,  0.4275,  0.1829), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4637,  0.3030, -0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1962,  0.4049, -0.9276), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3456,  0.4056, -0.9274), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1530,  0.2620, -0.9255), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1926,  0.7347, -0.7476), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3426,  0.7354, -0.7474), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1165,  0.5148, -0.7395), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1952,  0.4129, -0.5458), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3448,  0.4136, -0.5446), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1963,  0.4049, -0.9276), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1530,  0.2620, -0.9255), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3456,  0.4055, -0.9274), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1166,  0.5148, -0.7395), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1144,  0.2068, -0.4751), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1668,  0.0974, -0.5618), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1949,  0.7520, -0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1156,  0.8534, -0.5652), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1157,  0.8533, -0.5652), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1952,  0.4129, -0.5458), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3449,  0.4136, -0.5446), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1139,  0.5380, -0.3729), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1927,  0.7347, -0.7476), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3427,  0.7354, -0.7474), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1157,  0.8611, -0.1884), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1950,  0.7519, -0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4961,  0.6293, -0.1883), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4254,  0.7431, -0.3765), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4729,  0.6720, -0.4995), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4042,  0.4164, -0.1904), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4503,  0.3415, -0.3115), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1926,  0.7347,  0.7476), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3426,  0.7354,  0.7474), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1962,  0.4049,  0.9276), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3456,  0.4056,  0.9274), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1530,  0.2620,  0.9255), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1952,  0.4129,  0.5458), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3448,  0.4136,  0.5446), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1165,  0.5148,  0.7395), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1166,  0.5148,  0.7395), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1963,  0.4049,  0.9276), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1530,  0.2620,  0.9255), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3456,  0.4055,  0.9274), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1949,  0.7520,  0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1156,  0.8534,  0.5652), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1157,  0.8611,  0.1884), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1139,  0.5380,  0.3729), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1952,  0.4129,  0.5458), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3449,  0.4136,  0.5446), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1950,  0.7519,  0.3749), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4961,  0.6293,  0.1883), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1157,  0.8533,  0.5652), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1927,  0.7347,  0.7476), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3427,  0.7354,  0.7474), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4254,  0.7431,  0.3765), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4729,  0.6720,  0.4995), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1144,  0.2068,  0.4751), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1668,  0.0974,  0.5618), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4042,  0.4164,  0.1904), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4503,  0.3415,  0.3115), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4242,  0.7430,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7971,  0.5017,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7274,  0.6211, -0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7748,  0.5508, -0.3105), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6976,  0.2870,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7428,  0.2105, -0.1200), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7428,  0.2105,  0.1200), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7274,  0.6211,  0.1868), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.7748,  0.5508,  0.3105), type: .atom(.hydrogen)),
  ]
}
