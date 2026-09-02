import AppleEventKitSupport
import CoreGraphics
import Testing

@Suite("rgbComponents(from:)")
struct RgbComponentsFromTests {
    @Suite("nil input")
    struct NilInput {
        @Test("returns nil")
        func returnsNil() {
            #expect(rgbComponents(from: nil) == nil)
        }
    }

    @Suite("RGB color")
    struct RGBColor {
        @Test("extracts pure red")
        func extractsPureRed() {
            let color = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
            let result = rgbComponents(from: color)
            #expect(result?.r == 255)
            #expect(result?.g == 0)
            #expect(result?.b == 0)
        }

        @Test("extracts mixed color")
        func extractsMixedColor() {
            let color = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
            let result = rgbComponents(from: color)
            #expect(result?.r == 51)
            #expect(result?.g == 102)
            #expect(result?.b == 153)
        }
    }

    @Suite("monochrome color")
    struct MonochromeColor {
        @Test("maps gray to equal R G B components")
        func mapsGrayToEqualComponents() {
            let space = CGColorSpaceCreateDeviceGray()
            let color = CGColor(colorSpace: space, components: [0.5, 1.0])
            let result = rgbComponents(from: color)
            #expect(result?.r == result?.g)
            #expect(result?.g == result?.b)
        }
    }
}

@Suite("hexColor(from:)")
struct HexColorFromTests {
    @Suite("nil input")
    struct NilInput {
        @Test("returns nil")
        func returnsNil() {
            #expect(hexColor(from: nil) == nil)
        }
    }

    @Suite("RGB color")
    struct RGBColor {
        @Test("returns uppercase hex for pure red")
        func uppercaseHexPureRed() {
            let color = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
            #expect(hexColor(from: color) == "FF0000")
        }

        @Test("returns uppercase hex for pure green")
        func uppercaseHexPureGreen() {
            let color = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
            #expect(hexColor(from: color) == "00FF00")
        }

        @Test("returns uppercase hex for pure blue")
        func uppercaseHexPureBlue() {
            let color = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
            #expect(hexColor(from: color) == "0000FF")
        }

        @Test("returns correct hex for mixed color")
        func correctHexMixedColor() {
            let color = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
            #expect(hexColor(from: color) == "336699")
        }
    }

    @Suite("monochrome color")
    struct MonochromeColor {
        @Test("returns equal R G B components for white")
        func equalComponentsForWhite() {
            let space = CGColorSpaceCreateDeviceGray()
            let color = CGColor(colorSpace: space, components: [1.0, 1.0])
            #expect(hexColor(from: color) == "FFFFFF")
        }

        @Test("returns equal R G B components for black")
        func equalComponentsForBlack() {
            let space = CGColorSpaceCreateDeviceGray()
            let color = CGColor(colorSpace: space, components: [0.0, 1.0])
            #expect(hexColor(from: color) == "000000")
        }
    }
}
