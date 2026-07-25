# Dungeon Crawl Stone Soup 日本語版 0.16

[![Build](https://github.com/umiyosh/dcss-0.16-ja/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/umiyosh/dcss-0.16-ja/actions/workflows/ci.yml)
[![License: GPL-2.0-or-later](https://img.shields.io/badge/license-GPL--2.0--or--later-blue.svg)](crawl-ref/licence.txt)

ローグライク Dungeon Crawl Stone Soup 0.16 を日本語化したものです。個人で保守しています。

## このリポジトリについて

[dplusplus/dcss-0.16-ja](https://github.com/dplusplus/dcss-0.16-ja) の内容をコピーして作成しました。
GitHub のフォークではないため、上流との間に fork 関係はなく、ここでの変更が上流に流れることもありません。
DCSS は GPL v2 以降で配布されているので、この形での複製と改変は認められています。

ゲーム内容は 0.16 (2015年) のままで、本家 DCSS の最新版とは別物です。
現在は訳文の修正と、現行の開発環境でビルドできるようにするための保守を行っています。

## 遊ぶ

ソースからビルドします。`crawl-ref/source/` を作業ディレクトリにして `./crawl` を起動してください
（`dat/` と `docs/` を相対パスで探すため、他の場所からは起動できません）。

同梱ライブラリを使う場合は submodule の取得が必要です。`.gitmodules` の URL が GitHub の廃止した
`git://` のままなので、書き換えながら取得します。

```bash
git -c url."https://github.com/".insteadOf=git://github.com/ submodule update --init --recursive
```

Linux ではコンソール版が `make -C crawl-ref/source -j6`、タイル版が `TILES=y` を足すだけで通ります。
必要なパッケージは `.github/workflows/ci.yml` の内容が参考になります。

macOS (Apple Silicon) では、Makefile の SDK 検出が現行 Xcode に対応していないため `NO_APPLE_GCC=y` が要ります。
また同梱の SDL2 と zlib が 2014 年当時のもので現行 clang を通らないので、Homebrew 側を使います。

```bash
brew install sdl2 sdl2_image freetype libpng pkg-config
make -C crawl-ref/source NO_APPLE_GCC=y -j6                       # コンソール版
make -C crawl-ref/source TILES=y NO_APPLE_GCC=y \
     NO_PKGCONFIG= BUILD_SDL2= BUILD_SDL2IMAGE= \
     BUILD_FREETYPE= BUILD_LIBPNG= -j6                            # タイル版
```

`mac-app-tiles` ターゲットで `.app` バンドルも作れます。macOS 対応の残課題は
[#16](https://github.com/umiyosh/dcss-0.16-ja/issues/16) にまとめてあります。

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
