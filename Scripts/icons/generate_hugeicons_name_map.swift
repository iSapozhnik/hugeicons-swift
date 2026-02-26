#!/usr/bin/env swift

import Foundation

enum NameMapError: Error, CustomStringConvertible {
    case usage
    case svgRootMissing(String)
    case noIconsFound(String)
    case nameCollision(identifier: String, first: String, second: String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: generate_hugeicons_name_map.swift <svg-root-dir> <name-map-output-path>"
        case .svgRootMissing(let root):
            return "SVG root directory does not exist: \(root)"
        case .noIconsFound(let root):
            return "No .svg files found under: \(root)"
        case .nameCollision(let id, let first, let second):
            return "Swift identifier collision for '\(id)': \(first) and \(second)"
        }
    }
}

struct NameMapPayload: Codable {
    struct Entry: Codable {
        let sourceName: String
        let swiftIdentifier: String
    }

    let generatedAt: String
    let entryCount: Int
    let entries: [Entry]
}

let swiftKeywords: Set<String> = [
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init",
    "inout", "internal", "let", "open", "operator", "private", "protocol", "public", "rethrows",
    "static", "struct", "subscript", "typealias", "var", "break", "case", "continue", "default",
    "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch",
    "where", "while", "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self", "throw",
    "throws", "true", "try", "await", "actor"
]

func toSwiftIdentifier(_ source: String) -> String {
    let tokens = source
        .split(separator: "-")
        .map { token in
            token.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map(String.init)
                .joined()
        }
        .filter { !$0.isEmpty }

    guard let first = tokens.first?.lowercased() else {
        return "icon"
    }

    let rest = tokens.dropFirst().map { token -> String in
        let lower = token.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    var combined = ([first] + rest).joined()

    if let firstChar = combined.first, firstChar.isNumber {
        combined = "icon" + firstChar.uppercased() + combined.dropFirst()
    }

    if swiftKeywords.contains(combined) {
        combined += "Icon"
    }

    return combined
}

func collectSVGBaseNames(root: URL) throws -> [String] {
    let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )

    var names: [String] = []
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension.lowercased() == "svg" else { continue }
        names.append(fileURL.deletingPathExtension().lastPathComponent)
    }

    return names.sorted()
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw NameMapError.usage
    }

    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let output = URL(fileURLWithPath: CommandLine.arguments[2])

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
        throw NameMapError.svgRootMissing(root.path)
    }

    let baseNames = try collectSVGBaseNames(root: root)
    guard !baseNames.isEmpty else {
        throw NameMapError.noIconsFound(root.path)
    }

    var identifierSource: [String: String] = [:]
    var entries: [NameMapPayload.Entry] = []

    for name in baseNames {
        let identifier = toSwiftIdentifier(name)
        if let first = identifierSource[identifier] {
            throw NameMapError.nameCollision(identifier: identifier, first: first, second: name)
        }

        identifierSource[identifier] = name
        entries.append(.init(sourceName: name, swiftIdentifier: identifier))
    }

    let payload = NameMapPayload(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        entryCount: entries.count,
        entries: entries.sorted { $0.sourceName < $1.sourceName }
    )

    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(payload)
    try data.write(to: output)

    print("Generated \(payload.entryCount) stable name mappings at \(output.path)")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
