#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const ALLOWED_TAGS = new Set(["path", "circle", "ellipse", "rect"]);
const SVG_ROOT_OPEN =
  '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">';
const SVG_ROOT_CLOSE = "</svg>";

function usage() {
  return [
    "Usage: convert_hugeicons_core_to_svg.mjs --esm-dir <path> --output-dir <path> --source-package <name> --source-version <version> --report-path <path>",
    "",
    "Converts @hugeicons/core-free-icons dist/esm/*Icon.js modules into raw SVG files.",
  ].join("\n");
}

function parseArgs(argv) {
  const out = new Map();

  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith("--")) {
      throw new Error(`Unexpected argument: ${key}`);
    }

    const value = argv[i + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for ${key}`);
    }

    out.set(key, value);
    i += 1;
  }

  const required = [
    "--esm-dir",
    "--output-dir",
    "--source-package",
    "--source-version",
    "--report-path",
  ];

  for (const key of required) {
    if (!out.has(key)) {
      throw new Error(`Missing required option: ${key}`);
    }
  }

  return {
    esmDir: out.get("--esm-dir"),
    outputDir: out.get("--output-dir"),
    sourcePackage: out.get("--source-package"),
    sourceVersion: out.get("--source-version"),
    reportPath: out.get("--report-path"),
  };
}

function toKebabCaseIconName(moduleFileName) {
  const moduleBaseName = moduleFileName.replace(/\.js$/, "");
  const iconBaseName = moduleBaseName.replace(/Icon$/, "");

  return iconBaseName
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/([A-Z])([A-Z][a-z])/g, "$1-$2")
    .toLowerCase();
}

function escapeXML(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function toSVGAttributeName(attributeName) {
  if (attributeName === "xlinkHref") {
    return "xlink:href";
  }

  return attributeName.replace(/[A-Z]/g, (match) => `-${match.toLowerCase()}`);
}

function validateAndNormalizeIconNodes(iconNodes) {
  if (!Array.isArray(iconNodes)) {
    throw new Error("default export is not an array");
  }

  return iconNodes.map((node, index) => {
    if (!Array.isArray(node) || node.length < 2) {
      throw new Error(`node ${index} has invalid shape`);
    }

    const [tag, attrs] = node;
    if (typeof tag !== "string" || !ALLOWED_TAGS.has(tag)) {
      throw new Error(`node ${index} has unsupported tag '${String(tag)}'`);
    }

    if (attrs === null || typeof attrs !== "object" || Array.isArray(attrs)) {
      throw new Error(`node ${index} has invalid attrs payload`);
    }

    return { tag, attrs };
  });
}

function nodeToSVGString(node) {
  const attrs = Object.entries(node.attrs)
    .filter(([name, value]) => name !== "key" && value !== null && value !== undefined)
    .map(([name, value]) => `${toSVGAttributeName(name)}="${escapeXML(value)}"`)
    .join(" ");

  if (attrs.length === 0) {
    return `<${node.tag} />`;
  }

  return `<${node.tag} ${attrs} />`;
}

function buildSVG(nodes) {
  return `${SVG_ROOT_OPEN}\n${nodes.map(nodeToSVGString).join("\n")}\n${SVG_ROOT_CLOSE}\n`;
}

async function run() {
  const args = parseArgs(process.argv.slice(2));

  const report = {
    sourcePackage: args.sourcePackage,
    sourceVersion: args.sourceVersion,
    generatedAt: new Date().toISOString(),
    moduleCount: 0,
    convertedCount: 0,
    skippedCount: 0,
    skipped: [],
  };

  await fs.mkdir(args.outputDir, { recursive: true });
  await fs.mkdir(path.dirname(args.reportPath), { recursive: true });

  const directoryEntries = await fs.readdir(args.esmDir, { withFileTypes: true });
  const iconModules = directoryEntries
    .filter((entry) => entry.isFile() && entry.name.endsWith("Icon.js"))
    .map((entry) => entry.name)
    .sort();

  report.moduleCount = iconModules.length;

  const usedOutputNames = new Set();

  for (const moduleName of iconModules) {
    try {
      const modulePath = path.join(args.esmDir, moduleName);
      const moduleURL = pathToFileURL(modulePath).href;
      const loadedModule = await import(moduleURL);
      const nodes = validateAndNormalizeIconNodes(loadedModule.default);
      const outputName = `${toKebabCaseIconName(moduleName)}.svg`;

      if (usedOutputNames.has(outputName)) {
        throw new Error(`output filename collision for ${outputName}`);
      }
      usedOutputNames.add(outputName);

      const svg = buildSVG(nodes);
      await fs.writeFile(path.join(args.outputDir, outputName), svg, "utf8");
      report.convertedCount += 1;
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      report.skipped.push({
        module: moduleName,
        reason,
      });
      console.warn(`[hugeicons-convert] skipped ${moduleName}: ${reason}`);
    }
  }

  report.skippedCount = report.skipped.length;
  await fs.writeFile(args.reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");

  console.log(
    `[hugeicons-convert] modules=${report.moduleCount} converted=${report.convertedCount} skipped=${report.skippedCount}`
  );
  console.log(`[hugeicons-convert] report=${args.reportPath}`);
}

if (process.argv.includes("-h") || process.argv.includes("--help")) {
  console.log(usage());
  process.exit(0);
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  console.error(usage());
  process.exit(1);
});
