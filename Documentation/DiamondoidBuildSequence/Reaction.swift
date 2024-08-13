//
//  Reaction.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/7/24.
//

import HDL
import MM4
import xTB

#if false

// MARK: - Type Declaration

struct ReactionDescriptor {
  var metallicSurface: BuildPlate?
  var buildPlate: BuildPlate?
  var tooltip: CurrentTooltip?
  var frameBudget: Int?
  var nearOffset: SIMD3<Float>?
  var farOffset: SIMD3<Float>?
}

struct Reaction {
  let metallicSurface: BuildPlate
  var _buildPlate: BuildPlate
  var _tooltip: CurrentTooltip
  let frameBudget: Int
  let nearOffset: SIMD3<Float>
  let farOffset: SIMD3<Float>
  
  var time: Float
  var relativePositions: State
  var velocities: State
  
  var innerHighCalculator: xTB_Calculator!
  var innerLowCalculator: xTB_Calculator!
  var outerLowCalculator: xTB_Calculator!
  
  init(descriptor: ReactionDescriptor) {
    self.metallicSurface = descriptor.metallicSurface!
    self._buildPlate = descriptor.buildPlate!
    self._tooltip = descriptor.tooltip!
    self.frameBudget = descriptor.frameBudget!
    self.nearOffset = descriptor.nearOffset!
    self.farOffset = descriptor.farOffset!
    
    self.time = .zero
    self.relativePositions = State(buildPlate: _buildPlate, tooltip: _tooltip)
    self.velocities = State(buildPlate: _buildPlate, tooltip: _tooltip)
    
    // Place the system into the initial state.
    func initialize(
      _ array: inout [SIMD3<Float>],
      _ addedValue: SIMD3<Float>
    ) {
      for elementID in array.indices {
        array[elementID] += addedValue
      }
    }
    
    let probeOffset = self.offset(time: time)
    initialize(&relativePositions.dimer, probeOffset)
    initialize(&relativePositions.reactiveSite, probeOffset)
    initialize(&relativePositions.nearFramework, probeOffset)
    
    let probeVelocity = self.velocity(time: time)
    initialize(&velocities.dimer, probeVelocity)
    initialize(&velocities.reactiveSite, probeVelocity)
    initialize(&velocities.nearFramework, probeVelocity)
    
    // Create the calculators after the moving atoms are positioned at the
    // starting point. Otherwise, GFN-FF will parametrize the outermost
    // atoms as having broken bonds.
    createCalculators()
  }
  
  // A floating-point vector describing a dynamical variable.
  struct State {
    var graphene: [SIMD3<Float>]
    var product: [SIMD3<Float>]
    
    var dimer: [SIMD3<Float>]
    var reactiveSite: [SIMD3<Float>]
    var nearFramework: [SIMD3<Float>]
    
    init(buildPlate: BuildPlate, tooltip: CurrentTooltip) {
      func zeros(like atoms: [Entity]) -> [SIMD3<Float>] {
        Array(repeating: .zero, count: atoms.count)
      }
      
      graphene = zeros(like: buildPlate.graphene)
      product = zeros(like: buildPlate.product)
      
      dimer = zeros(like: tooltip.dimer)
      reactiveSite = zeros(like: tooltip.reactiveSite)
      nearFramework = zeros(like: tooltip.nearFramework)
    }
  }
  
  // Utility function for adding relative positions.
  private static func update(
    _ atoms: inout [Entity],
    _ relativePositions: [SIMD3<Float>]
  ) {
    guard atoms.count == relativePositions.count else {
      fatalError("Arrays did not have same length.")
    }
    for atomID in atoms.indices {
      var atom = atoms[atomID]
      atom.position += relativePositions[atomID]
      atoms[atomID] = atom
    }
  }
  
  // Projects the position state onto the build plate.
  func createBuildPlate() -> BuildPlate {
    var buildPlate = _buildPlate
    Reaction.update(&buildPlate.graphene, relativePositions.graphene)
    Reaction.update(&buildPlate.product, relativePositions.product)
    return buildPlate
  }
  
  // Projects the position state onto the tooltip.
  func createTooltip() -> CurrentTooltip {
    var tooltip = _tooltip
    Reaction.update(&tooltip.dimer, relativePositions.dimer)
    Reaction.update(&tooltip.reactiveSite, relativePositions.reactiveSite)
    Reaction.update(&tooltip.nearFramework, relativePositions.nearFramework)
    
    let probeOffset = self.offset(time: time)
    for atomID in tooltip.farFramework.indices {
      var atom = tooltip.farFramework[atomID]
      atom.position += probeOffset
      tooltip.farFramework[atomID] = atom
    }
    return tooltip
  }
}

// MARK: - Force Evaluation

extension Reaction {
  mutating func createCalculators() {
    let buildPlate = createBuildPlate()
    let tooltip = createTooltip()
    
    // Set up the xTB calculator.
    do {
      var initialAtoms: [Entity] = []
      initialAtoms += buildPlate.anchors
      initialAtoms += buildPlate.graphene
      initialAtoms += buildPlate.product
      initialAtoms += tooltip.dimer
      initialAtoms += tooltip.reactiveSite
      initialAtoms += tooltip.createInnerOuterBoundaryAtoms()
      
      // Create the calculator.
      var calculatorDesc = xTB_CalculatorDescriptor()
      calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
      calculatorDesc.hamiltonian = .tightBinding
      innerHighCalculator = xTB_Calculator(descriptor: calculatorDesc)
      guard xTB_Environment.status == 0 else {
        xTB_Environment.show()
        fatalError("Failed to create calculator.")
      }
    }
    
    // Set up the GFN-FF calculators.
    do {
      var movedMetallicSurface = metallicSurface
      var movedBuildPlate = buildPlate
      var movedTooltip = tooltip
      movedMetallicSurface.translate(offset: [0, -15, 0])
      movedBuildPlate.translate(offset: [0, -10, 0])
      movedTooltip.translate(offset: [0, -5, 0])
      
      // GFN-FF does not initialize when the dimer is bound.
      var movedDimer = movedTooltip.dimer
      guard movedDimer.count == 2 else {
        fatalError("Dimer had unexpected chemical composition.")
      }
      if movedDimer[0].atomicNumber == 1 {
        movedDimer[0].position.x -= 2
        movedDimer[1].position.x += 2
      }
      movedTooltip = tooltip
      movedTooltip.dimer = movedDimer
      
      do {
        var initialAtoms: [Entity] = []
        initialAtoms += movedBuildPlate.anchors
        initialAtoms += movedBuildPlate.graphene
        initialAtoms += movedBuildPlate.product
        initialAtoms += movedTooltip.dimer
        initialAtoms += movedTooltip.reactiveSite
        initialAtoms += movedTooltip.createInnerOuterBoundaryAtoms()
        
        // Create the calculator.
        var calculatorDesc = xTB_CalculatorDescriptor()
        calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
        calculatorDesc.hamiltonian = .forceField
        calculatorDesc.positions = initialAtoms.map(\.position)
        innerLowCalculator = xTB_Calculator(descriptor: calculatorDesc)
        guard xTB_Environment.status == 0 else {
          fatalError("Failed to create calculator.")
        }
      }
      
      do {
        var initialAtoms: [Entity] = []
        initialAtoms += movedBuildPlate.anchors
        initialAtoms += movedBuildPlate.graphene
        initialAtoms += movedBuildPlate.product
        initialAtoms += movedTooltip.dimer
        initialAtoms += movedTooltip.reactiveSite
        initialAtoms += movedTooltip.nearFramework
        initialAtoms += movedTooltip.createOuterAnchorBoundaryAtoms()
        initialAtoms += movedMetallicSurface.anchors
        initialAtoms += movedMetallicSurface.graphene
        initialAtoms += movedMetallicSurface.product
        
        // Create the calculator.
        var calculatorDesc = xTB_CalculatorDescriptor()
        calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
        calculatorDesc.hamiltonian = .forceField
        calculatorDesc.positions = initialAtoms.map(\.position)
        outerLowCalculator = xTB_Calculator(descriptor: calculatorDesc)
        guard xTB_Environment.status == 0 else {
          fatalError("Failed to create calculator.")
        }
      }
    }
  }
  
  // Sets the calculators to the current state, then queries the forces.
  func singlepoint() -> State {
    let buildPlate = createBuildPlate()
    let tooltip = createTooltip()
    
    var innerForces: [SIMD3<Float>]
    do {
      var innerAtoms: [Entity] = []
      innerAtoms += buildPlate.anchors
      innerAtoms += buildPlate.graphene
      innerAtoms += buildPlate.product
      innerAtoms += tooltip.dimer
      innerAtoms += tooltip.reactiveSite
      innerAtoms += tooltip.createInnerOuterBoundaryAtoms()
      innerHighCalculator.molecule.positions = innerAtoms.map(\.position)
      innerLowCalculator.molecule.positions = innerAtoms.map(\.position)
      
      // Evaluate the forces.
      let innerHighForces = innerHighCalculator.molecule.forces
      guard innerHighCalculator.energy != 0 else {
        fatalError("Failed to evaluate forces.")
      }
      let innerLowForces = innerLowCalculator.molecule.forces
      guard innerLowCalculator.energy != 0 else {
        fatalError("Failed to evaluate forces.")
      }
      
      innerForces = Array(repeating: .zero, count: innerHighForces.count)
      for forceID in innerForces.indices {
        let force = innerHighForces[forceID] - innerLowForces[forceID]
        innerForces[forceID] = force
      }
    }
    
    var outerForces: [SIMD3<Float>]
    do {
      var outerAtoms: [Entity] = []
      outerAtoms += buildPlate.anchors
      outerAtoms += buildPlate.graphene
      outerAtoms += buildPlate.product
      outerAtoms += tooltip.dimer
      outerAtoms += tooltip.reactiveSite
      outerAtoms += tooltip.nearFramework
      
      // Freeze the anchors to prevent additional motion.
      var anchors = _tooltip.createOuterAnchorBoundaryAtoms()
      let targetOffset = self.offset(time: self.time)
      for anchorID in anchors.indices {
        anchors[anchorID].position += targetOffset
      }
      outerAtoms += anchors
      outerAtoms += metallicSurface.anchors
      outerAtoms += metallicSurface.graphene
      outerAtoms += metallicSurface.product
      
      outerLowCalculator.molecule.positions = outerAtoms.map(\.position)
      
      // Evaluate the forces.
      outerForces = outerLowCalculator.molecule.forces
      guard outerLowCalculator.energy != 0 else {
        fatalError("Failed to evaluate forces.")
      }
    }
    
    // Initialize a structure for the total forces.
    let grapheneOffset = buildPlate.anchors.count
    let productOffset = grapheneOffset + buildPlate.graphene.count
    let dimerOffset = productOffset + buildPlate.product.count
    let reactiveSiteOffset = dimerOffset + tooltip.dimer.count
    var forces = State(buildPlate: buildPlate, tooltip: tooltip)
    
    // Add the forces on the reaction zone.
    for atomID in buildPlate.graphene.indices {
      let forceOffset = grapheneOffset + atomID
      let force = outerForces[forceOffset] + innerForces[forceOffset]
      forces.graphene[atomID] += force
    }
    for atomID in buildPlate.product.indices {
      let forceOffset = productOffset + atomID
      let force = outerForces[forceOffset] + innerForces[forceOffset]
      forces.product[atomID] += force
    }
    for atomID in tooltip.dimer.indices {
      let forceOffset = dimerOffset + atomID
      let force = outerForces[forceOffset] + innerForces[forceOffset]
      forces.dimer[atomID] += force
    }
    for atomID in tooltip.reactiveSite.indices {
      let forceOffset = reactiveSiteOffset + atomID
      let force = outerForces[forceOffset] + innerForces[forceOffset]
      forces.reactiveSite[atomID] += force
    }
    
    // Add forces on the inner-outer boundary.
    let innerOuterOffset = reactiveSiteOffset + tooltip.reactiveSite.count
    for bondID in tooltip.innerOuterBoundary.indices {
      let bond = tooltip.innerOuterBoundary[bondID]
      let innerAtom = tooltip.reactiveSite[Int(bond[0])]
      let outerAtom = tooltip.nearFramework[Int(bond[1])]
      guard innerAtom.atomicNumber == 6,
            outerAtom.atomicNumber == 14 else {
        fatalError("Unexpected boundary bond.")
      }
      let d1: Float = 1.1120 / 10
      let d2: Float = 1.876 / 10
      let k = d1 / d2
      
      let forceOffset = innerOuterOffset + bondID
      let force = innerForces[forceOffset]
      forces.reactiveSite[Int(bond[0])] += (1 - k) * force
      forces.nearFramework[Int(bond[1])] += k * force
    }
    
    // Add forces on the framework.
    let nearFrameworkOffset = reactiveSiteOffset + tooltip.reactiveSite.count
    for atomID in tooltip.nearFramework.indices {
      let forceOffset = nearFrameworkOffset + atomID
      let force = outerForces[forceOffset]
      forces.nearFramework[atomID] += force
    }
    
    return forces
  }
}

// MARK: - Time Integration

extension Reaction {
  var halfTime: Float {
    Float(frameBudget / 2) * 0.0025
  }
  
  func offset(time: Float) -> SIMD3<Float> {
    let progress = (time - halfTime) / halfTime
    return (progress * progress) * (farOffset - nearOffset) + nearOffset
  }
  
  func velocity(time: Float) -> SIMD3<Float> {
    var analyticalVelocity = 2 * (farOffset - nearOffset) / halfTime
    analyticalVelocity *= (time - halfTime) / halfTime
    return analyticalVelocity
  }
  
  mutating func step() {
    // Execute a singlepoint.
    let forces = self.singlepoint()
    var energy: Double = .zero
    energy += outerLowCalculator.energy
    energy += innerHighCalculator.energy - innerLowCalculator.energy
    print("time: \(Format.time(time))", terminator: " | ")
    print("energy: \(Format.energy(energy))", terminator: " | ")
    
    do {
      let velocity = self.velocity(time: time)
      let speed = (velocity * velocity).sum().squareRoot()
      print("speed:", String(format: "%.1f", speed * 1000), "m/s")
    }
    
    // Integrate the build plate.
    var integrationDesc = IntegrationDescriptor()
    integrationDesc.atoms = _buildPlate.graphene
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.graphene
    integrationDesc.targetVelocity = .zero
    Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.graphene,
      velocities: &velocities.graphene)
    
    integrationDesc.atoms = _buildPlate.product
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.product
    integrationDesc.targetVelocity = .zero
    Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.product,
      velocities: &velocities.product)
    
    // Set the target velocity to halfway between the current and next one.
    let startVelocity = self.velocity(time: time)
    let endVelocity = self.velocity(time: time + 0.0025)
    let midpointVelocity = (startVelocity + endVelocity) / 2
    
    // Integrate the tooltip.
    integrationDesc.atoms = _tooltip.dimer
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.dimer
    integrationDesc.targetVelocity = 0.5 * midpointVelocity
    Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.dimer,
      velocities: &velocities.dimer)
    
    integrationDesc.atoms = _tooltip.reactiveSite
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.reactiveSite
    integrationDesc.targetVelocity = midpointVelocity
    Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.reactiveSite,
      velocities: &velocities.reactiveSite)
    
    integrationDesc.atoms = _tooltip.nearFramework
    integrationDesc.dampingSpeed = 0.85
    integrationDesc.forces = forces.nearFramework
    integrationDesc.targetVelocity = midpointVelocity
    Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.nearFramework,
      velocities: &velocities.nearFramework)
    
    // Set the time to the end of this timestep.
    time += 0.0025
  }
  
  static func mass(atomicNumber: UInt8) -> Float {
    switch atomicNumber {
    case 1:
      return 4 * Float(MM4YgPerAmu)
    case 5:
      return 10.811 * Float(MM4YgPerAmu)
    case 6:
      return 12.011 * Float(MM4YgPerAmu)
    case 14:
      // Make silicon lighter to speed up the simulation. This provides a
      // conservative estimate of the positional uncertainty.
      return 12.011 * Float(MM4YgPerAmu)
    case 15:
      // Make silicon lighter to speed up the simulation. This provides a
      // conservative estimate of the positional uncertainty.
      return 12.011 * Float(MM4YgPerAmu)
    case 32:
      // Make germanium lighter to speed up the simulation. This provides a
      // conservative estimate of the positional uncertainty.
      return 12.011 * Float(MM4YgPerAmu)
    default:
      fatalError("Unrecognized atom.")
    }
  }
  
  // The quantities that are constant during the integration part.
  private struct IntegrationDescriptor {
    var atoms: [Entity]?
    var dampingSpeed: Float? // proportion of damping per timestep
    var forces: [SIMD3<Float>]?
    var targetVelocity: SIMD3<Float>?
  }
  
  // Utility function for integrating a dynamical variable.
  private static func integrate(
    descriptor: IntegrationDescriptor,
    relativePositions: inout [SIMD3<Float>],
    velocities: inout [SIMD3<Float>]
  ) {
    guard let atoms = descriptor.atoms,
          let dampingSpeed = descriptor.dampingSpeed,
          let forces = descriptor.forces,
          let targetVelocity = descriptor.targetVelocity else {
      fatalError("Descriptor was incomplete.")
    }
    guard atoms.count == relativePositions.count,
          atoms.count == velocities.count,
          atoms.count == forces.count else {
      fatalError("Arrays did not have the same length.")
    }
    
    // Iterate over the atoms.
    for atomID in atoms.indices {
      let atomicNumber = atoms[atomID].atomicNumber
      let mass = Reaction.mass(atomicNumber: atomicNumber)
      
      // Integrate the velocity.
      var velocity = velocities[atomID]
      velocity += 0.0025 * forces[atomID] / mass
      
      velocity = velocity * dampingSpeed
      velocity += (1 - dampingSpeed) * targetVelocity
      velocities[atomID] = velocity
      
      // Integrate the position.
      var position = relativePositions[atomID]
      position += 0.0025 * velocity
      relativePositions[atomID] = position
    }
  }
}

#endif
