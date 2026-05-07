import MailLib
import Nimble
import Quick

final class MimeTypeSpec: QuickSpec {
    override class func spec() {
        describe("mimeType(for:)") {
            it("returns pdf type") { expect(mimeType(for: "doc.pdf")) == "application/pdf" }
            it("returns png type") { expect(mimeType(for: "img.png")) == "image/png" }
            it("returns jpeg type for .jpg") { expect(mimeType(for: "img.jpg")) == "image/jpeg" }
            it("returns jpeg type for .jpeg") { expect(mimeType(for: "img.jpeg")) == "image/jpeg" }
            it("returns gif type") { expect(mimeType(for: "img.gif")) == "image/gif" }
            it("returns plain text type") { expect(mimeType(for: "notes.txt")) == "text/plain" }
            it("returns html type") { expect(mimeType(for: "page.html")) == "text/html" }
            it("returns zip type") { expect(mimeType(for: "archive.zip")) == "application/zip" }
            it("returns octet-stream for unknown extension") { expect(mimeType(for: "file.xyz")) == "application/octet-stream" }
            it("is case-insensitive") { expect(mimeType(for: "IMG.PNG")) == "image/png" }
            it("works with a full path") { expect(mimeType(for: "/tmp/attachments/report.pdf")) == "application/pdf" }
        }
    }
}
