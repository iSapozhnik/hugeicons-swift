#!/usr/bin/env swift

import Foundation

struct NameMapPayload: Decodable {
    struct Entry: Decodable {
        let sourceName: String
        let swiftIdentifier: String
    }

    let entries: [Entry]
}

struct Summary: Encodable {
    let oldCount: Int
    let newCount: Int
    let addedCount: Int
    let removedCount: Int
    let renamedCount: Int
}

enum OutputFormat: String {
    case text
    case markdown
    case json
}

enum SummaryError: Error, CustomStringConvertible {
    case usage
    case invalidFormat(String)
    case missingNewNameMap(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: summarize_hugeicons_name_map.swift <old-name-map-path> <new-name-map-path> [--format text|markdown|json]"
        case .invalidFormat(let value):
            return "Unsupported format '\(value)'. Expected one of: text, markdown, json."
        case .missingNewNameMap(let path):
            return "New name-map file not found: \(path)"
        }
    }
}

func loadEntries(at path: String, allowMissing: Bool) throws -> [NameMapPayload.Entry] {
    if !FileManager.default.fileExists(atPath: path) {
        if allowMissing {
            return []
        }
        throw SummaryError.missingNewNameMap(path)
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(NameMapPayload.self, from: data).entries
}

func computeSummary(oldEntries: [NameMapPayload.Entry], newEntries: [NameMapPayload.Entry]) -> Summary {
    let oldByIdentifier = Dictionary(uniqueKeysWithValues: oldEntries.map { ($0.swiftIdentifier, $0.sourceName) })
    let newByIdentifier = Dictionary(uniqueKeysWithValues: newEntries.map { ($0.swiftIdentifier, $0.sourceName) })

    let oldSources = Set(oldByIdentifier.values)
    let newSources = Set(newByIdentifier.values)

    var renamedCount = 0
    var renamedOldSources = Set<String>()
    var renamedNewSources = Set<String>()

    for (identifier, oldSource) in oldByIdentifier {
        guard let newSource = newByIdentifier[identifier], newSource != oldSource else {
            continue
        }
        renamedCount += 1
        renamedOldSources.insert(oldSource)
        renamedNewSources.insert(newSource)
    }

    var addedCount = newSources.subtracting(oldSources).count
    var removedCount = oldSources.subtracting(newSources).count

    let renamedAddedOverlap = newSources.subtracting(oldSources).intersection(renamedNewSources).count
    let renamedRemovedOverlap = oldSources.subtracting(newSources).intersection(renamedOldSources).count
    addedCount = max(0, addedCount - renamedAddedOverlap)
    removedCount = max(0, removedCount - renamedRemovedOverlap)

    return Summary(
        oldCount: oldSources.count,
        newCount: newSources.count,
        addedCount: addedCount,
        removedCount: removedCount,
        renamedCount: renamedCount
    )
}

func render(_ summary: Summary, format: OutputFormat) throws -> String {
    switch format {
    case .text:
        return """
        Hugeicons refresh summary:
          old count: \(summary.oldCount)
          new count: \(summary.newCount)
          added: \(summary.addedCount)
          removed: \(summary.removedCount)
          renamed: \(summary.renamedCount)
        """
    case .markdown:
        return """
        ## Hugeicons Refresh Summary

        - Old icon count: \(summary.oldCount)
        - New icon count: \(summary.newCount)
        - Icons added: \(summary.addedCount)
        - Icons removed: \(summary.removedCount)
        - Icons renamed: \(summary.renamedCount)
        """
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(summary)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return string
    }
}

do {
    var format = OutputFormat.text
    var positional: [String] = []

    var index = 1
    while index < CommandLine.arguments.count {
        let argument = CommandLine.arguments[index]
        switch argument {
        case "--format":
            guard index + 1 < CommandLine.arguments.count else {
                throw SummaryError.usage
            }
            guard let parsedFormat = OutputFormat(rawValue: CommandLine.arguments[index + 1]) else {
                throw SummaryError.invalidFormat(CommandLine.arguments[index + 1])
            }
            format = parsedFormat
            index += 2
        default:
            positional.append(argument)
            index += 1
        }
    }

    guard positional.count == 2 else {
        throw SummaryError.usage
    }

    let oldEntries = try loadEntries(at: positional[0], allowMissing: true)
    let newEntries = try loadEntries(at: positional[1], allowMissing: false)
    let summary = computeSummary(oldEntries: oldEntries, newEntries: newEntries)
    print(try render(summary, format: format))
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
