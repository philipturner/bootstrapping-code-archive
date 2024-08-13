//
//  AtomCoder.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/7/24.
//

import HDL
import xTB

struct AtomCoder {
  static let atomicNumbersToSymbolsMap: [UInt8: String] = [
    1: "h",
    6: "c",
    7: "n",
    8: "o",
    9: "f",
    14: "si",
    15: "p",
    16: "s",
    32: "ge",
    50: "sn",
    82: "pb"
  ]
  
  enum Encoding {
    case hdl
    case xtb
  }
  
  static func encode(
    _ input: [Entity], encoding: Encoding = .xtb
  ) throws -> String {
    var output: [String] = []
    switch encoding {
    case .hdl:
      output.append("[")
    case .xtb:
      output.append("$coord")
    }
    
    var columnSizes: SIMD4<Int> = .zero
    for pass in 0..<2 {
      for atomID in input.indices {
        // Encode the position.
        let atom = input[atomID]
        var strings: [String] = []
        for lane in 0..<3 {
          let valueInNm = atom.position[lane]
          var string: String
          switch encoding {
          case .hdl:
            string = String(format: "%.4f", valueInNm)
          case .xtb:
            let valueInBohr = Double(valueInNm) * xTB_BohrPerNm
            string = String(format: "%.3f", valueInBohr)
          }
          strings.append(string)
        }
        
        // Encode the atomic number.
        let atomicNumber = atom.atomicNumber
        var symbol: String?
        switch encoding {
        case .hdl:
          if let element = Element(rawValue: atomicNumber) {
            symbol = ".atom(\(element.description))"
          }
        case .xtb:
          symbol = Self.atomicNumbersToSymbolsMap[atomicNumber]
        }
        guard let symbol else {
          fatalError("'\(atomicNumber)' is not a recognized atomic number.")
        }
        strings.append(symbol)
        
        // Find the largest column size on pass 0.
        for i in 0..<4 {
          columnSizes[i] = max(columnSizes[i], strings[i].count)
        }
        guard pass == 1 else {
          continue
        }
        
        // Encode the actual line on pass 1.
        for i in 0..<3 {
          var string = strings[i]
          let columnSize = columnSizes[i]
          while string.count < columnSize {
            string = " " + string
          }
          strings[i] = string
        }
        
        var line = "  "
        switch encoding {
        case .hdl:
          let vector = "SIMD3(\(strings[0]), \(strings[1]), \(strings[2]))"
          line += "Entity(position: \(vector), type: \(strings[3])),"
        case .xtb:
          line += "\(strings[0]) \(strings[1]) \(strings[2]) \(strings[3])"
        }
        output.append(line)
      }
    }
    
    switch encoding {
    case .hdl:
      output.append("]")
    case .xtb:
      output.append("$end")
    }
    
    // Don't append a newline. It should be the user's job to decide how
    // whitespace is formatted.
    return output.joined(separator: "\n")
  }
}
