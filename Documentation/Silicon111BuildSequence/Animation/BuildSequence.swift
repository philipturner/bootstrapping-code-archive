//
//  BuildSequence.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/30/24.
//

import Foundation
import HDL

struct BuildSequence {
  var reactions: [BuildSequenceReaction] = []
  
  init() {
    // Separate the lines.
    let lines = BuildSequence.rawData
      .split(separator: "\n").map(String.init)
    
    // Iterate over the lines.
    for lineID in lines.indices {
      var line = lines[lineID]
      line.removeFirst(3)
      
      // Divide the line into two parts.
      var typeLabel = String(line.dropLast(line.count - 9))
      typeLabel.removeAll(where: { $0.isWhitespace })
      let fileName = String(line.dropFirst(11))
      
      
      
      // Create a reaction object from the parts.
      var descriptor = BuildSequenceReactionDescriptor()
      descriptor.fileName = fileName
      descriptor.number = lineID + 1
      descriptor.typeLabel = typeLabel
      let reaction = BuildSequenceReaction(descriptor: descriptor)
      reactions.append(reaction)
    }
  }
}

extension BuildSequence {
  static let rawData: String = """
// HAbst    - Reaction 1a (2024-06-25 23_56_34 +0000).data
// SiH3     - Reaction 2a (2024-06-26 00_03_03 +0000).data
// HAbst    - Reaction 3a (2024-06-26 00_38_20 +0000).data
// SiH3     - Reaction 4a (2024-06-26 00_43_36 +0000).data
// HAbst    - Reaction 5a (2024-06-26 01_01_13 +0000).data
// SiH3     - Reaction 6a (2024-06-26 01_04_21 +0000).data
// HAbst    - Reaction 7a (2024-06-26 01_06_41 +0000).data
// SiH3     - Reaction 8a (2024-06-26 01_08_45 +0000).data
// HAbst    - Reaction 9a (2024-06-29 23_01_06 +0000).data
// HAbst    - Reaction 10a (2024-06-30 00_23_11 +0000).data
// SiH:     - Reaction 11a (2024-06-30 00_40_19 +0000).data
// HDon     - Reaction 12a (2024-06-30 00_50_04 +0000).data
// Rearr.   - Reaction 13a (2024-06-30 00_59_18 +0000).data
// HAbst    - Reaction 14a (2024-06-30 01_18_26 +0000).data
// SiH3     - Reaction 15a (2024-06-30 01_33_14 +0000).data
// HAbst    - Reaction 16a (2024-06-30 01_36_45 +0000).data
// HAbst    - Reaction 17a (2024-06-30 01_42_27 +0000).data
// SiH3Abst - Reaction 18a (2024-06-30 02_15_12 +0000).data
// HDon     - Reaction 19a (2024-06-30 02_21_49 +0000).data
// HAbst    - Reaction 20a (2024-06-30 04_52_38 +0000).data
// SiH3     - Reaction 21a (2024-06-30 04_57_25 +0000).data
// HAbst    - Reaction 22a (2024-06-30 05_02_19 +0000).data
// HAbst    - Reaction 23a (2024-06-30 05_44_01 +0000).data
// Rearr.   - Reaction 24a (2024-06-30 11_56_44 +0000).data
// HAbst    - Reaction 25a (2024-06-30 12_24_17 +0000).data
// HAbst    - Reaction 26a (2024-06-30 12_37_16 +0000).data
// HAbst    - Reaction 27a (2024-06-30 12_45_05 +0000).data
// SiH3     - Reaction 28a (2024-06-30 13_04_35 +0000).data
// HAbst    - Reaction 29a (2024-06-30 13_12_26 +0000).data
// Rearr.   - Reaction 30a (2024-06-30 13_21_18 +0000).data
// HDon     - Reaction 31a (2024-06-30 13_26_35 +0000).data
// HAbst    - Reaction 32a (2024-06-30 13_32_06 +0000).data
// SiH3     - Reaction 33a (2024-06-30 13_40_38 +0000).data
// HAbst    - Reaction 34a (2024-06-30 14_18_32 +0000).data
// HAbst    - Reaction 35a (2024-06-30 14_26_58 +0000).data
// HAbst    - Reaction 36a (2024-06-30 14_36_17 +0000).data
// Rearr.   - Reaction 37a (2024-06-30 14_48_05 +0000).data
// SiH3     - Reaction 38a (2024-06-30 15_07_23 +0000).data
// HAbst    - Reaction 39a (2024-06-30 15_16_13 +0000).data
// SiH3     - Reaction 40a (2024-06-30 15_25_40 +0000).data
// HAbst    - Reaction 41a (2024-06-30 15_29_45 +0000).data
// SiH3     - Reaction 42a (2024-06-30 15_35_08 +0000).data
// HAbst    - Reaction 43a (2024-06-30 15_50_37 +0000).data
// HAbst    - Reaction 44a (2024-06-30 15_54_24 +0000).data
// GeH:     - Reaction 45a (2024-06-30 18_53_20 +0000).data
// CH2      - Reaction 46a (2024-06-30 19_22_02 +0000).data
// HAbst    - Reaction 47a (2024-06-30 19_30_31 +0000).data
// Rearr.   - Reaction 48a (2024-06-30 19_40_10 +0000).data
"""
}
