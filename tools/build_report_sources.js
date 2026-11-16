// 要件定義書と既存コードを report/sources.js に書き出す。
// ブラウザはファイルから開いたページで他のファイルを読めないため、レポートに内容を同梱する。
// 題材を変更したときだけ実行する。  node tools/build_report_sources.js
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");

function walk(dir) {
  return fs.readdirSync(path.join(ROOT, dir), { withFileTypes: true }).flatMap((entry) => {
    const rel = dir + "/" + entry.name;
    return entry.isDirectory() ? walk(rel) : [rel];
  });
}

function readSources() {
  const sources = {};
  ["docs/requirements.md", ...walk("legacy").sort()].forEach((rel) => {
    sources[rel] = fs.readFileSync(path.join(ROOT, rel), "utf8");
  });
  return sources;
}

function render(sources) {
  return "// tools/build_report_sources.js が生成する。手で編集しない。\n"
    + "window.REPORT_SOURCES = " + JSON.stringify(sources, null, 2) + ";\n";
}

if (require.main === module) {
  fs.writeFileSync(path.join(ROOT, "report/sources.js"), render(readSources()));
  console.log("report/sources.js を更新しました。");
}

module.exports = { ROOT, readSources, render };
