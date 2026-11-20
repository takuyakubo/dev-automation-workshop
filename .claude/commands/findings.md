---
description: 要件定義書と既存コードから、移行前に確認すべき問題点を洗い出す
---

このCOBOLシステムをJavaへ移行します。その前に、`docs/requirements.md` と `legacy/` を読み、問題点を洗い出してください。

対象のファイルは次の6つです。すべて読んでください。

- `docs/requirements.md`（移行要件定義書）
- `legacy/DEPOSIT.cbl`、`legacy/INTEREST.cbl`（現行のCOBOLプログラム）
- `legacy/COPYBOOK/ACCOUNT.cpy`（レコード定義）
- `legacy/data/ACCOUNT.txt`、`legacy/data/TRANSACTION.txt`（サンプルデータ）

結果は `findings/findings.json` にJSON配列で出力してください。各要素の形式は次のとおりです。

```json
{
  "id": "F-001",
  "classification": "誤り | 矛盾 | 未定義",
  "area": "業務ロジック | 営業依存 | 基盤・移行・文書",
  "severity": "高 | 中 | 低",
  "title": "短い題名",
  "requirement_ref": "docs/requirements.md §3.2（該当がなければ null）",
  "code_ref": "legacy/DEPOSIT.cbl:84（該当がなければ null）",
  "evidence": "根拠の説明",
  "migration_impact": "移行への影響",
  "external_basis": "外部の基準を根拠にした場合の出典と確認日（なければ null）"
}
```

`classification` は次の基準で選んでください。

- 誤り：正解がある状態で、何かがおかしい。法令などの外部の基準も正解に含める
- 矛盾：正解はないが、2つ以上の記述が異なる
- 未定義：書くべきことが書かれていない

外部の基準を根拠にする場合は、`external_basis` に出典と確認日を書いてください。手元で確認していない知識に基づく場合は「未確認」と書いてください。

ファイルを読むときは Read を使ってください。ファイルの一覧や検索が必要なら、Glob と Grep、または `ls`、`find`、`grep` など読むだけのコマンドを使って構いません。ファイルを変更するコマンドと Web 検索は使わないでください。書き込むのは `findings/findings.json` だけです。書き込んだ後に、`python3` や `node` などで JSON を確かめることもしないでください。形式の確認は、後でレポートの「機械のチェック」が行います。休憩中に確認待ちで止まらないようにするためです。

`area` は次の基準で選んでください。

- 業務ロジック：入出金と利息の計算そのもの
- 営業依存：時間外、営業日、手数料など、営業や運用の決めで変わるもの
- 基盤・移行・文書：上の2つに入らないもの（照合順序、障害回復、非機能など）
