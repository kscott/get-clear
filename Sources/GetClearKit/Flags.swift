import Foundation

/// Returns true if the argument is a version flag: --version, -v, or version.
public func isVersionFlag(_ s: String) -> Bool {
    s == "--version" || s == "-v" || s == "version"
}

/// Returns true if the argument is a help flag: --help, -h, or help.
public func isHelpFlag(_ s: String) -> Bool {
    s == "--help" || s == "-h" || s == "help"
}
