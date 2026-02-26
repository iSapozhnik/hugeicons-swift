#!/usr/bin/env swift

import Foundation

struct NameMapPayload: Decodable {
    struct Entry: Decodable {
        let sourceName: String
        let swiftIdentifier: String
    }

    let entryCount: Int
    let entries: [Entry]
}

enum WrapperGenerationError: Error, CustomStringConvertible {
    case usage
    case inputMissing(path: String)
    case invalidGeneratedSwift
    case duplicateGeneratedSourceName(String)
    case duplicatePublicIdentifier(String)
    case missingGeneratedSource(String)
    case invalidPublicIdentifier(String)
    case invalidNameMapCount(expected: Int, actual: Int)

    var description: String {
        switch self {
        case .usage:
            return "Usage: generate_hugeicons_wrapper.swift <name-map.json> <swiftgen-file> <output-path>"
        case .inputMissing(let path):
            return "Input file not found: \(path)"
        case .invalidGeneratedSwift:
            return "Failed to parse source icon mappings from generated SwiftGen file."
        case .duplicateGeneratedSourceName(let name):
            return "Duplicate source icon name found in generated SwiftGen file: \(name)"
        case .duplicatePublicIdentifier(let name):
            return "Duplicate public identifier in name-map: \(name)"
        case .missingGeneratedSource(let name):
            return "Name-map source '\(name)' was not found in generated SwiftGen output."
        case .invalidPublicIdentifier(let name):
            return "Invalid public identifier in name-map: \(name)"
        case .invalidNameMapCount(let expected, let actual):
            return "Name-map entryCount (\(expected)) does not match entries count (\(actual))."
        }
    }
}

func escapeSwiftString(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

func parseSwiftGenMappings(_ generatedSwift: String) throws -> [String: String] {
    let pattern = #"internal static let\s+(`?)([A-Za-z_][A-Za-z0-9_]*)\1\s*=\s*File\(name:\s*"([^"]+)""#
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let fullRange = NSRange(generatedSwift.startIndex..<generatedSwift.endIndex, in: generatedSwift)
    let matches = regex.matches(in: generatedSwift, options: [], range: fullRange)

    guard !matches.isEmpty else {
        throw WrapperGenerationError.invalidGeneratedSwift
    }

    var sourceToGeneratedIdentifier: [String: String] = [:]
    for match in matches {
        guard
            let identifierRange = Range(match.range(at: 2), in: generatedSwift),
            let sourceNameRange = Range(match.range(at: 3), in: generatedSwift)
        else {
            continue
        }

        let identifier = String(generatedSwift[identifierRange])
        let sourceName = String(generatedSwift[sourceNameRange])
        if sourceToGeneratedIdentifier[sourceName] != nil {
            throw WrapperGenerationError.duplicateGeneratedSourceName(sourceName)
        }
        sourceToGeneratedIdentifier[sourceName] = identifier
    }

    return sourceToGeneratedIdentifier
}

func isValidSwiftIdentifier(_ value: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: #"^[A-Za-z_][A-Za-z0-9_]*$"#) else {
        return false
    }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.firstMatch(in: value, options: [], range: range) != nil
}

do {
    guard CommandLine.arguments.count == 4 else {
        throw WrapperGenerationError.usage
    }

    let nameMapPath = CommandLine.arguments[1]
    let swiftGenPath = CommandLine.arguments[2]
    let outputPath = CommandLine.arguments[3]

    guard FileManager.default.fileExists(atPath: nameMapPath) else {
        throw WrapperGenerationError.inputMissing(path: nameMapPath)
    }
    guard FileManager.default.fileExists(atPath: swiftGenPath) else {
        throw WrapperGenerationError.inputMissing(path: swiftGenPath)
    }

    let nameMapData = try Data(contentsOf: URL(fileURLWithPath: nameMapPath))
    let nameMap = try JSONDecoder().decode(NameMapPayload.self, from: nameMapData)
    let generatedSwift = try String(contentsOfFile: swiftGenPath, encoding: .utf8)
    let sourceToGeneratedIdentifier = try parseSwiftGenMappings(generatedSwift)

    guard nameMap.entryCount == nameMap.entries.count else {
        throw WrapperGenerationError.invalidNameMapCount(expected: nameMap.entryCount, actual: nameMap.entries.count)
    }

    var seenPublicIdentifiers = Set<String>()
    let sortedEntries = nameMap.entries.sorted { $0.swiftIdentifier < $1.swiftIdentifier }

    for entry in sortedEntries {
        guard isValidSwiftIdentifier(entry.swiftIdentifier) else {
            throw WrapperGenerationError.invalidPublicIdentifier(entry.swiftIdentifier)
        }

        if !seenPublicIdentifiers.insert(entry.swiftIdentifier).inserted {
            throw WrapperGenerationError.duplicatePublicIdentifier(entry.swiftIdentifier)
        }

        if sourceToGeneratedIdentifier[entry.sourceName] == nil {
            throw WrapperGenerationError.missingGeneratedSource(entry.sourceName)
        }
    }

    var lines: [String] = []
    lines.append("// swiftlint:disable all")
    lines.append("// Generated by Scripts/icons/generate_hugeicons_wrapper.swift")
    lines.append("// DO NOT EDIT.")
    lines.append("")
    lines.append("import Foundation")
    lines.append("")
    lines.append("public extension Hugeicons {")
    for entry in sortedEntries {
        lines.append("    static var \(entry.swiftIdentifier): HugeiconsAsset {")
        lines.append("        HugeiconsCatalog.\(entry.swiftIdentifier)")
        lines.append("    }")
    }
    lines.append("}")
    lines.append("")
    lines.append("enum HugeiconsCatalog {")
    for entry in sortedEntries {
        let generatedIdentifier = sourceToGeneratedIdentifier[entry.sourceName]!
        lines.append("    static let \(entry.swiftIdentifier) = HugeiconsAsset(")
        lines.append("        sourceName: \"\(escapeSwiftString(entry.sourceName))\",")
        lines.append("        swiftIdentifier: \"\(escapeSwiftString(entry.swiftIdentifier))\",")
        lines.append("        resourceName: HugeiconsGenerated.`\(generatedIdentifier)`.name")
        lines.append("    )")
    }
    lines.append("")
    lines.append("    static let all: [HugeiconsAsset] = [")
    for (index, entry) in sortedEntries.enumerated() {
        let suffix = index == sortedEntries.count - 1 ? "" : ","
        lines.append("        \(entry.swiftIdentifier)\(suffix)")
    }
    lines.append("    ]")
    lines.append("}")
    lines.append("")
    lines.append("// swiftlint:enable all")

    let outputURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let output = lines.joined(separator: "\n")
    try output.write(to: outputURL, atomically: true, encoding: .utf8)

    print("Generated wrapper catalog for \(sortedEntries.count) icons at \(outputPath)")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
