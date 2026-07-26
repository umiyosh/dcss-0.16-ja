# Dungeon Crawl Stone Soup 日本語版 0.16

[![Build](https://github.com/umiyosh/dcss-0.16-ja/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/umiyosh/dcss-0.16-ja/actions/workflows/ci.yml)
[![License: GPL-2.0-or-later](https://img.shields.io/badge/license-GPL--2.0--or--later-blue.svg)](crawl-ref/licence.txt)

ローグライク Dungeon Crawl Stone Soup 0.16 を日本語化したものです。個人で保守しています。

## このリポジトリについて

[dplusplus/dcss-0.16-ja](https://github.com/dplusplus/dcss-0.16-ja) の内容をコピーして作成しました。
GitHub のフォークではないため、上流との間に fork 関係はなく、ここでの変更が上流に流れることもありません。
DCSS は GPL v2 以降で配布されているので、この形での複製と改変は認められています。

ゲーム内容は 0.16 (2015年) のままで、[本家 DCSS](https://github.com/crawl/crawl) の最新版とは別物です。
現在は訳文の修正と、現行の開発環境でビルドできるようにするための保守を行っています。

## 本家との違い

本家は 2026年3月時点で 0.34.1 まで進んでおり、0.16 (2015年3月) との間には18バージョン、
ちょうど11年ぶんの開きがあります。その間に土台の仕様が何度も変わっているため、
最近の DCSS に慣れている場合は別物として扱ってください。

大きなところでは、0.17 で視界が正方形になり Lair の支流が5層から4層に短縮され、
0.23 で罠が刷新されて迷宮 (Labyrinth) が Gauntlet に置き換わりました。
0.26 では食料と空腹の概念そのものが廃止され、0.34 では消耗品の所持数制限も無くなっています。
種族・神・背景の追加も続いていて、Gnoll (0.21)、Djinni (0.27)、Coglin (0.32) といった種族、
Wu Jian Council (0.21) のような神、Shapeshifter や Alchemist (0.31) といった背景は 0.16 にはありません。

逆に言えば、ここで遊べるのは食料管理が必要だった頃の DCSS です。
各版の変更点は本家の
[changelog.txt](https://github.com/crawl/crawl/blob/master/crawl-ref/docs/changelog.txt) にまとまっています。

## 遊ぶ (macOS)

[リリースページ](https://github.com/umiyosh/dcss-0.16-ja/releases/latest)から zip をダウンロードし、
`.app` をアプリケーションフォルダに入れてください。

- `stone_soup-<版数>-tiles-macosx.zip` — タイル版 (グラフィカル)
- `stone_soup-<版数>-console-macosx.zip` — コンソール版 (文字のみ)

**Apple Silicon (arm64) 専用**で、macOS 11 (Big Sur) 以降で動きます。Intel Mac には対応していません。
必要なライブラリはすべてバイナリに組み込んであるので、Homebrew などの事前準備は要りません。

### 初回起動時の警告について

ダウンロードした `.app` を最初に開こうとすると、次の警告が出ます。

> "Dungeon Crawl Stone Soup - Tiles" は開いていません
> Apple は、"Dungeon Crawl Stone Soup - Tiles" に Mac に損害を与えたり、
> プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。

これは**ダウンロードした人全員に出ます**。アプリが壊れているわけでも、実際に何か検出された
わけでもありません。Apple の公証 (notarization) を受けていない配布物に対して macOS が一律に出す
警告で、原因は署名が自己署名相当であることだけです。

開くには次のどちらかを行ってください。

**方法1: システム設定から許可する**

1. 警告ダイアログの「完了」を押して閉じる (「ゴミ箱に入れる」は押さない)
2. **システム設定 → プライバシーとセキュリティ** を開く
3. 下の方に「"Dungeon Crawl Stone Soup - Tiles" は開発元を確認できないため
   使用がブロックされました」と出ているので、その横の**「このまま開く」**を押す

**方法2: ターミナルで隔離属性を外す**

```bash
xattr -dr com.apple.quarantine "/Applications/Dungeon Crawl Stone Soup - Tiles.app"
```

どちらも最初の一度だけで、二回目以降は普通に起動します。macOS 15 (Sequoia) 以降では、
かつて使えた「右クリック → 開く」の回避策は廃止されているので、上記のどちらかになります。

この手順を不要にする Developer ID 署名と公証の対応は
[#37](https://github.com/umiyosh/dcss-0.16-ja/issues/37) で進めています。

## ソースからビルドする

`crawl-ref/source/` を作業ディレクトリにして `./crawl` を起動してください
（`dat/` と `docs/` を相対パスで探すため、他の場所からは起動できません）。

同梱ライブラリを使う場合は submodule の取得が必要です。`.gitmodules` の URL が GitHub の廃止した
`git://` のままなので、書き換えながら取得します (macOS は後述のとおり 2 つだけで足ります)。

```bash
git -c url."https://github.com/".insteadOf=git://github.com/ submodule update --init --recursive
```

Linux ではコンソール版が `make -C crawl-ref/source -j6`、タイル版が `TILES=y` を足すだけで通ります。
必要なパッケージは `.github/workflows/ci.yml` の内容が参考になります。

macOS (Apple Silicon) では、Makefile の SDK 検出が現行 Xcode に対応していないため `NO_APPLE_GCC=y` が要ります。

```bash
git -c url."https://github.com/".insteadOf=git://github.com/ \
    submodule update --init crawl-ref/source/contrib/lua crawl-ref/source/contrib/sqlite
make -C crawl-ref/source NO_APPLE_GCC=y -j6            # コンソール版
make -C crawl-ref/source TILES=y NO_APPLE_GCC=y -j6    # タイル版
```

タイル版の SDL2 / SDL2_image / FreeType / libpng / zlib は
`crawl-ref/source/contrib/build-macos-deps.sh` が上流から取得して静的ビルドするので、
Homebrew での事前準備は不要です (cmake と curl だけ使います)。
Homebrew を使わないのは、その bottle がビルドしたマシンの macOS 版数向けに作られていて、
同梱すると成果物がその版数以降でしか起動しなくなるためです。

配布物と同じものを作るなら `make -C crawl-ref/source NO_APPLE_GCC=y -j6 dist-macos` で、
コンソール版とタイル版の zip が `crawl-ref/source/dist/` に揃います。
macOS 対応の残課題は [#16](https://github.com/umiyosh/dcss-0.16-ja/issues/16) にまとめてあります。

遊び方そのものは `crawl-ref/docs/` の quickstart.txt と crawl_manual.reST を参照してください
（英語のままです）。

## 日本語化の仕組み

メッセージは英語の原文をキーにした辞書引きで訳しています。ソース側で `jtrans("...")` と包み、
`crawl-ref/source/dat/database/ja/jtrans_*.txt` に `%%%%` 区切りで原文と訳文の対を置きます。
キーが見つからないときは原文がそのまま返るため、ゲーム中に英語が出ていればそれが訳抜けです。

モンスターやアイテムの長い解説文は `crawl-ref/source/dat/descript/ja/` に、
助数詞や活用といった日本語固有の処理は `crawl-ref/source/japanese.cc` にあります。
タイル版は CJK グリフを持つフォントが要るので、HackGen を `dat/tiles/` に同梱しています。

詳しくは [CLAUDE.md](CLAUDE.md) に書いてあります。

## ディレクトリ

`crawl-ref/source/` に C++ のソースと Makefile、`crawl-ref/source/dat/` にゲームデータと辞書、
`crawl-ref/docs/` にドキュメント、`crawl-ref/settings/` に設定例があります。
ファイル構成の詳細は `crawl-ref/README.txt` にあります。

## ライセンスと来歴

DCSS 本体は Linley Henzell と開発チームによる著作物で、GNU General Public License version 2 以降で
配布されています。全文は [crawl-ref/licence.txt](crawl-ref/licence.txt)、作者一覧は
`crawl-ref/CREDITS.txt` にあります。タイル画像や一部のソースには GPL と両立する別ライセンス
(BSD, MIT, CC0 など) のものが含まれます。

日本語訳は dplusplus 氏による [dcss-0.16-ja](https://github.com/dplusplus/dcss-0.16-ja) が元になっています。
同梱している HackGen フォントは SIL Open Font License 1.1 です
([crawl-ref/docs/license/hackgen-LICENSE.txt](crawl-ref/docs/license/hackgen-LICENSE.txt))。

本リポジトリでの変更も同じく GPL v2 以降で配布します。
