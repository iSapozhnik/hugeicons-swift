#!/usr/bin/env swift

import Foundation

enum VerifyError: Error, CustomStringConvertible {
    case usage
    case invalidMaxSkipped(String)
    case xcassetsRootMissing(String)

    var description: String {
        switch self {
        case .usage:
            return """
            Usage: verify_hugeicons_xcassets.swift <xcassets-root-dir> [--report-path <path>] [--max-skipped <count>]
            """
        case .invalidMaxSkipped(let value):
            return "Invalid --max-skipped value: \(value)"
        case .xcassetsRootMissing(let path):
            return "Asset catalog root does not exist: \(path)"
        }
    }
}

struct AssetCatalogContents: Decodable {
    struct Info: Decodable {
        let author: String
        let version: Int
    }

    let info: Info
}

struct ImageSetContents: Decodable {
    struct ImageEntry: Decodable {
        let idiom: String?
        let filename: String?
    }

    struct Properties: Decodable {
        let preservesVectorRepresentation: Bool?
        let templateRenderingIntent: String?

        enum CodingKeys: String, CodingKey {
            case preservesVectorRepresentation = "preserves-vector-representation"
            case templateRenderingIntent = "template-rendering-intent"
        }
    }

    let images: [ImageEntry]
    let properties: Properties?
}

struct ConversionReport: Decodable {
    struct SkippedEntry: Decodable {
        let module: String
        let reason: String
    }

    let outputKind: String?
    let moduleCount: Int
    let convertedCount: Int
    let skippedCount: Int
    let skipped: [SkippedEntry]?
}

struct Config {
    let rootPath: String
    let reportPath: String
    let maxSkipped: Int
}

func parseArgs() throws -> Config {
    let args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else { throw VerifyError.usage }

    if args.contains("-h") || args.contains("--help") {
        throw VerifyError.usage
    }

    let rootPath = args[0]
    var reportPath: String?
    var maxSkipped = 0

    var index = 1
    while index < args.count {
        let flag = args[index]
        switch flag {
        case "--report-path":
            guard index + 1 < args.count else { throw VerifyError.usage }
            reportPath = args[index + 1]
            index += 2
        case "--max-skipped":
            guard index + 1 < args.count else { throw VerifyError.usage }
            guard let parsed = Int(args[index + 1]), parsed >= 0 else {
                throw VerifyError.invalidMaxSkipped(args[index + 1])
            }
            maxSkipped = parsed
            index += 2
        default:
            throw VerifyError.usage
        }
    }

    let defaultReportPath = URL(fileURLWithPath: rootPath, isDirectory: true)
        .appendingPathComponent("conversion-report.json")
        .path

    return Config(
        rootPath: rootPath,
        reportPath: reportPath ?? defaultReportPath,
        maxSkipped: maxSkipped
    )
}

func decodeJSON<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

func collectImageSetDirectories(root: URL) -> [URL] {
    let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )

    var imageSetDirs: [URL] = []
    while let item = enumerator?.nextObject() as? URL {
        guard item.hasDirectoryPath, item.pathExtension == "imageset" else { continue }
        imageSetDirs.append(item)
    }
    return imageSetDirs.sorted { $0.path < $1.path }
}

func validateCatalog(root: URL, reportURL: URL, maxSkipped: Int) -> [String] {
    var failures: [String] = []

    let rootContentsURL = root.appendingPathComponent("Contents.json")
    if !FileManager.default.fileExists(atPath: rootContentsURL.path) {
        failures.append("Missing root Contents.json at \(rootContentsURL.path)")
    } else {
        do {
            let rootContents = try decodeJSON(AssetCatalogContents.self, at: rootContentsURL)
            if rootContents.info.author != "xcode" {
                failures.append("Root Contents.json author should be 'xcode', got '\(rootContents.info.author)'")
            }
            if rootContents.info.version != 1 {
                failures.append("Root Contents.json version should be 1, got \(rootContents.info.version)")
            }
        } catch {
            failures.append("Failed to parse root Contents.json: \(error)")
        }
    }

    let imageSetDirs = collectImageSetDirectories(root: root)
    if imageSetDirs.isEmpty {
        failures.append("No .imageset directories found under \(root.path)")
    }

    var seenNames: [String: String] = [:]

    for imageSetDir in imageSetDirs {
        let imageSetName = imageSetDir.deletingPathExtension().lastPathComponent
        let normalizedName = imageSetName.lowercased()
        if let first = seenNames[normalizedName] {
            failures.append("Duplicate asset name collision (case-insensitive): '\(first)' and '\(imageSetName)'")
        } else {
            seenNames[normalizedName] = imageSetName
        }

        let contentsURL = imageSetDir.appendingPathComponent("Contents.json")
        if !FileManager.default.fileExists(atPath: contentsURL.path) {
            failures.append("Missing Contents.json for \(imageSetName)")
            continue
        }

        let imageSetContents: ImageSetContents
        do {
            imageSetContents = try decodeJSON(ImageSetContents.self, at: contentsURL)
        } catch {
            failures.append("Failed to parse \(contentsURL.path): \(error)")
            continue
        }

        if imageSetContents.properties?.preservesVectorRepresentation != true {
            failures.append("\(imageSetName): properties.preserves-vector-representation must be true")
        }

        if imageSetContents.properties?.templateRenderingIntent != "template" {
            failures.append("\(imageSetName): properties.template-rendering-intent must be 'template'")
        }

        let universalImages = imageSetContents.images.filter { $0.idiom == "universal" }
        if universalImages.count != 1 {
            failures.append("\(imageSetName): expected exactly one universal image entry, got \(universalImages.count)")
            continue
        }

        guard let fileName = universalImages[0].filename, !fileName.isEmpty else {
            failures.append("\(imageSetName): universal image entry is missing filename")
            continue
        }

        if fileName.contains("/") || fileName.contains("\\") {
            failures.append("\(imageSetName): filename must not include path separators (\(fileName))")
        }

        if URL(fileURLWithPath: fileName).pathExtension.lowercased() != "pdf" {
            failures.append("\(imageSetName): universal filename must be a .pdf, got \(fileName)")
        }

        let referencedPDF = imageSetDir.appendingPathComponent(fileName)
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: referencedPDF.path, isDirectory: &isDirectory) || isDirectory.boolValue {
            failures.append("\(imageSetName): referenced PDF missing at \(referencedPDF.path)")
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: imageSetDir, includingPropertiesForKeys: nil)
            let pdfFiles = files.filter { $0.pathExtension.lowercased() == "pdf" }
            if pdfFiles.count != 1 {
                failures.append("\(imageSetName): expected exactly one PDF file in imageset, found \(pdfFiles.count)")
            }
        } catch {
            failures.append("Failed to list files in \(imageSetDir.path): \(error)")
        }
    }

    if !FileManager.default.fileExists(atPath: reportURL.path) {
        failures.append("Missing conversion report at \(reportURL.path)")
        return failures
    }

    do {
        let report = try decodeJSON(ConversionReport.self, at: reportURL)
        if report.outputKind != "xcassets-pdf" {
            failures.append("conversion-report outputKind must be 'xcassets-pdf', got '\(report.outputKind ?? "nil")'")
        }
        if report.convertedCount != imageSetDirs.count {
            failures.append("conversion-report convertedCount (\(report.convertedCount)) does not match imageset count (\(imageSetDirs.count))")
        }
        if report.moduleCount < report.convertedCount {
            failures.append("conversion-report moduleCount (\(report.moduleCount)) is less than convertedCount (\(report.convertedCount))")
        }
        if report.skippedCount != (report.skipped?.count ?? 0) {
            failures.append("conversion-report skippedCount (\(report.skippedCount)) does not match skipped entries (\(report.skipped?.count ?? 0))")
        }
        if report.skippedCount > maxSkipped {
            failures.append("conversion-report skippedCount (\(report.skippedCount)) exceeds allowed max (\(maxSkipped))")
        }
    } catch {
        failures.append("Failed to parse conversion report at \(reportURL.path): \(error)")
    }

    return failures
}

do {
    let config = try parseArgs()
    let rootURL = URL(fileURLWithPath: config.rootPath, isDirectory: true)
    let reportURL = URL(fileURLWithPath: config.reportPath)

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw VerifyError.xcassetsRootMissing(rootURL.path)
    }

    let failures = validateCatalog(root: rootURL, reportURL: reportURL, maxSkipped: config.maxSkipped)
    if !failures.isEmpty {
        fputs("Asset catalog verification failed with \(failures.count) issue(s):\n", stderr)
        for failure in failures {
            fputs("- \(failure)\n", stderr)
        }
        exit(1)
    }

    let imageSetCount = collectImageSetDirectories(root: rootURL).count
    print("Asset catalog verification passed: \(imageSetCount) imagesets verified in \(rootURL.path)")
    print("Conversion report: \(reportURL.path) (max skipped: \(config.maxSkipped))")
} catch VerifyError.usage {
    print(VerifyError.usage.description)
    exit(0)
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
