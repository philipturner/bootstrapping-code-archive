//
//  Monocraft.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/20/24.
//

import CairoGraphics
import GIF
import Foundation

// A configuration for a written character.
struct MonocraftCharacterDescriptor {
  // 40 array slots specifying the pixels.
  var bitmap: [UInt8]?
  
  // Color in RGB.
  var color: SIMD3<UInt8>?
  
  // Offset from upper left in pixels.
  var position: SIMD2<Int>?
  
  // Size of each bitmap segment in pixels.
  var size: Int?
}

// A configuration for a sequence of written characters.
struct MonocraftTextDescriptor {
  // The characters that make up the text.
  var characters: [Character]?
  
  // The color of each character.
  var colors: [MonocraftColor]?
  
  // Offset from upper left in pixels.
  var position: SIMD2<Int>?
  
  // Size of each bitmap segment in pixels.
  var size: Int?
}

// A configuration for an intermediate text rendering layer.
struct MonocraftMaskDescriptor {
  // The image that was rendered to.
  var image: CairoImage?
  
  // The opacity of the layer.
  var opacity: Float?
}

struct Monocraft {
  // Writes the character onto a region of the image.
  static func drawCharacter(
    image: CairoImage, descriptor: MonocraftCharacterDescriptor
  ) {
    guard let bitmap = descriptor.bitmap,
          let color = descriptor.color,
          let position = descriptor.position,
          let size = descriptor.size else {
      fatalError("Descriptor was incomplete.")
    }
    
    let bgra = SIMD4<UInt8>(
      UInt8(color[2]),
      UInt8(color[1]),
      UInt8(color[0]),
      UInt8(255))
    let pixelScalar = unsafeBitCast(bgra, to: UInt32.self)
    let colorObject = Color(argb: pixelScalar)
    
    // Iterate over the bitmap.
    guard bitmap.count == 40 else {
      fatalError("Bitmap had incorrect size.")
    }
    for bitmapY in 0..<8 {
      for bitmapX in 0..<5 {
        // Skip transparent pixels.
        let bitmapAddress = bitmapY * 5 + bitmapX
        let bitmapValue = bitmap[bitmapAddress]
        guard bitmapValue > 0 else {
          continue
        }
        
        // Iterate over the subpixels.
        let maximumY = image.height - 1
        let maximumX = image.width - 1
        for subpixelY in 0..<size {
          for subpixelX in 0..<size {
            var imageY = position.y + bitmapY * size
            var imageX = position.x + bitmapX * size
            imageY += subpixelY
            imageX += subpixelX
            imageY = min(imageY, maximumY)
            imageX = min(imageX, maximumX)
            
            image[imageY, imageX] = colorObject
          }
        }
      }
    }
  }
  
  // Writes the text onto a region of the image.
  static func drawText(
    image: CairoImage, descriptor: MonocraftTextDescriptor
  ) {
    guard let characters = descriptor.characters,
          let colors = descriptor.colors,
          let position = descriptor.position,
          let size = descriptor.size else {
      fatalError("Descriptor was incomplete.")
    }
    guard characters.count == colors.count else {
      fatalError("Colors array must have same size as characters array.")
    }
    
    for isBackground in [true, false] {
      var rowStart: Int = .zero
      for characterID in characters.indices {
        let character = characters[characterID]
        let monocraftColor = colors[characterID]
        
        var rgbColor: SIMD3<UInt8>
        if isBackground {
          rgbColor = Monocraft.createBackgroundColor(monocraftColor)
        } else {
          rgbColor = Monocraft.createForegroundColor(monocraftColor)
        }
        
        let (bitmap, offset, spacing) = Monocraft
          .createBitmap(character: character)
        
        var characterDesc = MonocraftCharacterDescriptor()
        characterDesc.bitmap = bitmap
        characterDesc.color = rgbColor
        characterDesc.position = SIMD2(
          position.x + ((isBackground ? 1 : 0) + rowStart + offset) * size,
          position.y + ((isBackground ? 1 : 0)) * size)
        characterDesc.size = size
        Monocraft.drawCharacter(image: image, descriptor: characterDesc)
        
        rowStart += spacing
      }
    }
  }
  
  // Writes a mask onto the image.
  static func drawMask(
    image: CairoImage, descriptor: MonocraftMaskDescriptor
  ) {
    guard let maskImage = descriptor.image,
          let opacity = descriptor.opacity else {
      fatalError("Descriptor was incomplete.")
    }
    
    for y in 0..<maskImage.height {
      for x in 0..<maskImage.width {
        let maskColor = maskImage[y, x]
        guard maskColor.alpha != 0 else {
          continue
        }
        
        // Perform alpha blending.
        @_transparent
        func createVector(color: Color) -> SIMD3<Float> {
          SIMD3(Float(color.red) / 255,
                Float(color.green) / 255,
                Float(color.blue) / 255)
        }
        let previousImageColor = image[y, x]
        let previousImageVector = createVector(color: previousImageColor)
        let maskVector = createVector(color: maskColor)
        
        var nextVector: SIMD3<Float> = .zero
        nextVector += previousImageVector * (1 - opacity)
        nextVector += maskVector * opacity
        nextVector *= 255
        nextVector.round(.toNearestOrEven)
        
        // Transform into a color.
        let nextImageColor = Color(
          red: UInt8(nextVector.x),
          green: UInt8(nextVector.y),
          blue: UInt8(nextVector.z),
          alpha: 255)
        image[y, x] = nextImageColor
      }
    }
  }
}

// MARK: - Letters

// https://minecraft.fandom.com/wiki/Formatting_codes
enum MonocraftColor {
  case gold
  case white
}

extension Monocraft {
  static func createForegroundColor(_ color: MonocraftColor) -> SIMD3<UInt8> {
    switch color {
    case .gold:
      return SIMD3(0xFF, 0xAA, 0x00)
    case .white:
      return SIMD3(0xFF, 0xFF, 0xFF)
    }
  }
  
  static func createBackgroundColor(_ color: MonocraftColor) -> SIMD3<UInt8> {
    switch color {
    case .gold:
      // Choose the Bedrock Edition's color over the Java Edition's color.
      return SIMD3(0x40, 0x2A, 0x00)
    case .white:
      return SIMD3(0x3F, 0x3F, 0x3F)
    }
  }
  
  static func createBitmap(character: Character) -> (
    bitmap: [UInt8], offset: Int, spacing: Int
  ) {
    var string: String
    var offset: Int = 0
    var spacing: Int = 6
    
    // adamantane(.carbon)
    // adamantane(.silicon)
    // adamantane(.germanium)
    // atrane(.tin)
    //
    // +
    //
    // FIRE
    //
    // 0123456789
    //
    // tooltips
    // electronic structures solved
    
    switch character {
      // Capital letters.
    case "A":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
      """
    case "B":
      string = """
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0]
      """
    case "C":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "D":
      string = """
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0]
      """
    case "E":
      string = """
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 1]
      """
    case "F":
      string = """
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0]
      """
    case "G":
      string = """
      [0, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "I":
      string = """
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0]
      """
      offset = -1
      spacing = 4
    case "M":
      string = """
      [1, 0, 0, 0, 1],
      [1, 1, 0, 1, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
      """
    case "R":
      string = """
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
      """
    case "S":
      string = """
      [0, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
      
      // Small letters.
    case "a":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 0, 0, 1],
      [0, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1]
      """
    case "b":
      string = """
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 1, 1, 0],
      [1, 1, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0]
      """
    case "c":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "d":
      string = """
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [0, 1, 1, 0, 1],
      [1, 0, 0, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1]
      """
    case "e":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [0, 1, 1, 1, 1]
      """
    case "f":
      string = """
      [0, 0, 0, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0]
      """
      offset = -1
      spacing = 5
    case "g":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1],
      [0, 0, 0, 0, 1],
      [1, 1, 1, 1, 0]
      """
    case "h":
      string = """
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 1, 1, 0],
      [1, 1, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
      """
    case "i":
      string = """
      [0, 0, 1, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 1, 1]
      """
      offset = -1
      spacing = 5
    case "j":
      string = """
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "k":
      string = """
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 1, 0],
      [1, 0, 1, 0, 0],
      [1, 1, 0, 0, 0],
      [1, 0, 1, 0, 0],
      [1, 0, 0, 1, 0]
      """
      spacing = 5
    case "l":
      string = """
      [0, 1, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 1, 1]
      """
      offset = -1
      spacing = 5
    case "m":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 1, 0, 1, 0],
      [1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
      """
    case "n":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1]
      """
    case "o":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "p":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 1, 1, 0],
      [1, 1, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0]
      """
    case "q":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 0, 1],
      [1, 0, 0, 1, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1]
      """
    case "r":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 1, 1, 0],
      [1, 1, 0, 0, 1],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 0, 0, 0, 0]
      """
    case "s":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 0, 0, 1],
      [1, 1, 1, 1, 0]
      """
    case "t":
      string = """
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 1, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 1, 1]
      """
      offset = -1
      spacing = 5
    case "u":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1]
      """
    case "v":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0]
      """
    case "w":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 1, 0, 1],
      [1, 0, 1, 0, 1],
      [0, 1, 1, 1, 1]
      """
    case "x":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 0, 1]
      """
    case "y":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1],
      [0, 0, 0, 0, 1],
      [1, 1, 1, 1, 0]
      """
    case "z":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0],
      [1, 1, 1, 1, 1]
      """
      
      // Numbers.
    case "0":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 1, 1],
      [1, 0, 1, 0, 1],
      [1, 1, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "1":
      string = """
      [0, 0, 1, 0, 0],
      [0, 1, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [1, 1, 1, 1, 1]
      """
    case "2":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 1, 1, 0],
      [0, 1, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1]
      """
    case "3":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 1, 1, 0],
      [0, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "4":
      string = """
      [0, 0, 0, 1, 1],
      [0, 0, 1, 0, 1],
      [0, 1, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1]
      """
    case "5":
      string = """
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "6":
      string = """
      [0, 0, 1, 1, 0],
      [0, 1, 0, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "7":
      string = """
      [1, 1, 1, 1, 1],
      [1, 0, 0, 0, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0]
      """
    case "8":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 0]
      """
    case "9":
      string = """
      [0, 1, 1, 1, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 0, 1],
      [0, 1, 1, 1, 1],
      [0, 0, 0, 0, 1],
      [0, 0, 0, 1, 0],
      [0, 1, 1, 0, 0]
      """
      
      // Symbols.
    case " ":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0]
      """
      spacing = 4
    case "+":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 1, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 0, 0]
      """
    case ",":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0]
      """
      spacing = 5
    case "-":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0]
      """
    case ".":
      string = """
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 1, 0, 0]
      """
      offset = -1
      spacing = 4
    case "(":
      string = """
      [0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 1, 0]
      """
    case ")":
      string = """
      [0, 1, 0, 0, 0],
      [0, 0, 1, 0, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 0, 0]
      """
    case "[":
      string = """
      [0, 1, 1, 1, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 1, 1, 1, 0]
      """
    case "]":
      string = """
      [0, 1, 1, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 0, 0, 1, 0],
      [0, 1, 1, 1, 0]
      """
      
      // Crash on the remaining characters.
    default:
      fatalError("Character \(character) not supported.")
    }
    
    
    var output: [UInt8] = []
    for split in string.split(separator: "\n") {
      for character in split {
        switch character {
        case "0":
          output.append(0)
        case "1":
          output.append(1)
        default:
          continue
        }
      }
    }
    if output.count == 35 {
      output += [0, 0, 0, 0, 0]
    }
    guard output.count == 40 else {
      fatalError("Unexpected pixel count: \(output.count).")
    }
    return (output, offset, spacing)
  }
}
