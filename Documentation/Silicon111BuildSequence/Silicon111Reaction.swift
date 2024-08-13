//
//  Silicon111Reaction.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/22/24.
//

import HDL
import xTB

struct Silicon111ReactionDescriptor {
  var siliconTooltip: Silicon111Tooltip?
  var cageTooltip: CageTooltip?
  var frameBudget: Int?
  var nearOffset: SIMD3<Float>?
  var farOffset: SIMD3<Float>?
  
  var netSpin: Float = 0.00
  var electronicTemperature: Float = 300.0
}

// A reaction where a gold tooltip is shaped.
// - The gold tooltip approaches the tripod from above (inverted mode).
struct Silicon111Reaction {
  var _siliconTooltip: Silicon111Tooltip
  var _cageTooltip: CageTooltip
  let frameBudget: Int
  let nearOffset: SIMD3<Float>
  let farOffset: SIMD3<Float>
  
  var time: Float
  var relativePositions: State
  var velocities: State
  
  var calculator: xTB_Calculator!
  
  struct State {
    var siliconSurface: [SIMD3<Float>]
    
    var cageFeedstock: [SIMD3<Float>]
    var cageApex: [SIMD3<Float>]
    var cageFramework: [SIMD3<Float>]
    
    init(siliconTooltip: Silicon111Tooltip, cageTooltip: CageTooltip) {
      func zeros(like atoms: [Entity]) -> [SIMD3<Float>] {
        Array(repeating: .zero, count: atoms.count)
      }
      
      siliconSurface = zeros(like: siliconTooltip.surface)
      
      cageFeedstock = zeros(like: cageTooltip.feedstock)
      cageApex = zeros(like: cageTooltip.apex)
      cageFramework = zeros(like: cageTooltip.framework)
    }
  }
  
  init(descriptor: Silicon111ReactionDescriptor) {
    _siliconTooltip = descriptor.siliconTooltip!
    _cageTooltip = descriptor.cageTooltip!
    frameBudget = descriptor.frameBudget!
    nearOffset = descriptor.nearOffset!
    farOffset = descriptor.farOffset!
    
    time = .zero
    relativePositions = State(
      siliconTooltip: _siliconTooltip, cageTooltip: _cageTooltip)
    velocities = State(
      siliconTooltip: _siliconTooltip, cageTooltip: _cageTooltip)
    
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
    initialize(&relativePositions.siliconSurface, probeOffset)
    
    let probeVelocity = self.velocity(time: time)
    initialize(&velocities.siliconSurface, probeVelocity)
    
    createCalculator(descriptor: descriptor)
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
  
  // Projects the position state onto the gold tooltip.
  func createSiliconTooltip() -> Silicon111Tooltip {
    var siliconTooltip = _siliconTooltip
    Silicon111Reaction.update(
      &siliconTooltip.surface, relativePositions.siliconSurface)
    
    let probeOffset = self.offset(time: time)
    for atomID in siliconTooltip.anchors.indices {
      var atom = siliconTooltip.anchors[atomID]
      atom.position += probeOffset
      siliconTooltip.anchors[atomID] = atom
    }
    return siliconTooltip
  }
  
  // Projects the position state onto the cage tooltip.
  func createCageTooltip() -> CageTooltip {
    var cageTooltip = _cageTooltip
    Silicon111Reaction.update(
      &cageTooltip.feedstock, relativePositions.cageFeedstock)
    Silicon111Reaction.update(
      &cageTooltip.apex, relativePositions.cageApex)
    Silicon111Reaction.update(
      &cageTooltip.framework, relativePositions.cageFramework)
    return cageTooltip
  }
}

// MARK: - Force Evaluation

enum Silicon111Error: Error {
  case feedstockNotFound(String)
  case solverFailed
}

extension Silicon111Reaction {
  mutating func createCalculator(
    descriptor: Silicon111ReactionDescriptor
  ) {
    let siliconTooltip = createSiliconTooltip()
    let cageTooltip = createCageTooltip()
    let siliconLinkAtoms = Silicon111Tooltip.createLinkAtoms(
      inner: siliconTooltip.surface,
      outer: siliconTooltip.anchors,
      boundary: siliconTooltip.boundary)
    let cageLinkAtoms = CageTooltip.createLinkAtoms(
      inner: cageTooltip.framework,
      outer: cageTooltip.legs,
      boundary: cageTooltip.frameworkLegsBoundary)
    
    var initialAtoms:[Entity] = []
    initialAtoms += siliconTooltip.surface
    initialAtoms += siliconLinkAtoms
    initialAtoms += cageTooltip.feedstock
    initialAtoms += cageTooltip.apex
    initialAtoms += cageTooltip.framework
    initialAtoms += cageLinkAtoms
    
    // Create the calculator.
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
    calculatorDesc.hamiltonian = .tightBinding
    calculatorDesc.netSpin = descriptor.netSpin
    calculator = xTB_Calculator(descriptor: calculatorDesc)
    guard xTB_Environment.status == 0 else {
      xTB_Environment.show()
      fatalError("Failed to create calculator.")
    }
    
    calculator.electronicTemperature = descriptor.electronicTemperature
  }
  
  // Sets the calculator to the current state, then queries the forces.
  func singlepoint() throws -> State {
    let siliconTooltip = createSiliconTooltip()
    let cageTooltip = createCageTooltip()
    let siliconLinkAtoms = Silicon111Tooltip.createLinkAtoms(
      inner: siliconTooltip.surface,
      outer: siliconTooltip.anchors,
      boundary: siliconTooltip.boundary)
    let cageLinkAtoms = CageTooltip.createLinkAtoms(
      inner: cageTooltip.framework,
      outer: cageTooltip.legs,
      boundary: cageTooltip.frameworkLegsBoundary)
    
    var atoms: [Entity] = []
    atoms += siliconTooltip.surface
    atoms += siliconLinkAtoms
    atoms += cageTooltip.feedstock
    atoms += cageTooltip.apex
    atoms += cageTooltip.framework
    atoms += cageLinkAtoms
    
    // Evaluate the forces.
    calculator.molecule.positions = atoms.map(\.position)
    var xtbForces = calculator.molecule.forces
    guard calculator.energy != 0 else {
      xTB_Environment.show()
      throw Silicon111Error.solverFailed
    }
    
    // Clamp the magnitude of the forces.
    for forceID in xtbForces.indices {
      var force = xtbForces[forceID]
      let forceMagnitude = (force * force).sum().squareRoot()
      if forceMagnitude > 20000 {
        force *= 20000 / forceMagnitude
      }
      xtbForces[forceID] = force
    }
    
    // Initialize a structure for the total forces.
    let siliconSurfaceOffset: Int = 0
    let siliconLinkOffset = siliconSurfaceOffset + siliconTooltip.surface.count
    let cageFeedstockOffset = siliconLinkOffset + siliconLinkAtoms.count
    let cageApexOffset = cageFeedstockOffset + cageTooltip.feedstock.count
    let cageFrameworkOffset = cageApexOffset + cageTooltip.apex.count
    var forces = State(
      siliconTooltip: siliconTooltip, cageTooltip: cageTooltip)
    
    // Add the forces on the reaction zone.
    for atomID in siliconTooltip.surface.indices {
      let forceOffset = siliconSurfaceOffset + atomID
      let force = xtbForces[forceOffset]
      forces.siliconSurface[atomID] = force
    }
    for atomID in cageTooltip.feedstock.indices {
      let forceOffset = cageFeedstockOffset + atomID
      let force = xtbForces[forceOffset]
      forces.cageFeedstock[atomID] = force
    }
    for atomID in cageTooltip.apex.indices {
      let forceOffset = cageApexOffset + atomID
      let force = xtbForces[forceOffset]
      forces.cageApex[atomID] = force
    }
    for atomID in cageTooltip.framework.indices {
      let forceOffset = cageFrameworkOffset + atomID
      let force = xtbForces[forceOffset]
      forces.cageFramework[atomID] = force
    }
    
    return forces
  }
}

// MARK: - Time Integration

extension Silicon111Reaction {
  static var timeStep: Float {
    0.0025
  }
  
  var halfTime: Float {
    Float(frameBudget / 2) * Silicon111Reaction.timeStep
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
  
  // Performs one iteration of molecular dynamics.
  mutating func step() throws {
    // Execute a singlepoint.
    let forces = try self.singlepoint()
    print("time: \(Format.time(time))", terminator: " | ")
    print("energy: \(Format.energy(calculator.energy))", terminator: " | ")
    do {
      let velocity = self.velocity(time: time)
      let speed = (velocity * velocity).sum().squareRoot()
      print("speed:", String(format: "%.1f", speed * 1000), "m/s")
    }
    
    // Set the target velocity to halfway between the current and next one.
    let startVelocity = self.velocity(time: time)
    let endVelocity = self.velocity(time: time + Silicon111Reaction.timeStep)
    let midpointVelocity = (startVelocity + endVelocity) / 2
    
    var integrationDesc = IntegrationDescriptor()
    let forceScale = createForceScale(
      probeVelocity: midpointVelocity, forces: forces)
    integrationDesc.forceScale = forceScale
    
    // Integrate the gold tooltip.
    integrationDesc.atoms = _siliconTooltip.surface
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.siliconSurface
    integrationDesc.targetVelocity = 0.5 * midpointVelocity
    Silicon111Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.siliconSurface,
      velocities: &velocities.siliconSurface)
    
    // Integrate the cage tooltip.
    integrationDesc.atoms = _cageTooltip.feedstock
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.cageFeedstock
    integrationDesc.targetVelocity = .zero
    Silicon111Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.cageFeedstock,
      velocities: &velocities.cageFeedstock)
    
    integrationDesc.atoms = _cageTooltip.apex
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.cageApex
    integrationDesc.targetVelocity = .zero
    Silicon111Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.cageApex,
      velocities: &velocities.cageApex)
    
    integrationDesc.atoms = _cageTooltip.framework
    integrationDesc.dampingSpeed = 0.95
    integrationDesc.forces = forces.cageFramework
    integrationDesc.targetVelocity = .zero
    Silicon111Reaction.integrate(
      descriptor: integrationDesc,
      relativePositions: &relativePositions.cageFramework,
      velocities: &velocities.cageFramework)
    
    // Set the time to the end of this timestep.
    time += Silicon111Reaction.timeStep
  }
  
  // Utility for querying the mass of an element.
  static func mass(atomicNumber: UInt8) -> Float {
    switch atomicNumber {
    case 1:
      // Making hydrogen heavier, improving stability.
      return 4 * Float(1.6605)
    case 5:
      return 10.81 * Float(1.6605)
    case 6:
      // Use the standard 12 amu mass for carbon.
      return 12.011 * Float(1.6605)
    case 7:
      return 14.007 * Float(1.6605)
    case 8:
      return 15.999 * Float(1.6605)
    case 9:
      return 18.9984031636 * Float(1.6605)
    case 14:
      return 28.085 * Float(1.6605)
    case 15:
      return 30.9737619985 * Float(1.6605)
    case 16:
      return 32.06 * Float(1.6605)
    case 17:
      return 35.45 * Float(1.6605)
    case 32:
      return 72.6308 * Float(1.6605)
    case 34:
      return 78.9718 * Float(1.6605)
    case 35:
      return 79.904 * Float(1.6605)
    case 50:
      return 118.7107 * Float(1.6605)
    case 79:
      // Gold needs to be the actual atomic mass, to have stable simulation at
      // 2 fs/step.
      return 196.9665695 * Float(1.6605)
    case 82:
      return 207.21 * Float(1.6605)
    default:
      fatalError("Unrecognized atom.")
    }
  }
  
  // The quantities that are constant during the integration part.
  private struct IntegrationDescriptor {
    var atoms: [Entity]?
    var dampingSpeed: Float? // proportion of damping per timestep
    var forces: [SIMD3<Float>]?
    var forceScale: Float?
    var targetVelocity: SIMD3<Float>?
  }
  
  // Interesting idea: try FIRE integration on the entire system, instead of
  // damped Verlet integration. This seemed to not work very well in a
  // previous test, so write the initial implementation with Verlet.
  private static func integrate(
    descriptor: IntegrationDescriptor,
    relativePositions: inout [SIMD3<Float>],
    velocities: inout [SIMD3<Float>]
  ) {
    guard let atoms = descriptor.atoms,
          let dampingSpeed = descriptor.dampingSpeed,
          let forces = descriptor.forces,
          let forceScale = descriptor.forceScale,
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
      let mass = Silicon111Reaction.mass(atomicNumber: atomicNumber)
      let force = forces[atomID]
      
      // Integrate the velocity.
      var velocity = velocities[atomID]
      velocity += Silicon111Reaction.timeStep * force / mass
      
      // Temporarily materialize the relative velocity.
      do {
        var delta = velocity - targetVelocity
        
        // Perform FIRE integration.
        if !forceScale.isNaN, !forceScale.isInfinite {
          delta = 0.75 * delta + 0.25 * force * forceScale
        }
        
        // Clamp the magnitude of the velocity.
        let speed = (delta * delta).sum().squareRoot()
        if speed > 4 {
          delta *= 4.0 / speed
        }
        
        // Restore the absolute velocity.
        velocity = targetVelocity + delta
      }
      
      velocity.y = velocity.y * dampingSpeed
      velocity.y += (1 - dampingSpeed) * targetVelocity.y
      velocities[atomID] = velocity
      
      // Integrate the position.
      var position = relativePositions[atomID]
      position += Silicon111Reaction.timeStep * velocity
      relativePositions[atomID] = position
    }
  }
}

// MARK: - FIRE

extension Silicon111Reaction {
  // WARNING: Subtract the target velocities from the actual velocities
  // before entering into this function.
  static func euclideanLength(state: State) -> Float {
    var values: [SIMD3<Float>] = []
    values += state.siliconSurface
    values += state.cageApex
    values += state.cageFeedstock
    values += state.cageFramework
    
    var accumulatorSq: Double = .zero
    for value in values {
      let magnitudeSq = (value * value).sum()
      accumulatorSq += Double(magnitudeSq)
    }
    let norm = accumulatorSq.squareRoot()
    return Float(norm)
  }
  
  // Computes the FIRE force scale from the relative velocities.
  func createForceScale(probeVelocity: SIMD3<Float>, forces: State) -> Float {
    var velocityState = velocities
    for atomID in velocityState.siliconSurface.indices {
      var velocity = velocityState.siliconSurface[atomID]
      velocity -= probeVelocity / 2
      velocityState.siliconSurface[atomID] = velocity
    }
    
    let vNorm = Silicon111Reaction.euclideanLength(state: velocityState)
    let fNorm = Silicon111Reaction.euclideanLength(state: forces)
    return vNorm / fNorm
  }
}

// MARK: - Serialization

enum Silicon111ReactionProduct {
  case rearrangement
  case donation([Element])
  case abstraction([Element])
}

extension Silicon111Reaction {
  func createProduct(type: Silicon111ReactionProduct) throws -> [Entity] {
    var output: [Entity] = []
    let probeOffset = self.offset(time: time)
    
    let siliconTooltip = createSiliconTooltip()
    for atomID in siliconTooltip.surface.indices {
      var atom = siliconTooltip.surface[atomID]
      atom.position -= probeOffset
      output.append(atom)
    }
    
    let cageTooltip = createCageTooltip()
    switch type {
    case .rearrangement:
      break
    case .donation(let elements):
      // Iterate over the feedstock atoms.
      var extractedAtomIDs: Set<UInt32> = []
      for element in elements {
        // Throw an error when a "donated" atom ends up below the apex.
        var greatestY = cageTooltip.apex[0].position.y
        var greatestAtomID: UInt32?
        for atomID in cageTooltip.feedstock.indices {
          // Skip atoms that have already been extracted.
          if extractedAtomIDs.contains(UInt32(atomID)) {
            continue
          }
          
          var atom = cageTooltip.feedstock[atomID]
          atom.position += probeOffset
          guard atom.atomicNumber == element.rawValue else {
            continue
          }
          
          let y = atom.position.y
          if y > greatestY {
            greatestY = y
            greatestAtomID = UInt32(atomID)
          }
        }
        
        guard let greatestAtomID else {
          throw Silicon111Error.feedstockNotFound(
            "There was no \(element) to abstract.")
        }
        extractedAtomIDs.insert(greatestAtomID)
      }
      
      for atomID in extractedAtomIDs {
        var atom = cageTooltip.feedstock[Int(atomID)]
        atom.position -= probeOffset
        output.append(atom)
      }
    case .abstraction(let elements):
      var abstractionSite: Entity?
      do {
        var candidates = cageTooltip.feedstock
        candidates.append(cageTooltip.apex[0])
        
        for atom in candidates {
          if atom.atomicNumber == 1 {
            continue
          }
          if abstractionSite == nil {
            abstractionSite = atom
          } else {
            let y = abstractionSite!.position.y
            if atom.position.y > y {
              abstractionSite = atom
            }
          }
        }
      }
      guard let abstractionSite else {
        throw Silicon111Error.feedstockNotFound(
          "Failed to find abstraction site.")
      }
      
      // Iterate over the extracted atoms.
      var extractedAtomIDs: Set<UInt32> = []
      for element in elements {
        var closestDistance: Float = .greatestFiniteMagnitude
        var closestAtomID: UInt32?
        for atomID in siliconTooltip.surface.indices {
          // Skip atoms that have already been extracted.
          if extractedAtomIDs.contains(UInt32(atomID)) {
            continue
          }
          
          var atom = output[atomID]
          atom.position += probeOffset
          guard atom.atomicNumber == element.rawValue else {
            continue
          }
          
          let delta = atom.position - abstractionSite.position
          let distance = (delta * delta).sum().squareRoot()
          if distance < closestDistance {
            closestDistance = distance
            closestAtomID = UInt32(atomID)
          }
        }
        
        guard let closestAtomID else {
          throw Silicon111Error.feedstockNotFound(
            "There was no \(element) to abstract.")
        }
        extractedAtomIDs.insert(closestAtomID)
      }
      
      // Remove the atoms while preserving the order between them.
      let sortedIDs = Array(extractedAtomIDs).sorted()
      for atomID in sortedIDs.reversed() {
        output.remove(at: Int(atomID))
      }
    }
    
    return output
  }
}
