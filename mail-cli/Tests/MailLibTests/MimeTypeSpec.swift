import MailLib
import Testing

@Suite("mimeType(for:)")
struct MimeTypeTests {
    @Test("returns pdf type") func pdf() {
        #expect(mimeType(for: "doc.pdf") == "application/pdf")
    }

    @Test("returns png type") func png() {
        #expect(mimeType(for: "img.png") == "image/png")
    }

    @Test("returns jpeg type for .jpg") func jpg() {
        #expect(mimeType(for: "img.jpg") == "image/jpeg")
    }

    @Test("returns jpeg type for .jpeg") func jpeg() {
        #expect(mimeType(for: "img.jpeg") == "image/jpeg")
    }

    @Test("returns gif type") func gif() {
        #expect(mimeType(for: "img.gif") == "image/gif")
    }

    @Test("returns plain text type") func txt() {
        #expect(mimeType(for: "notes.txt") == "text/plain")
    }

    @Test("returns html type") func html() {
        #expect(mimeType(for: "page.html") == "text/html")
    }

    @Test("returns zip type") func zip() {
        #expect(mimeType(for: "archive.zip") == "application/zip")
    }

    @Test("returns octet-stream for unknown extension") func unknown() {
        #expect(mimeType(for: "file.xyz") == "application/octet-stream")
    }

    @Test("is case-insensitive") func caseInsensitive() {
        #expect(mimeType(for: "IMG.PNG") == "image/png")
    }

    @Test("works with a full path") func fullPath() {
        #expect(mimeType(for: "/tmp/attachments/report.pdf") == "application/pdf")
    }
}
