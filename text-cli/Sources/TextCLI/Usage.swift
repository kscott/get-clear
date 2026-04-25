// Usage.swift
// Assembles the full usage string (identity + command reference) for text-bin.

import TextLib

func usage() -> String {
    "\(identity)\n\n\(usageText())"
}
