日本語ヘルプ文書の生成
========================

crawl_manual.reSTが日本語マニュアルの正本です。ゲーム内で表示する
crawl_manual.txtは、source/Makefileの生成規則とsource/util/unrest.plを使って
生成します。

生成物を確認する場合は、crawl-ref/sourceで次のコマンドを実行します。

  make ../docs/crawl_manual.txt
  ./util/gen-apt.pl ../docs/aptitudes.txt ../docs/template/apt-tmpl.txt \
      species.cc aptitudes.h
  ./util/FAQ2html.pl dat/database/FAQ.txt ../docs/FAQ.html

crawl_manual.txt、aptitudes.txt、FAQ.htmlは生成物です。正本の変更後に再生成して
表示を確認します。
