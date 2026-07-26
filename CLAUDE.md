# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリの性質

Dungeon Crawl Stone Soup 0.16 の**日本語化フォーク**（`github.com/umiyosh/dcss-0.16-ja`）。
上流は 2015 年頃の DCSS で、C++ もその時代のもの。作業のほぼ全てはゲームロジックの変更ではなく
**訳文の追加・修正**であり、直近 200 コミットのうち大半が `dat/database/ja/jtrans_*.txt` の編集。

デフォルトブランチは `develop`（`master` ではない）。上流リモートは設定されていない。

## ビルドとテスト

作業ディレクトリは `crawl-ref/source/`。`./crawl` はここから起動しないと `dat/` `docs/` を見つけられない。

```bash
make -C crawl-ref/source -j4             # コンソール版
make -C crawl-ref/source TILES=y -j4     # Tiles 版
make -C crawl-ref/source debug -j4       # FULLDEBUG。-test を使うにはこれが必要
make -C crawl-ref/source test            # crawl -test + ストレステスト全部
make -C crawl-ref/source nondebugtest    # 非debugビルド向け（-test は走らない）
```

### macOS でのビルドの罠（2026-07 時点で実測）

1. **SDK 検出が失敗して即停止する** — `Makefile:419` が
   `ls $DEVELOPER_PATH/SDKs | sort -n | head -1` で最古の SDK 名から版数を取る前提だが、
   現行 Xcode は `MacOSX.sdk`（版数なし）なので `SDK_VER` が空になり
   `You do not seem to have any Mac OS X SDKs installed!` で止まる。
   `NO_APPLE_GCC=y` を渡して Apple 専用ブロックごと飛ばせば通過する（検証済み）:

   ```bash
   make -C crawl-ref/source NO_APPLE_GCC=y -j4
   ```

2. **contrib が未展開だと `.contrib-libs` で失敗する** — システムに zlib / lua5.1 / sqlite が
   無い場合 `contrib/` をビルドしようとするが、submodule が空だと
   `The 'zlib' directory exists, but the Makefile is missing!` で停止する。
   さらに `.gitmodules` の URL は 11 件すべて `git://github.com/...` で、GitHub は
   このプロトコルを廃止済み。CI（`.github/workflows/ci.yml`）は insteadOf で回避している:

   ```bash
   git config --global url."https://github.com/".insteadOf git://github.com/
   git submodule update --init --recursive
   ```

macOS では contrib のうち lua と sqlite だけが必要（他は system / Homebrew 側を使う）なので、
submodule も次の 2 つを取れば足りる。

```bash
git submodule update --init crawl-ref/source/contrib/lua crawl-ref/source/contrib/sqlite
```

### テスト

単体テストは `crawl-ref/source/test/*.lua` が 1 ファイル 1 テスト。debug ビルド後に:

```bash
./crawl -test list            # テスト名一覧
./crawl -test monster-name    # 単体実行（カンマ区切りで複数可）
```

`-test` は `DEBUG_TESTS` 依存で、これは `make debug` → `FULLDEBUG` → `DEBUG_DIAGNOSTICS` →
`DEBUG_TESTS`（`AppHdr.h:348`）と連鎖して初めて定義される。通常ビルドでは `-test` は存在しない。

翻訳系の変更で壊れやすいのは `test/monster-name.lua`, `test/corpse.lua`, `test/rune-gen.lua`
（アイテム名・モンスター名の文字列を assert している）。

## 日本語化アーキテクチャ

### jtrans: メッセージ翻訳の中核

`database.h` / `database.cc` が提供する、**英語原文をキーにした辞書引き**。

| 呼び方 | 用途 |
|---|---|
| `jtrans("...")` | 英語原文 → 訳文（`string`） |
| `jtransc("...")` | 同上を `const char*` で（`mprf` の書式文字列などに） |
| `jtransln` / `jtranslnc` | 末尾改行を残す版 |
| `tagged_jtrans("[spell]", name)` | タグ付きキーで曖昧性を解消 |
| `jtrans_has_key(key)` | 訳が存在するか |

辞書の実体は `crawl-ref/source/dat/database/ja/jtrans_*.txt`。フォーマット:

```
%%%%
You feel the staff feeding on your energy!

杖があなたのエネルギーを吸い上げているのを感じた！
%%%%
```

`%%%%` 区切りで 1 エントリ。区切り直後の行が英語キー、空行を挟んで以降が訳文。
キーは lookup 時に `trim` され、改行は `\n` の 2 文字にエスケープされる（`database.cc:1008`）。
つまり複数行のメッセージをキーにする場合、辞書側のキー行も `\n` をリテラルで書く。

**キーが見つからない場合、`jtrans` は入力（英語原文）をそのまま返す。** つまりゲーム中に
英語が出ていれば「訳抜け」＝辞書エントリ欠落であり、これがこのリポジトリの主要なバグ形態。

タグ付きキーは辞書側でも `[spell]Fireball` のようにタグを前置して書く。実在するタグは
`[branch]` `[spell]` `[skill]` `[card]` `[dur]` `[zap]` `[adj]` `[form]` `[title]`
`[sacrifice]` `[auxname]`。

### 辞書ファイルの登録

`database.cc` の `AllDBs[]` に `TextDB("jtrans", "database/ja/", ...)` としてファイル名が
列挙されている。**新規 txt を追加したらここに追記しないと読み込まれない**。
（`jtrans_exclude.txt` など一部はコメントアウトされたまま残っている）

DB は sqlite dbm にコンパイルされ、セーブディレクトリ配下 `db/` にキャッシュされる。
txt のタイムスタンプが変わると起動時に自動再生成される（`Regenerating db: ...` と出る）。
明示的に作り直すなら `./crawl --builddb`（`make builddb` も同じ）。

### descript: 解説文の言語オーバーレイ

上流由来の仕組み。`dat/descript/<lang>/*.txt` が `dat/descript/*.txt` に上書きで重なる
（`TextDB::translation`）。言語は `Options.lang_name` で選ばれ、**このフォークでは
`initfile.cc:1713` の `game_options()` で `LANG_JA` / `"ja"` にハードコードされている**。
モンスター・アイテム・呪文などの長文解説は `dat/descript/ja/` を編集する。

`dat/database/ja/` 直下には `monspeak.txt` `shout.txt` `godspeak.txt` など上流の
ランダムテキスト DB の日本語版も同居している（`jtrans_` 接頭辞なし = 上流ファイルの ja 版）。
`dat/database/ja/crawlj/` は `randart_vanilla` DB 用（ランダムアーテファクト名の別セット）。

なお `crawl-ref/docs/develop/translation.txt` は上流の Transifex ワークフローの説明で、
**このフォークには適用されない**。翻訳は上記 jtrans / descript を直接編集する。

### japanese.cc: 日本語文法ヘルパー

`english.cc` の対応物。上流の英語処理関数を残したまま、`_j` 接尾辞で日本語版を並置している。

- `counter_suffix*()` — 助数詞（剣は「振」、斧は「挺」、弩は「丁」、弓は「張」…）。
  `itemname.cc` が `<数><助数詞>の<名前>` を組み立てる
- `jpluralise(name, prefix, suffix)` — 「両手」「〜たち」など日本語の複数表現
- `apply_description_j()` / `thing_do_grammar_j()` — 冠詞処理の代替（英語の a/the を捨てる）
- `jconj_verb(verb, jconj)` — 動詞活用（未然・連用・終止・連体・仮定・命令・完了・受動・現在）
- `jnumber_for_hydra_heads()` / `get_desc_quantity_j()` — 数量表現

### 語順の入れ替え

英語 SVO を日本語 SOV に組み替えるために、引数順を差し替える専用関数がある:

```cpp
// 呼び出し側は英語順 (subject, verb, object) で渡すが、
// 書式文字列には subject, object, verb の順で入る
jtrans_make_stringf(msg, subject, verb, object);
jtrans_make_stringf(msg, verb, object);   // 2引数版も同様に object, verb
```

訳文側の `%s` はこの入れ替え後の順序で書く必要がある。

### 訳文が集中しているファイル

`jtrans` 呼び出しが多い順に `command.cc`, `describe.cc`, `godabil.cc`, `player.cc`,
`beam.cc`, `item_use.cc`, `melee_attack.cc`, `xom.cc`, `itemname.cc`。
辞書ファイル名はおおむねソースファイル名に対応している（`describe.cc` → `jtrans_describe.txt`）。

### 訳抜けを直す典型フロー

1. ゲーム中に英語で出ている文字列を、ソースから grep して該当箇所を特定する
2. 呼び出しが `mpr("...")` のように生の英語リテラルなら `mpr(jtrans("..."))` に、
   `mprf("... %s ...", x)` なら `mprf(jtransc("... %s ..."), x)` に置き換える
3. 対応する `dat/database/ja/jtrans_<モジュール名>.txt` に `%%%%` エントリを追加する
   （キーはソース中のリテラルと完全一致させる。`trim` はされるが内部の空白・記号は一致必須）
4. 語順を変える必要があれば `jtrans_make_stringf` を使い、訳文側の `%s` を入れ替え後の順で書く
5. 再ビルドして起動すると DB が自動再生成される。表示を目視確認する

既に `jtrans()` で包まれているのに英語が出る場合は (3) だけの問題、
英語リテラルが素で渡っている場合は (2) からの問題。

## コーディング規約

`crawl-ref/docs/develop/coding_conventions.txt` に従う。**汎用の modern C++ ルールは適用しない** —
0.16 は C++11 以前が主体のコードベースで、周囲のコードに合わせるのが正解。

- スペース 4、タブ禁止、80 桁前後
- 波括弧は独立行
- 関数・変数は `snake_case`、ファイル内部関数は `_` 前置、メンバは `m_`、static メンバは `sm_`

コミット前に `crawl-ref/source/util/checkwhite`（`-m` で staged のみ、`-n` で dry-run）。
`crawl-ref/git-hooks/pre-commit` は末尾空白・タブ・CR・**不正な UTF-8**・マージ衝突マーカーを
検出して commit を止める。日本語テキストを扱うので UTF-8 チェックは実質的に重要。

`util/db_lint` は訳文エントリの欠落・余剰を検査するが、対象は上流由来の
`dat/descript/<lang>/*` と `dat/database/<lang>/*`（`monspeak` 等）だけで、
**`jtrans_*.txt` は対象外**（引数に渡しても黙って何もしない）。
`crawl-ref/source/` を cwd にして実行する必要がある:

```bash
perl util/db_lint -v ja monsters   # dat/descript/ja/monsters.txt を検査
```

## コミットメッセージ

**このリポジトリの慣習は日本語 1 行要約**（直近 200 コミット中 188 件）。例:

```
Contamが付いた防具を装備した状態で別の防具を装備しようとすると無警告で装備されてしまうのを修正
"caustic shrike"の訳を｢焼酸の百舌｣に変更
```

CI・テスト・ビルド周りの変更のみ英語の Conventional Commits（`fix(build):`, `ci:`, `test:`）が
使われている。

なお `AGENTS.md` は「Conventional Commits に従え」と書いているが、それが実際に当てはまるのは
上記のインフラ系コミットだけで、訳文修正の履歴は日本語 1 行要約が圧倒的多数。
訳文修正では既存履歴（日本語要約）に合わせるのが自然だが、判断に迷う場合は確認すること。

## CI

`.github/workflows/ci.yml`（Travis からは移行済み）。`develop` への push と PR で起動する。

`build` ジョブは ubuntu-22.04 上で GCC × Clang の 2 コンパイラ × 10 バリアント
（Console / Tiles / Webtiles / DGL、それぞれ debug 有無、bundled dependencies 版）を
ビルドする。Tiles 以外のバリアントでは `make test`（debug）または `make nondebugtest` も走る。

`build-macos` ジョブは macos-latest（arm64）で Console / Console (debug) / Tiles をビルドし、
`./crawl --version` が動くところまで確認する。debug バリアントだけ `make test-test`
（`crawl -test`）も走る。ストレステスト（`test-all`）は 1 本あたり最大 595 秒かかるため回していない。

`test-test` を呼ぶときも `debug` をゴールに残すこと。`Makefile:792` が `DEBUG` と
`NO_OPTIMIZE` を `MAKECMDGOALS` から決めているため、外すとフラグが変わって全再ビルドになる。

## AGENTS.md との関係

リポジトリルートに英語の `AGENTS.md` がある（Codex 等の他エージェント向け）。
プロジェクト構成・ビルド・スタイル・PR 運用の一般論はそちらと重複するが、
**日本語化アーキテクチャの記述は AGENTS.md に無い**のでこの CLAUDE.md が唯一の情報源。
ビルド手順など共通部分を書き換えるときは両方の整合を取ること。
