import AppleEventKitSupport
import CoreGraphics
import Nimble
import Quick

final class CGColorHexSpec: QuickSpec {
    override class func spec() {
        describe("rgbComponents(from:)") {
            context("nil input") {
                it("returns nil") {
                    expect(rgbComponents(from: nil)).to(beNil())
                }
            }

            context("RGB color") {
                it("extracts pure red") {
                    let color = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
                    let result = rgbComponents(from: color)
                    expect(result?.r) == 255
                    expect(result?.g) == 0
                    expect(result?.b) == 0
                }
                it("extracts mixed color") {
                    let color = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
                    let result = rgbComponents(from: color)
                    expect(result?.r) == 51
                    expect(result?.g) == 102
                    expect(result?.b) == 153
                }
            }

            context("monochrome color") {
                it("maps gray to equal R G B components") {
                    let space = CGColorSpaceCreateDeviceGray()
                    let color = CGColor(colorSpace: space, components: [0.5, 1.0])
                    let result = rgbComponents(from: color)
                    expect(result?.r) == result?.g
                    expect(result?.g) == result?.b
                }
            }
        }

        describe("hexColor(from:)") {
            context("nil input") {
                it("returns nil") {
                    expect(hexColor(from: nil)).to(beNil())
                }
            }

            context("RGB color") {
                it("returns uppercase hex for pure red") {
                    let color = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
                    expect(hexColor(from: color)) == "FF0000"
                }
                it("returns uppercase hex for pure green") {
                    let color = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
                    expect(hexColor(from: color)) == "00FF00"
                }
                it("returns uppercase hex for pure blue") {
                    let color = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
                    expect(hexColor(from: color)) == "0000FF"
                }
                it("returns correct hex for mixed color") {
                    let color = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
                    expect(hexColor(from: color)) == "336699"
                }
            }

            context("monochrome color") {
                it("returns equal R G B components for white") {
                    let space = CGColorSpaceCreateDeviceGray()
                    let color = CGColor(colorSpace: space, components: [1.0, 1.0])
                    expect(hexColor(from: color)) == "FFFFFF"
                }
                it("returns equal R G B components for black") {
                    let space = CGColorSpaceCreateDeviceGray()
                    let color = CGColor(colorSpace: space, components: [0.0, 1.0])
                    expect(hexColor(from: color)) == "000000"
                }
            }
        }
    }
}
