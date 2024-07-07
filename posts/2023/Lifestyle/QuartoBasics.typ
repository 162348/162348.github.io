// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

#show ref: it => locate(loc => {
  let target = query(it.target, loc).first()
  if it.at("supplement", default: none) == none {
    it
    return
  }

  let sup = it.supplement.text.matches(regex("^45127368-afa1-446a-820f-fc64c546b2c5%(.*)")).at(0, default: none)
  if sup != none {
    let parent_id = sup.captures.first()
    let parent_figure = query(label(parent_id), loc).first()
    let parent_location = parent_figure.location()

    let counters = numbering(
      parent_figure.at("numbering"), 
      ..parent_figure.at("counter").at(parent_location))
      
    let subcounter = numbering(
      target.at("numbering"),
      ..target.at("counter").at(target.location()))
    
    // NOTE there's a nonbreaking space in the block below
    link(target.location(), [#parent_figure.at("supplement") #counters#subcounter])
  } else {
    it
  }
})

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      block(
        inset: 1pt, 
        width: 100%, 
        block(fill: white, width: 100%, inset: 8pt, body)))
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[Abstract] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}
#show: doc => article(
  title: [Quarto はじめて良かった],
  authors: (
    ( name: [司馬博文],
      affiliation: [],
      email: [] ),
    ),
  date: [11/04/2023],
  abstract: [Quarto は TeX のような使用感で，数式とコードが併存する文章を書き，１つのソースファイルから PDF, HTML, Word, Reveal.js, PowerPoint などの多様な形式に出力できる次世代の執筆環境である．TeX, RStudio, Jupyter Notebook のいずれかに慣れている人であれば，極めて手軽に Quarto を使うことができる．],
  margin: (x: 1.5em,y: 1.5em,),
  toc: true,
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)
#import "@preview/fontawesome:0.1.0": *


#block[
]
= 使い方の概要
<使い方の概要>
== 導入
<導入>
本サイトは Quarto と，GitHub Actions によってホスティングされている．

Quarto ではこのような Notebook-like なドキュメントが，極めて簡単に＋凡ゆるフォーマットで作成できる．

特に VSCode の拡張機能と組み合わせれば，RStudio のような隙のない統合開発環境が得られる．#footnote[特に，VSCode では#link("https://quarto.org/docs/visual-editor/vscode/")[ビジュアルモードでの編集];もサポートされており，Jupyter Notebookと全く同じ使用感で始められる．]

基本的な仕組みとして，自分で作成するのは `.qmd`ファイルのみである．

その後は`quarto render`コマンドにより，

#block[
#callout(
body: 
[
- コードブロックは Jupyter によって処理され，
- 全体は markdown に変換され，
- Pandoc によって`pdf`, `html`, `word` など好きな形式に最終出力できる．

]
, 
title: 
[
Important
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
)
]
拡張機能をオンにした VSCode では`Run Cell`ボタンもあるので，ノートブック全体を毎度ビルドせずとも，コードブロックごとに実行して結果を見ることもできる．

`Ctrl+Enter` で１行ごとに実行できる操作感は `RStudio` と同じである．

== 美点
<美点>
#block[
#callout(
body: 
[
- レンダリングがとんでもなく速い．体感で TeX の10分の1である．
- それでいて数式とコードブロックを併在させることが出来る．なお，明かに TeX を意識していることがわかる使用感になっているし，#link("https://quarto.org/docs/books/")[本の作成も可能];としている．
- （ちょっと使いにくい）ブラウザ上ではなく，好きなエディタで動く．Jupyter Notebook が続かない筆者にとって，この点は肝要である．
- 私用の勉強ノートとしても使えると同時に，内容そのままブログとして公開できる．
- #link("https://quarto.org/docs/presentations/")[プレゼンテーションの作成にも使える];．
- すごい細かいが，例えば `project type` を `website` としたリポジトリで`quarto render`をしても，不要なファイルが自動で削除される．このような点がライトユーザーでもとにかく使いやすい．
- さらに#link("https://quarto.org/docs/interactive/")[インタラクティブな機能];を実現したブログを作ってみたい．

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
)
]
== YAML Header
<yaml-header>
各ファイルの冒頭に YAML block を用意することで，ノートブックの詳細を調整できる（参照：#link("https://quarto.org/docs/reference/formats/html.html")[HTML Options];）．

例えば本ページでは次のとおり：

```yaml
---
title: "Quarto はじめて良かった"
author: "司馬博文"
date: "11/4/2023"
date-modified: "7/7/2024"
categories: [Lifestyle]
abstract: Quarto は TeX のような使用感で，数式とコードが併存する文章を書き，１つのソースファイルから PDF, HTML, Word, Reveal.js, PowerPoint などの多様な形式に出力できる次世代の執筆環境である．TeX, RStudio, Jupyter Notebook のいずれかに慣れている人であれば，極めて手軽に Quarto を使うことができる．
abstract-title: 概要
format:
  html:
    mainfont: "Gill Sans"
    theme: minty
    css: styles.css
    toc: true
    number-sections: true
    highlight-style: ayu
    code-block-border-left: "#7CC4AC"
    code-overflow: scroll
    toc-title: "目次"
    abstract-title: "概要"
---
```

== 本文の書き方
<本文の書き方>
=== 数式
<数式>
本文は markdown 記法で書く．数式も使える： $ "P" [\| xi \| < t] lt.eq 2 e^(- frac(t^2, 2 sigma^2)) , #h(2em) t > 0 . $

=== コード
<コード>
また，コードブロックにもコメントアウトと接頭辞の組み合わせ `#|` を前につけることでYAMLで指示が出せる（参照：#link("https://quarto.org/docs/reference/cells/cells-jupyter.html")[指示のリスト];）．上のコードブロックには

```yaml
#| label: fig-polar
#| fig-cap: "A line plot on a polar axis"
```

と追加されているために，出力された図にラベリングとキャプションが付いているのである．

```zsh
pip3 install jupyter-cache
```

が必要であることに注意．

= Website の作り方
<website-の作り方>
#link("https://quarto.org/docs/publishing/github-pages.html")[公式 Guide] を参考．

== Source Branchを`main`と別ける
<source-branchをmainと別ける>
まず`gh-pages`という全く新しいブランチを作成する．既存のリポジトリのコミット履歴とは独立している新しいブランチを作るときは`--orphan`オプションが利用される．

```bash
git checkout --orphan gh-pages
git reset --hard # make sure all changes are committed before running this!
git commit --allow-empty -m "Initialising gh-pages branch"
git push origin gh-pages
git checkout main
```

基本`gh-pages`ブランチには自分では立ち入らない．

== `Publish`コマンドによるサイトの公開
<publishコマンドによるサイトの公開>
`main`ブランチにいることを確認して，

```bash
quarto publish gh-pages
```

を実行．

GitHubの方の設定#strong[Settings: Pages];で，Sourceを`gh-pages`ブランチの`/(root)`にしていることを確認すれば，これで無事サイトが公開されていることが確認できる．

== GitHub Action の使用
<github-action-の使用>
さらに，ローカル上で`render`するのではなく，コミットする度にGitHub上でレンダリングしてもらえるように自動化することもできる．こうするとスマホからも自分のサイトが更新できる．

まず，GitHubの設定の#strong[Actions];セクションの#strong[Workflow permissions];から，読み書きの権限をGitHub Actionに付与する．

続いて，次の内容のファイルを`.github/workflows/publish.yml`に書き込む：

```yml
on:
  workflow_dispatch:
  push:
    branches: main

name: Quarto Publish

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up Quarto
        uses: quarto-dev/quarto-actions/setup@v2
        with:
          tinytex: true  # https://github.com/quarto-dev/quarto-actions/tree/main/setup
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # Setting GH_TOKEN is recommended as installing TinyTeX will query the github API.

      - name: Render and Publish
        uses: quarto-dev/quarto-actions/publish@v2
        with:
          target: gh-pages
          # render: false  # https://quarto.org/docs/publishing/github-pages.html#additional-options
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

途中，`tinytex: true` とすることで，１つのページを HTML と pdf の両方で閲覧可能になる．本ブログでは，#link("https://162348.github.io/static/CV/cv.html")[CV のページ] でこの機能を使っている．

これで，`main`ブランチにコミットする度に，GitHub上で`render`が実行されることとなる．

= PDF の作り方
<pdf-の作り方>
== LuaLaTeX を使う方法
<lualatex-を使う方法>
LuaLaTeX を利用することで日本語を含んだ PDF を作成できる．

```qmd
title: "タイトル"
author: 司馬博文
date: 2023/12/11
format:
  pdf:
    toc: true
    number-sections: true
    urlcolor: minty
    template-partials: 
      - ../../../before-title.tex
    keep-tex: true
    block-headings: false
    pdf-engine: lualatex
    documentclass: ltjsarticle
```

=== LuaLaTeX の注意
<lualatex-の注意>
```latex
\int_{\mathbb{R}}
```

のような記法は，pdfLaTeX ではなぜかコンパイルが通るが，LuaLaTeX （や殆どの pdfLaTeX 以外のエンジン）ではエラーになる．

=== LuaLaTeX の欠点
<lualatex-の欠点>
`ltjsarticle` クラスでは

```zsh
Font \JY3/mc/m/n/10=file:HaranoAjiMincho-Regular.otf:-kern;jfm=ujis at 9.24713pt not loadable: metric data not found or bad.
<to be read again> 
relax 
l.79 \kanjiencoding{JY3}\selectfont
                                 \adjustbaseline
```

というエラーが．一方で，`bxjsarticle` クラスでは

```zsh
LaTeX Error: File `haranoaji.sty' not found.

Type X to quit or <RETURN> to proceed,
or enter new name. (Default extension: sty)

Enter file name: 
! Emergency stop.
<read *>
```

というエラーが出る．

ローカルではインストールすれば良いだけであるが，これを GitHub Actions 上で実現する方法を考えあぐねていた．

#block[
#callout(
body: 
[
年度を跨いだ TeX Live manager のアップデートは，次のようにする必要がある：

```zsh
wget http://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.sh
chmod +x update-tlmgr-latest.sh
sudo ./update-tlmgr-latest.sh
```

]
, 
title: 
[
注（TeX Live のアップデート方法）
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
)
]
=== `GitHub Actions` の修正
<github-actions-の修正>
次のようにして，Set up Quarto と Render and Publish の間に，TinyTeX と haranoaji.sty のインストールを使いすることで，GitHub 上でもレンダリングが可能になる．

`{yml filename="publish.yml"} - name: 'Install TinyTeX'  # https://github.com/quarto-dev/quarto-actions/tree/main/setup   env:     QUARTO_PRINT_STACK: true     GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # Setting GH_TOKEN is recommended as installing TinyTeX will query the github API.   run: |     quarto install tool tinytex --log-level warning     case $RUNNER_OS in        "Linux")           echo "$HOME/bin" >> $GITHUB_PATH           export PATH="$HOME/bin:$PATH"           ;;        "macOS")           TLMGR_PATH=$(dirname $(find ~/Library/TinyTeX -name tlmgr))           echo $TLMGR_PATH >> $GITHUB_PATH           export PATH="$TLMGR_PATH:$PATH"           ;;        "Windows")           TLMGR_PATH=$(dirname $(find $APPDATA/TinyTeX -name tlmgr.bat))           echo $TLMGR_PATH >> $GITHUB_PATH           export PATH="$TLMGR_PATH:$PATH"           ;;         *)           echo "$RUNNER_OS not supported"           exit 1           ;;     esac     echo "TinyTeX installed !"     tlmgr install haranoaji   # Install haranoaji.sty   shell: bash`

=== ローカルの TinyTeX に haranoaji.sty をインストールする方法
<ローカルの-tinytex-に-haranoaji.sty-をインストールする方法>
```zsh
tlmgr install haranoaji
```

だと，すでに TeX Live がローカルに存在する場合は，そちらにインストールされてしまう．

```zsh
quarto install tinytex
```

でインストールされる TinyTeX は，ホームディレクトリ下の `~/Liberary/TinyTeX/` にインストールされる．#footnote[MaxOS では．]

そこの，`tlmgr` がインストールされている場所まで行って，

```zsh
tlmgr install haranoaji
```

を実行すると良い．

だが，まだ見つからないと言われる……

```zsh
❯ ./tlmgr install haranoaji        
tlmgr: package repository https://mirror.las.iastate.edu/tex-archive/systems/texlive/tlnet/ (verified)
[1/1, ??:??/??:??] install: haranoaji [25570k]
running mktexlsr ...
done running mktexlsr.
tlmgr: package log updated: ~/Library/TinyTeX/texmf-var/web2c/tlmgr.log
tlmgr: command log updated: ~/Library/TinyTeX/texmf-var/web2c/tlmgr-commands.log
```

== Typst を用いる方法
<typst-を用いる方法>
#link("https://typst.app/")[HP]

使うフォントは次のように，#link("https://fonts.google.com/specimen/BIZ+UDPGothic")[Google Fonts] を通じて，GitHub Actions 上でインストールすることもできるだろう：

```zsh
wget https://github.com/google/fonts/raw/main/ofl/bizudpgothic/BIZUDPGothic-Regular.ttf
wget https://github.com/google/fonts/raw/main/ofl/bizudpgothic/BIZUDPGothic-Bold.ttf
```

= スライドの作り方
<スライドの作り方>



