// 指摘のJSONをコマンドラインで確かめる。レポートの画面と同じ処理を使う。
// 参加者のワークには不要で、Node.js がある人だけ使える。
//   node tools/check_findings.js [findings/findings.json]
const fs = require("fs");
const path = require("path");
const { checkFindings } = require("../report/check.js");
const { ROOT, readSources, render } = require("./build_report_sources.js");

const file = process.argv[2] || path.join(ROOT, "findings/findings.json");
let findings;
try {
  findings = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (e) {
  console.error("読み込めませんでした: " + e.message);
  process.exit(1);
}

const sources = readSources();
const result = checkFindings(findings, sources);
if (result.fatal) {
  console.error(result.fatal);
  process.exit(1);
}
result.errors.forEach((x) => console.log("不合格 " + x.id + ": " + x.message));
result.warnings.forEach((x) => console.log("注意   " + x.id + ": " + x.message));

const bundled = path.join(ROOT, "report/sources.js");
const stale = !fs.existsSync(bundled) || fs.readFileSync(bundled, "utf8") !== render(sources);
if (stale) console.log("注意   report/sources.js が題材と一致しません。node tools/build_report_sources.js を実行してください。");

console.log(result.count + "件 / 不合格 " + result.errors.length + " / 注意 " + result.warnings.length);
console.log("形式と参照先だけを確かめました。指摘の内容が正しいかは判定していません。");
process.exit(result.errors.length ? 1 : 0);
