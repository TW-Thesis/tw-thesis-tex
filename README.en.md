# tw-thesis-tex

English | [繁體中文](README.md)

![LaTeX](https://img.shields.io/badge/made%20with-LaTeX-008080?style=flat-square&logo=latex&logoColor=white) ![schools](https://img.shields.io/badge/schools-15-4b69c6?style=flat-square) ![i18n](https://img.shields.io/badge/tutorial-zh--Hant%20%7C%20en-4b69c6?style=flat-square) [![license](https://img.shields.io/badge/license-MIT-4b69c6?style=flat-square)](LICENSE)

TW-Thesis provides a [LaTeX](https://www.latex-project.org) template for master's and doctoral theses at major universities in Taiwan. It includes format presets for 15 schools. The tutorial is also a working sample thesis, so you can compile it, copy what you need, and change it into your own thesis. The Typst version is [tw-thesis-typ](https://github.com/TW-Thesis/tw-thesis-typ); both versions read the same `config.yml` and `schools/`, so switching typesetting engines does not mean re-entering your data.

> **Disclaimer**: The format presets in this template are for reference only. Always follow your school's official thesis regulations and your department's requirements.

## Getting started

Follow the steps below to go from nothing to your first PDF. It takes about ten minutes.

### Install LaTeX and Python

The template is compiled with XeLaTeX, and it uses Python 3 to turn `config.yml` into LaTeX macros (LaTeX cannot read YAML). Choose one way to install a LaTeX distribution for your system. `brew` and `winget` need to be installed first.

```bash
brew install --cask mactex-no-gui   # macOS
winget install --id MiKTeX.MiKTeX   # Windows
sudo apt install texlive-full       # Debian / Ubuntu
```

The lighter [TinyTeX](https://yihui.org/tinytex/) works too. After installing, check that it works and install the Python YAML package:

```bash
xelatex --version
python3 -m pip install pyyaml
```

References are handled by the `citation-style-language` package and its `citeproc-lua`, so `.bib`, Hayagriva `.yml`, CSL JSON/YAML and any `.csl` style all work. A full TeX Live already includes it; with TinyTeX or a partial install, run `tlmgr install citation-style-language`.

This template was developed and tested with TeX Live 2025, so we recommend using the same version or a newer one.

### Get the project

This repository is a GitHub **template repository**. Please use **Use this template** to create your own thesis project:

1. Click the green **Use this template** button at the top right, then choose **Create a new repository**.
2. Enter a name for the project (for example, `my-thesis`). We recommend setting the visibility to **Private**.
3. When the repository is created, clone it to your computer:

```bash
git clone https://github.com/<your-account>/my-thesis.git
cd my-thesis
```

If you have the [GitHub CLI](https://cli.github.com), one command creates the repository and clones it:

```bash
gh repo create my-thesis --template TW-Thesis/tw-thesis-tex --private --clone
cd my-thesis
```

A project created from a template is a **brand-new repository**. It has only one initial commit, does not contain the template's history, and is not linked to this repository. Later updates to the template are not applied to your project automatically. When you want them, you can compare with the new version and copy over the parts you need.

If you do not use GitHub, you can also choose **Code → Download ZIP** on this page and unzip it.

Run all the commands below from the **project root**, which is the folder that contains both `main.tex` and `config.yml`.

### Compile

Once you have the project on your computer, try compiling it:

```bash
python3 scripts/gen.py
latexmk -xelatex main.tex
```

The first line reads `config.yml` and `schools/`, writes the private `.tw-thesis-config.tex` and converts Hayagriva bibliographies to CSL JSON; repeat it after every change to the config or the bibliography. The second line is the compile, and a `main.pdf` file will appear in the project root. Open it and check that the cover page, the table of contents and the body text all display correctly, including the Chinese and English fonts.

- The fonts that come with the project (EB Garamond, Tinos and the Ministry of Education Standard Kai typeface) sit in `fonts/` and are loaded by file from `tw-thesis.cls`, so you do not need to install them on your system.
- `latexmk` reruns XeLaTeX as often as needed and calls `citeproc-lua` after every pass, so the table of contents, cross-references and bibliography all resolve.
- When the build succeeds the terminal prints nothing; only errors are shown, with the file and line. The temporary files of the build live in the hidden `.tw-thesis-build/`, so the project root only gains a `main.pdf`. To see everything latexmk prints, set the environment variable `TW_VERBOSE=1`.

### Fill in your information

Open `config.yml` in any text editor. Replace the title, name, department and date with your own, and uncomment the `school` line with your school's code:

```yaml
school: nccu              # uses schools/nccu.yml; see "Supported schools" below

title: "Thesis title in Chinese"
title-en: "A Study on Consistency in Distributed Systems"

author: "Author name in Chinese"
author-en: "Wang, Xiao-Ming"
advisor: "Advisor name in Chinese"
advisor-en: "Chen, Da-Wen"

institute: "Department name in Chinese"
institute-en: "Department of Computer Science"

date: "2027-01-15"        # date on the cover, in YYYY-MM-DD format
```

The fields without `-en` hold the Chinese text, so replace the placeholders above with your Chinese title, name, advisor and department. The fields ending in `-en` hold the English text. Fill in both, or the cover page will be missing one of the languages. Compile again and check the cover page and the verification page. When you choose a school, the format (margins, font sizes, cover style and so on) follows that school's preset. If you do not choose one, the default format is used.

If you want to change a setting that the school preset does not cover, for example setting only the top margin to 3.5 cm, just write it in `config.yml`. It has the highest priority, so you do not have to edit anything in `schools/`. Every available setting and its unit is documented in `schools/default.yml`.

### Write your thesis

The content of your thesis is in `contents/`, organised like this:

```text
contents/
├── front/           abstract, acknowledgements, list of symbols, etc.
├── chapter01.tex    the chapters start here
├── chapter02.tex
├── chapter03.tex
├── chapter04.tex
├── back/            appendices and the bibliography
└── i18n/en/         English version of the tutorial
```

When you first copy the project, these files contain the tutorial. They are also examples you can learn from.

The order of the chapters is set in `main.tex`. To add or remove a chapter, add or delete the matching `\input` line:

```latex
\input{contents/chapter01}
\input{contents/chapter02}
```

References go in `contents/back/references.bib`. In the text, cite an entry by its key (you can also use a Hayagriva `.yml` or a CSL file instead; see Chapter 4 of the tutorial). For example, `references.bib` contains an entry called `kocher99`:

```latex
\citep{kocher99}
```

The English version of the tutorial is in `contents/i18n/en/`. It is not part of your thesis. To see it as a document of its own, with English prefixes (Figure, Table, Chapter, Section), run `make compile-en`.

### Edit and preview

If you want to see the result while you write, use watch mode. The PDF is rebuilt every time you save a file:

```bash
make watch
```

The output of watch mode is as concise as `typst watch`: each save shows `compiling ...` and `compiled successfully`, errors are listed with their file and line, and once you fix them it goes quiet again.

If you use VS Code, install the [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop) extension and choose the `latexmk` (XeLaTeX) recipe to preview the document directly.

If your school requires a watermark when you submit, first set the watermark image in the configuration file (this is explained in Chapter 2 of the tutorial), then compile with the following commands:

```bash
python3 scripts/gen.py
latexmk -g -xelatex -usepretex='\def\twwatermark{1}' main.tex
```

If you have `make` or [`just`](https://github.com/casey/just) installed, the commands above can be shortened to:

```bash
make           # normal build
make watch     # rebuild every time you save
make release   # build with the watermark
make clean     # delete main.pdf and the build leftovers
```

To use `just`, replace `make` in the commands above with `just`.

## Supported schools

| Code | University | Chinese name | Regulation version |
|---|---|---|---|
| [`ntu`](schools/ntu.yml) | National Taiwan University | 國立臺灣大學 | [20 Oct 2023](docs/國立臺灣大學-1121020-碩博士論文規範.pdf) |
| [`nthu`](schools/nthu.yml) | National Tsing Hua University | 國立清華大學 | [29 May 2025](docs/國立清華大學-1140529-碩博士論文規範.pdf) |
| [`nycu`](schools/nycu.yml) | National Yang Ming Chiao Tung University | 國立陽明交通大學 | [17 Sep 2026](docs/國立陽明交通大學-1150917-碩博士論文規範.pdf) |
| [`ncku`](schools/ncku.yml) | National Cheng Kung University | 國立成功大學 | [6 Jan 2021](docs/國立成功大學-1100106-碩博士論文規範.pdf) |
| [`nccu`](schools/nccu.yml) | National Chengchi University | 國立政治大學 | [23 Dec 2024](docs/國立政治大學-1131223-碩博士論文規範.pdf) |
| [`ntpu`](schools/ntpu.yml) | National Taipei University | 國立臺北大學 | [16 Aug 2022](docs/國立臺北大學-1110816-碩博士論文規範.pdf) |
| [`ntnu`](schools/ntnu.yml) | National Taiwan Normal University | 國立臺灣師範大學 | [5 Mar 2025](docs/國立臺灣師範大學-1140305-碩博士論文規範.pdf) |
| [`nknu`](schools/nknu.yml) | National Kaohsiung Normal University | 國立高雄師範大學 | [24 Aug 2021](docs/國立高雄師範大學-1100824-碩博士論文規範.pdf) |
| [`ncue`](schools/ncue.yml) | National Changhua University of Education | 國立彰化師範大學 | [15 Dec 2021](docs/國立彰化師範大學-1101215-碩博士論文規範.pdf) |
| [`ncu`](schools/ncu.yml) | National Central University | 國立中央大學 | [27 Jan 2016](docs/國立中央大學-1050127-碩博士論文規範.pdf) |
| [`nsysu`](schools/nsysu.yml) | National Sun Yat-sen University | 國立中山大學 | [15 Mar 2022](docs/國立中山大學-1110315-碩博士論文規範.pdf) |
| [`nchu`](schools/nchu.yml) | National Chung Hsing University | 國立中興大學 | [21 Apr 2022](docs/國立中興大學-1110421-碩博士論文規範.pdf) |
| [`ccu`](schools/ccu.yml) | National Chung Cheng University | 國立中正大學 | [Jan 2001](docs/國立中正大學-0900100-碩博士論文規範.pdf) |
| [`ntou`](schools/ntou.yml) | National Taiwan Ocean University | 國立臺灣海洋大學 | [6 Aug 2025](docs/國立臺灣海洋大學-1140806-碩博士論文規範.pdf) |
| [`nuk`](schools/nuk.yml) | National University of Kaohsiung | 國立高雄大學 | [26 Aug 2016](docs/國立高雄大學-1050826-碩博士論文規範.pdf) |

The official regulation PDFs are stored in [`docs/`](docs/). The beginning of each preset file states which regulation it follows and which items are not supported yet.

## Project structure

| Path | Purpose |
|---|---|
| `config.yml` | Your thesis information and settings |
| `main.tex` | Binding order: front matter, chapters, references, appendices |
| `contents/` | Thesis content (the tutorial chapters are the sample) |
| `schools/` | Format presets for each school; `default.yml` is the only source of default values |
| `i18n/` | Wording that depends on the language (Chinese and English) |
| `scripts/` | The Python program that turns `config.yml` into LaTeX macros |
| `tw-thesis.cls`, `tw-thesis.sty` | The template itself: the document class plus tools for figures, tables and code |
| `Makefile`, `justfile`, `latexmkrc` | Build commands; `latexmkrc` sets up XeLaTeX, `citeproc-lua` and the output format |
| `fonts/`, `assets/`, `docs/` | Fonts, watermarks and each school's regulation PDFs |

## Contributing

New schools, format fixes and improvements to the tutorial are all welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

The code and the tutorial text are released under the [MIT license](LICENSE). Fonts, school emblems and the schools' regulation documents are not covered by this license. See [THIRD_PARTY.md](THIRD_PARTY.md) for details.
