# Dungeon Crawl Stone Soup 日本語版 0.16

[![Build](https://github.com/umiyosh/dcss-0.16-ja/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/umiyosh/dcss-0.16-ja/actions/workflows/ci.yml)
[![License: GPL-2.0-or-later](https://img.shields.io/badge/license-GPL--2.0--or--later-blue.svg)](crawl-ref/licence.txt)

Dungeon Crawl Stone Soup (DCSS) 0.16 の日本語版です。

いまは WebTiles でオンラインプレイするのが主流ですが、macOS のタイル版を
ローカルで遊んでみたくて、現行の macOS でも動くアプリをビルドしました。
個人的に遊ぶためのものなので、大がかりなプロジェクトではありません。

もうひとつ、古い C++ のゲームを現行環境でビルドする作業を題材に、
Claude Opus 5 がどのくらい使えるのか試してみる目的もあります。

## 遊ぶ

[リリースページ](https://github.com/umiyosh/dcss-0.16-ja/releases/latest)から
タイル版の zip (`stone_soup-<版数>-tiles-macosx.zip`) をダウンロードし、
`.app` をアプリケーションフォルダに入れてください。

Apple Silicon (arm64) 専用で、macOS 11 (Big Sur) 以降に対応しています。
必要なライブラリはアプリに含まれているため、Homebrew などの準備は不要です。

初回起動時は、Apple の公証を受けていないため警告が出ます。
一度起動を試したあと、**システム設定 → プライバシーとセキュリティ**に表示される
**「このまま開く」**を押してください。ターミナルから解除する場合は次のコマンドでも開けます。

```bash
xattr -dr com.apple.quarantine "/Applications/Dungeon Crawl Stone Soup - Tiles.app"
```

最初は次の操作だけ覚えれば遊べます。

| キー | 操作 |
| --- | --- |
| `方向キー` / `h j k l y u b n` | 移動。敵のいる方向へ進むと攻撃 |
| `o` | 未探索区域を自動探索 |
| `Tab` | 近くの敵へ移動・攻撃 |
| `5` | HP・MPが回復するまで休息 |
| `,` | 足元のアイテムを拾う |
| `i` | 所持品を見る |
| `<` / `>` | 階段を上る / 下りる |
| `S` | 保存して終了 |
| `?` | ヘルプ |

詳しい操作や序盤の進め方は
[Mac版・初心者向け操作ガイド](crawl-ref/docs/beginner-guide-ja.md) にまとめています。
原文の資料は `crawl-ref/docs/quickstart.txt` と
`crawl-ref/docs/crawl_manual.reST` にあります（英語です）。

## ソースからビルドする

```bash
git -c url."https://github.com/".insteadOf=git://github.com/ \
    submodule update --init crawl-ref/source/contrib/lua crawl-ref/source/contrib/sqlite
make -C crawl-ref/source TILES=y NO_APPLE_GCC=y -j6
```

配布用のコンソール版とタイル版をまとめて作る場合は、次を実行します。

```bash
make -C crawl-ref/source NO_APPLE_GCC=y -j6 dist-macos
```

ビルドした `crawl` は、データファイルを相対パスで探すため
`crawl-ref/source/` を作業ディレクトリにして起動してください。

## 由来とライセンス

このリポジトリは
[dplusplus/dcss-0.16-ja](https://github.com/dplusplus/dcss-0.16-ja) を元にしています。
ゲーム内容は 2015 年の 0.16 のままで、
[本家 DCSS](https://github.com/crawl/crawl) の最新版とは別物です。

DCSS 本体と本リポジトリでの変更は GPL v2 以降で配布します。
詳細は [ライセンス全文](crawl-ref/licence.txt) と
[作者一覧](crawl-ref/CREDITS.txt) を参照してください。
同梱している HackGen フォントは SIL Open Font License 1.1 です。
