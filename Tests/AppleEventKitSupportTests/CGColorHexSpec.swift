import AppleEventKitSupport
import CoreGraphics
import Nimble
import Quick

final class CGColorHexSpec: QuickSpec {
    override class func spec() {
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
                    let components: [CGFloat] = [1.0, 1.0]
                    let color = CGColor(colorSpace: space, components: components)
                    expect(hexColor(from: color)) == "FFFFFF"
                }
                it("returns equal R G B components for black") {
                    let space = CGColorSpaceCreateDeviceGray()
                    let components: [CGFloat] = [0.0, 1.0]
                    let color = CGColor(colorSpace: space, components: components)
                    expect(hexColor(from: color)) == "000000"
                }
            }
        }
    }
}
