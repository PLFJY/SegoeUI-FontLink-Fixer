# SegoeUI-FontLink-Fixer

[简体中文](README.md) / 日本語 / [한국어](README.ko-KR.md) / [English](README.en-US.md)

> [!WARNING]
> このプロジェクトのコードのかなりの部分は AI 支援により生成され、その後も継続的な人手による調整、結合確認、リファクタリングを行っていますが、それでも見落としや境界条件の処理不足、期待と完全には一致しない挙動が残っている可能性があります。
> 利用中にバグ、互換性の問題、異常な挙動、またはドキュメント不足を見つけた場合は、Issue の報告を歓迎します。再現手順、ログ、スクリーンショット、OS バージョン情報を添えていただけると非常に助かります。

`SegoeUI-FontLink-Fixer` は、Windows FontLink レジストリ マッピングを確認、バックアップ、プレビュー、適用、検証、復元するための、保守的で安全性重視の PowerShell ツールです。

対象レジストリ パス:

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink`

主な用途は、既定の CJK フォールバック順序が希望に合わない環境で、`Segoe UI*`、`Tahoma`、`Microsoft Sans Serif` のフォールバック優先順位を調整することです。

## このツールについて

このツールは FontLink リストを最初から作り直しません。安定した並べ替えモデルを使います。

- 対象言語のフォントだけを前に移動
- 無関係な項目の相対順は維持
- その値に存在しない項目は新規生成しない

つまり、積極的な再構築ではなく、既存順序の修正に向いたツールです。

## 安全上の注意

このプロジェクトは `HKLM` 配下のシステム レジストリを変更します。機密性の高い設定です。

`apply` や `restore` を実行する前に、スクリプトと復旧経路を確認してください。

現在の安全設計:

- 書き込み前に必ずバックアップを作成
- バックアップ失敗後は続行しない
- `apply` 後に再読込して検証し、検証失敗なら成功扱いにしない
- `restore` はバックアップ検証後に復元前安全バックアップを作成し、復元後も再検証する
- 不完全なバックアップは明示的にマークされ、復元に使えない

リスクを減らすことはできますが、ゼロにはできません。

## 機能

- `SystemLink` キー全体をバックアップ
- `.reg` と JSON スナップショットを同時に保存
- ハッシュ、タイムスタンプ、値一覧を含む `manifest.json` を作成
- `Segoe UI` で始まるすべての値を自動処理
- `Tahoma` と `Microsoft Sans Serif` も処理
- `zh-CN`、`zh-TW`、`ja-JP`、`ko-KR` をサポート
- dry-run / プレビュー対応
- 最新有効バックアップまたは指定パスから復元可能
- ローカル向けキーボード駆動 TUI を提供
- UI 言語:
  `zh-CN`、`ja-JP`、`ko-KR`、`en-US`

## 要件

- Windows
- PowerShell 5.1 以降
- `apply` / `restore` には管理者権限が必要

## クイックスタート

TUI を起動:

```powershell
.\SegoeLinker.ps1
```

明示的に起動する場合:

```powershell
.\SegoeLinker.ps1 tui
```

プレビュー実行:

```powershell
.\SegoeLinker.ps1 apply zh-CN --dry-run
```

手動バックアップ:

```powershell
.\SegoeLinker.ps1 backup
```

最新の有効バックアップを復元:

```powershell
.\SegoeLinker.ps1 restore --latest
```

## TUI

`.\SegoeLinker.ps1` を実行するとローカル TUI が開きます。

TUI は人が使うための主要 UI として設計されています。

- メイン メニューは単キー操作
- プロファイル選択は単キー操作
- 言語選択は単キー操作
- 復元パスのように文字入力が必要な場合だけ入力欄を使用

選択した UI 言語は次のローカル設定ファイルに保存されます。

- `.segoelinker.user.json`

このファイルはプロジェクト ルートに置かれ、Git では無視されます。

## UI 言語

TUI 内で切り替えることも、コマンドラインで `--lang` を使うこともできます。

`--lang` が指定されていない場合は、ローカル保存済みの UI 言語設定を優先します。

例:

```powershell
.\SegoeLinker.ps1 list --lang zh-CN
.\SegoeLinker.ps1 status --lang ja-JP
.\SegoeLinker.ps1 backup --lang ko-KR
.\SegoeLinker.ps1 tui --lang en-US
```

対応言語 ID:

- `zh-CN`
- `ja-JP`
- `ko-KR`
- `en-US`

## コマンド

```powershell
.\SegoeLinker.ps1
.\SegoeLinker.ps1 tui
.\SegoeLinker.ps1 backup
.\SegoeLinker.ps1 apply zh-CN
.\SegoeLinker.ps1 apply ja-JP --dry-run
.\SegoeLinker.ps1 restore --latest
.\SegoeLinker.ps1 restore --file .\backups\20260420-120000123
.\SegoeLinker.ps1 list
.\SegoeLinker.ps1 status
.\SegoeLinker.ps1 help
```

## 対応プロファイル

- `zh-CN`: `Microsoft YaHei UI`, `Microsoft YaHei`
- `zh-TW`: `Microsoft JhengHei UI`, `Microsoft JhengHei`
- `ja-JP`: `Yu Gothic UI`, `Yu Gothic`, `Meiryo UI`, `Meiryo`
- `ko-KR`: `Malgun Gothic`

挙動は意図的に保守的です。

- その値に既に存在する対象項目だけを移動
- 無関係な項目の相対順は維持
- 存在しないフォント項目は追加しない

補足:

- `Segoe UI*`、`Tahoma`、`Microsoft Sans Serif` はすべて同じ安定並べ替えモデルを使います
- 現在の値に存在する項目だけが前方移動の対象です
- `,128,96` を含まない値に対して、` ,128,96` 項目を新規生成しません

## バックアップ形式

各バックアップは [backups](./backups) 配下のタイムスタンプ付きディレクトリに保存されます。

完全なバックアップには以下が含まれます。

- `SystemLink.reg`
  手動確認や手動インポート互換のための完全な `reg.exe export`
- `SystemLink.snapshot.json`
  正確な復元ロジック用の構造化スナップショット
- `manifest.json`
  schema 版、タイムスタンプ、ハッシュ、レジストリ パス、値一覧

バックアップ作成中は `backup.incomplete.txt` が置かれます。途中で失敗したバックアップは、意図的に復元不可のまま残します。

## 復元モデル

`restore` は明示的で、保守的で、検証可能であることを重視しています。

処理の流れ:

1. `--latest` または `--file` で対象バックアップを解決
2. manifest、必要ファイル、schema 版、対象レジストリ、ハッシュを検証
3. 現在状態の安全バックアップを新規作成
4. `SystemLink` スナップショット全体を正確に復元
5. 復元後の状態を再読込して一致を検証

復元は `SystemLink` キー全体に対する正確な復元です。

- バックアップに存在する値は復元
- 現在あるがバックアップに存在しない値は削除

この用途では部分マージ復元のほうが危険なため、この方式を採用しています。

## 昇格

`apply` と `restore` は `HKLM` へ書き込むため、管理者権限が必要です。

書き込み前に昇格状態を確認し、必要であれば管理者権限で自動再起動してから処理を続けます。

昇格時の引数受け渡しには、脆弱な文字列連結ではなくエンコード済みペイロードを使用しているため、空白パス、引用符、Unicode 引数に対してより安全です。

既定で昇格を強制しないコマンド:

- `backup`
- `list`
- `status`
- `apply --dry-run`
- `tui`

TUI 内の書き込み操作も同じ安全な経路を使用します。

## 出力と検証

ツールは次の情報を明示的に表示します。

- 昇格状態
- バックアップ保存先
- 対象となる管理値
- 変更前後の順序差分
- 復元時に選択されたバックアップ
- 検証の成功 / 失敗
- ログオフ / 再起動が必要な可能性

`apply` または `restore` の最終検証が失敗した場合、成功とは表示しません。

## 実行を中止する代表例

- 無効なプロファイル ID
- `--file` パス不足
- 無効なバックアップ選択
- 不完全バックアップ マーカーの存在
- manifest、snapshot、`.reg` の欠落
- バックアップ ハッシュ不一致
- バックアップ対象レジストリ不一致
- 復元スナップショット内の未対応値種別
- 対象値が `MultiString` ではない
- 書き込み後検証の不一致

## 補足

- `status` は `Segoe UI*`、`Tahoma`、`Microsoft Sans Serif` と最新有効バックアップを表示します
- `list` は対応プロファイルと優先フォントを表示します
- TUI は選択した UI 言語を `.segoelinker.user.json` に保存します
- 変更の反映には、環境によってログオフ、再起動、対象アプリ再起動が必要な場合があります
- `backups/` は `.gitkeep` を除いて Git 無視です
- `.segoelinker.user.json` は Git 無視です

## 制限

- 既存項目の順序調整のみを行い、欠落 FontLink データは合成しません
- `apply` が途中で失敗した場合、事前バックアップは存在しますが、ロールバックは別操作です
- TUI はローカル対話コンソール向けであり、無人自動化向けではありません
- 即時キー入力が使えない環境では、TUI は行入力互換モードにフォールバックします

## 免責

このプロジェクトは慎重に設計されていますが、依然として機密性の高いシステム レジストリを変更します。コードと復旧手順を理解したうえで利用してください。
