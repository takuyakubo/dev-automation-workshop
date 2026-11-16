// 指摘のJSONを、AIを使わずに機械で確かめる。
// 確かめるのは形式と参照先だけで、指摘の内容が正しいかは判定しない。
// ブラウザ（report/index.html）とコマンドライン（tools/check_findings.js）で同じ処理を使う。
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.FindingsCheck = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const REQUIREMENTS_PATH = "docs/requirements.md";
  const ENUMS = {
    classification: ["誤り", "矛盾", "未定義"],
    area: ["業務ロジック", "営業依存", "基盤・移行・文書"],
    severity: ["高", "中", "低"],
  };
  const REQUIRED_TEXT = ["title", "evidence", "migration_impact"];
  const NULLABLE_TEXT = ["requirement_ref", "code_ref", "external_basis"];

  // 要件定義書の節（## と ###）を { "3.2": { title, level, text } } にする
  function parseSections(markdown) {
    const lines = markdown.split(/\r?\n/);
    const heads = [];
    lines.forEach((line, i) => {
      const m = line.match(/^(#{2,3})\s+(\d+(?:\.\d+)?)\.?\s*(.*)$/);
      if (m) heads.push({ index: i, level: m[1].length, number: m[2], title: m[3] });
    });
    const sections = {};
    heads.forEach((head, h) => {
      const next = heads.slice(h + 1).find((other) => other.level <= head.level);
      const end = next ? next.index : lines.length;
      sections[head.number] = {
        number: head.number,
        title: head.title,
        line: head.index + 1,
        end: end,
        text: lines.slice(head.index, end).join("\n").trim(),
      };
    });
    return sections;
  }

  // "docs/requirements.md §1, §3.2" → { path, numbers: ["1", "3.2"] }
  function parseRequirementRef(ref) {
    return {
      path: (ref.match(/^[^\s§（(,、]+/) || [""])[0],
      numbers: [...ref.matchAll(/§\s*(\d+(?:\.\d+)?)/g)].map((m) => m[1]),
    };
  }

  // "legacy/A.cbl:10, 12-14, legacy/B.cbl:3" → [{ path, from, to }, ...]
  // 行番号のない参照は from を null にする
  function parseCodeRef(ref) {
    const parts = [];
    let current = "";
    ref.split(/[,、]/).forEach((raw) => {
      const piece = raw.trim().replace(/（.*$|\(.*$/, "").trim();
      if (!piece) return;
      const withPath = piece.match(/^([^:\s]+):(\d+)(?:\s*[-–~〜]\s*(\d+))?$/);
      const lineOnly = piece.match(/^(\d+)(?:\s*[-–~〜]\s*(\d+))?$/);
      if (withPath) {
        current = withPath[1];
        parts.push({ path: current, from: +withPath[2], to: +(withPath[3] || withPath[2]) });
      } else if (lineOnly && current) {
        parts.push({ path: current, from: +lineOnly[1], to: +(lineOnly[2] || lineOnly[1]) });
      } else {
        parts.push({ path: piece, from: null, to: null });
      }
    });
    return parts;
  }

  function lineCount(text) {
    const lines = text.split(/\r?\n/);
    if (lines[lines.length - 1] === "") lines.pop();
    return lines.length;
  }

  // sources: { "相対パス": "ファイルの内容" }
  function checkFindings(findings, sources) {
    const errors = [];
    const warnings = [];
    if (!Array.isArray(findings)) {
      return { fatal: "JSONの最上位が配列ではありません。", errors, warnings, count: 0 };
    }
    const sections = parseSections(sources[REQUIREMENTS_PATH] || "");
    const seen = new Set();

    findings.forEach((f, i) => {
      const id = f && typeof f.id === "string" ? f.id : "(" + (i + 1) + "件目)";
      const err = (message) => errors.push({ id, message });
      const warn = (message) => warnings.push({ id, message });

      if (!f || typeof f !== "object" || Array.isArray(f)) return err("オブジェクトではありません。");

      if (typeof f.id !== "string" || !/^F-\d{3,}$/.test(f.id)) err("id が F-001 の形式ではありません。");
      else if (seen.has(f.id)) err("id が重複しています。");
      else seen.add(f.id);

      Object.keys(ENUMS).forEach((key) => {
        if (!(key in f)) err(key + " がありません。");
        else if (!ENUMS[key].includes(f[key])) err(key + " の値「" + f[key] + "」は選択肢にありません。");
      });
      REQUIRED_TEXT.forEach((key) => {
        if (typeof f[key] !== "string" || !f[key].trim()) err(key + " が空です。");
      });
      NULLABLE_TEXT.forEach((key) => {
        if (!(key in f)) err(key + " がありません（該当がなければ null）。");
        else if (f[key] !== null && typeof f[key] !== "string") err(key + " は文字列か null にしてください。");
      });

      if (typeof f.requirement_ref === "string") {
        const ref = parseRequirementRef(f.requirement_ref);
        if (ref.path !== REQUIREMENTS_PATH) err("requirement_ref のファイル「" + ref.path + "」は要件定義書ではありません。");
        if (!ref.numbers.length) err("requirement_ref に節の番号（§）がありません。");
        ref.numbers.forEach((n) => {
          if (!sections[n]) err("要件定義書に §" + n + " はありません。");
        });
      }
      if (typeof f.code_ref === "string") {
        parseCodeRef(f.code_ref).forEach((ref) => {
          if (!(ref.path in sources)) return err("ファイル「" + ref.path + "」はありません。");
          if (ref.from === null) return err("「" + ref.path + "」の行番号がありません。");
          const total = lineCount(sources[ref.path]);
          if (ref.from < 1 || ref.to > total || ref.from > ref.to) {
            err(ref.path + " に " + ref.from + "行目はありません（全" + total + "行）。");
          }
        });
      }
      if (f.requirement_ref === null && f.code_ref === null) warn("要件定義書にもコードにも参照先がありません。");
      if (f.classification === "誤り" && !f.external_basis) warn("誤りとしていますが、外部の基準の記載がありません。何を正解としたかを確かめてください。");
      if (typeof f.external_basis === "string" && !/未確認|\d{4}\s*[-/年]\s*\d{1,2}/.test(f.external_basis)) {
        warn("external_basis に確認日も「未確認」もありません。");
      }
    });
    return { fatal: null, errors, warnings, count: findings.length };
  }

  return { REQUIREMENTS_PATH, ENUMS, parseSections, parseRequirementRef, parseCodeRef, checkFindings };
});
