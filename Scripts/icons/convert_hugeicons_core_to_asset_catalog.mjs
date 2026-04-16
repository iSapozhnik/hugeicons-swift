#!/usr/bin/env node

import fs from "node:fs/promises";
import fssync from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import PDFDocument from "pdfkit";
import SVGtoPDF from "svg-to-pdfkit";

const ALLOWED_TAGS = new Set(["path", "circle", "ellipse", "rect"]);
const ICON_SIZE = 24;

function usage() {
  return [
    "Usage: convert_hugeicons_core_to_asset_catalog.mjs \\",
    "  --esm-dir <path> \\",
    "  --output-dir <path> \\",
    "  --source-package <name> \\",
    "  --source-version <version> \\",
    "  --report-path <path>",
    "",
    "Converts @hugeicons/core-free-icons dist/esm/*Icon.js modules into",
    "Hugeicons.xcassets/<icon>.imageset/{<icon>.pdf,Contents.json}.",
  ].join("\n");
}

function parseArgs(argv) {
  const out = new Map();

  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith("--")) throw new Error(`Unexpected argument: ${key}`);
    const value = argv[i + 1];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for ${key}`);
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
    if (!out.has(key)) throw new Error(`Missing required option: ${key}`);
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
  if (attributeName === "xlinkHref") return "xlink:href";
  return attributeName.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
}

function normalizeAttrValue(name, value) {
  if (value === null || value === undefined) return value;

  // For template/vector assets, black is the safest default instead of currentColor.
  if (
    (name === "stroke" || name === "fill") &&
    (value === "currentColor" || value === "currentcolor")
  ) {
    return "#000000";
  }

  return value;
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

    const normalizedAttrs = {};
    for (const [name, value] of Object.entries(attrs)) {
      if (name === "key") continue;
      const normalizedValue = normalizeAttrValue(name, value);
      if (normalizedValue !== null && normalizedValue !== undefined) {
        normalizedAttrs[name] = normalizedValue;
      }
    }

    return { tag, attrs: normalizedAttrs };
  });
}

function nodeToSVGString(node) {
  const attrs = Object.entries(node.attrs)
    .map(([name, value]) => `${toSVGAttributeName(name)}="${escapeXML(value)}"`)
    .join(" ");

  return attrs.length === 0 ? `<${node.tag} />` : `<${node.tag} ${attrs} />`;
}

function buildSVG(nodes) {
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${ICON_SIZE}" height="${ICON_SIZE}" viewBox="0 0 ${ICON_SIZE} ${ICON_SIZE}" fill="none">`,
    ...nodes.map(nodeToSVGString),
    `</svg>`,
    "",
  ].join("\n");
}

async function writeJSON(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function writePDF(svg, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });

  await new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: [ICON_SIZE, ICON_SIZE],
      margin: 0,
      autoFirstPage: true,
      compress: true,
      info: {
        Title: path.basename(outputPath),
        Producer: "hugeicons-swift pipeline",
      },
    });

    const stream = fssync.createWriteStream(outputPath);
    stream.on("finish", resolve);
    stream.on("error", reject);
    doc.on("error", reject);

    doc.pipe(stream);

    SVGtoPDF(doc, svg, 0, 0, {
      width: ICON_SIZE,
      height: ICON_SIZE,
      preserveAspectRatio: "xMidYMid meet",
      assumePt: true,
    });

    doc.end();
  });
}

function assetCatalogContentsJSON() {
  return {
    info: {
      author: "xcode",
      version: 1,
    },
  };
}

function imageSetContentsJSON(pdfFileName) {
  return {
    images: [
      {
        idiom: "universal",
        filename: pdfFileName,
      },
    ],
    info: {
      author: "xcode",
      version: 1,
    },
    properties: {
      "preserves-vector-representation": true,
      "template-rendering-intent": "template"
    },
  };
}

async function run() {
  const args = parseArgs(process.argv.slice(2));

  const report = {
    sourcePackage: args.sourcePackage,
    sourceVersion: args.sourceVersion,
    generatedAt: new Date().toISOString(),
    outputKind: "xcassets-pdf",
    moduleCount: 0,
    convertedCount: 0,
    skippedCount: 0,
    skipped: [],
  };

  await fs.mkdir(args.outputDir, { recursive: true });
  await writeJSON(
    path.join(args.outputDir, "Contents.json"),
    assetCatalogContentsJSON(),
  );
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

      const iconName = toKebabCaseIconName(moduleName);
      if (usedOutputNames.has(iconName)) {
        throw new Error(`output filename collision for ${iconName}`);
      }
      usedOutputNames.add(iconName);

      const svg = buildSVG(nodes);
      const imagesetDir = path.join(args.outputDir, `${iconName}.imageset`);
      const pdfFileName = `${iconName}.pdf`;
      const pdfPath = path.join(imagesetDir, pdfFileName);
      const contentsJSONPath = path.join(imagesetDir, "Contents.json");

      await writePDF(svg, pdfPath);
      await writeJSON(contentsJSONPath, imageSetContentsJSON(pdfFileName));

      report.convertedCount += 1;
    } catch (error) {
      const reason = error instanceof Error ? error.stack ?? error.message : String(error);
      report.skipped.push({ module: moduleName, reason });
      console.warn(`[hugeicons-convert] skipped ${moduleName}: ${reason}`);
    }
  }

  report.skippedCount = report.skipped.length;
  await writeJSON(args.reportPath, report);

  console.log(
    `[hugeicons-convert] modules=${report.moduleCount} converted=${report.convertedCount} skipped=${report.skippedCount}`,
  );
  console.log(`[hugeicons-convert] output=${args.outputDir}`);
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
