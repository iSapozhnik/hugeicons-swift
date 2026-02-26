#!/usr/bin/env swift

import Foundation

struct ManifestEntry: Codable {
    let sourceName: String
    let relativePath: String
    let sha256: String
}

struct Manifest: Codable {
    let generatedAt: String
    let iconCount: Int
    let entries: [ManifestEntry]
}

enum VerifyError: Error, CustomStringConvertible {
    case usage
    case svgRootMissing(String)
    case noIconsFound(String)
    case duplicateNames([String])
    case invalidSVG(path: String)
    case checksumFailed(path: String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: verify_hugeicons_free.swift <svg-root-dir> <manifest-output-path>"
        case .svgRootMissing(let root):
            return "SVG root directory does not exist: \(root)"
        case .noIconsFound(let root):
            return "No .svg files found under: \(root)"
        case .duplicateNames(let names):
            return "Duplicate icon base names found: \(names.joined(separator: ", "))"
        case .invalidSVG(let path):
            return "Invalid SVG XML: \(path)"
        case .checksumFailed(let path):
            return "Unable to compute checksum for: \(path)"
        }
    }
}

final class XMLValidator: NSObject, XMLParserDelegate {
    private(set) var hadError = false

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        hadError = true
    }
}

func collectSVGFiles(in root: URL) -> [URL] {
    let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )

    var files: [URL] = []
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension.lowercased() == "svg" else { continue }
        files.append(fileURL)
    }

    return files.sorted { $0.path < $1.path }
}

func validateSVG(_ url: URL) throws {
    let data = try Data(contentsOf: url)
    let parser = XMLParser(data: data)
    let validator = XMLValidator()
    parser.delegate = validator

    if !parser.parse() || validator.hadError {
        throw VerifyError.invalidSVG(path: url.path)
    }
}

func relativePath(of fileURL: URL, from root: URL) -> String {
    let rootComponents = root.standardizedFileURL.pathComponents
    let fileComponents = fileURL.standardizedFileURL.pathComponents

    guard fileComponents.starts(with: rootComponents) else {
        return fileURL.lastPathComponent
    }

    return fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
}

func sha256(_ path: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["shasum", "-a", "256", path]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let line = String(data: data, encoding: .utf8)?.split(separator: " ").first else {
            return nil
        }
        return String(line)
    } catch {
        return nil
    }
}

do {
    let args = CommandLine.arguments
    guard args.count == 3 else {
        throw VerifyError.usage
    }

    let svgRoot = URL(fileURLWithPath: args[1], isDirectory: true)
    let manifestPath = URL(fileURLWithPath: args[2])

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: svgRoot.path, isDirectory: &isDir), isDir.boolValue else {
        throw VerifyError.svgRootMissing(svgRoot.path)
    }

    let svgFiles = collectSVGFiles(in: svgRoot)
    guard !svgFiles.isEmpty else {
        throw VerifyError.noIconsFound(svgRoot.path)
    }

    let duplicateNames = Dictionary(grouping: svgFiles, by: { $0.deletingPathExtension().lastPathComponent })
        .filter { $0.value.count > 1 }
        .map(\.key)
        .sorted()
    guard duplicateNames.isEmpty else {
        throw VerifyError.duplicateNames(duplicateNames)
    }

    let manifestEntries = try svgFiles.map { fileURL in
        try validateSVG(fileURL)
        guard let checksum = sha256(fileURL.path) else {
            throw VerifyError.checksumFailed(path: fileURL.path)
        }

        let relativePath = relativePath(of: fileURL, from: svgRoot)
        let sourceName = fileURL.deletingPathExtension().lastPathComponent
        return ManifestEntry(sourceName: sourceName, relativePath: relativePath, sha256: checksum)
    }

    let manifest = Manifest(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        iconCount: manifestEntries.count,
        entries: manifestEntries.sorted { $0.relativePath < $1.relativePath }
    )

    try FileManager.default.createDirectory(at: manifestPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)
    try data.write(to: manifestPath)

    print("Verified \(manifest.iconCount) SVG files and wrote manifest to \(manifestPath.path)")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
