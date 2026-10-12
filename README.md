# tw-thesis-tex

[English](README.en.md) | 繁體中文

![LaTeX](https://img.shields.io/badge/made%20with-LaTeX-008080?style=flat-square&logo=latex&logoColor=white) ![schools](https://img.shields.io/badge/schools-15-4b69c6?style=flat-square) ![i18n](https://img.shields.io/badge/tutorial-zh--Hant%20%7C%20en-4b69c6?style=flat-square) [![license](https://img.shields.io/badge/license-MIT-4b69c6?style=flat-square)](LICENSE)

TW-Thesis 提供臺灣主要大學碩博士論文的 [LaTeX](https://www.latex-project.org) 模板。內建 15 所學校的格式設定，教學文件本身就是可以編譯的範例，可以直接按照範例修改，以符合學校格式的論文。Typst 版本見 [tw-thesis-typ](https://github.com/TW-Thesis/tw-thesis-typ)；兩個版本共用同一份 `config.yml` 與 `schools/`，換排版引擎不必重填資料。

> **免責聲明**：模板的格式設定僅供參考，實際仍請以學校公布的論文規範及系所要求為準。

## 快速開始

將本專案 clone 下來後，建議按照以下步驟從零開始到編譯出第一份 PDF，耗時約十分鐘。

### 安裝 LaTeX 與 Python

這份模板使用 XeLaTeX 編譯，並用 Python 3 把 `config.yml` 轉成 LaTeX 巨集（LaTeX 讀不了 YAML）。依系統選一種方式安裝 LaTeX 發行版（`brew`、`winget` 需要先有對應的套件管理工具）：

```bash
brew install --cask mactex-no-gui   # macOS
winget install --id MiKTeX.MiKTeX   # Windows
sudo apt install texlive-full       # Debian / Ubuntu
```

也可以改用較輕量的 [TinyTeX](https://yihui.org/tinytex/)。裝好後確認能執行，並安裝 Python 的 YAML 套件：

```bash
xelatex --version
python3 -m pip install pyyaml
```

參考文獻由 `citation-style-language` 套件與它的 `citeproc-lua` 處理，所以 `.bib`、Hayagriva `.yml`、CSL JSON／YAML 與任何 `.csl` 樣式都能使用。完整的 TeX Live 已經內含；TinyTeX 或只裝部分套件時，執行 `tlmgr install citation-style-language`。

這份模板以 TeX Live 2025 開發與測試，建議使用同一版或更新的版本。

### 取得專案

這個 repo 是 GitHub 的**範本儲存庫（template repository）**，請用 **Use this template** 建立你自己的論文專案：

1. 點擊右上角綠色的 **Use this template** 按鈕，選擇 **Create a new repository**。
2. 填入專案名稱（例如 `my-thesis`），可見度建議選 **Private**。
3. 建立完成後，把你的新專案 clone 到本機：

```bash
git clone https://github.com/<你的帳號>/my-thesis.git
cd my-thesis
```

已安裝 [GitHub CLI](https://cli.github.com) 的話，一行指令即可完成建立與 clone：

```bash
gh repo create my-thesis --template TW-Thesis/tw-thesis-tex --private --clone
cd my-thesis
```

用範本建立的專案是**全新的版本庫**：只有一個初始提交，不含模板的歷史紀錄，也不會與本 repo 有任何關聯。模板日後的更新不會自動套用到你的專案，需要時可以自行比對新版，再挑選要採用的部分。

若不使用 GitHub 的話，也可以在本頁選擇 **Code → Download ZIP**，解壓縮後進入資料夾即可。

後續所有指令都請在**專案根目錄**執行，也就是同時含有 `main.tex` 與 `config.yml` 的資料夾。

### 編譯

建立專案並 clone 後，可以嘗試編譯：

```bash
python3 scripts/gen.py
latexmk -xelatex main.tex
```

第一行讀取 `config.yml` 與 `schools/`，產生私有的 `.tw-thesis-config.tex`，並把 Hayagriva 文獻檔轉成 CSL JSON；修改設定檔或文獻檔後都要重新執行一次。第二行才是編譯，完成後根目錄會出現 `main.pdf`。打開它，確認封面、目次與內文的中英文字型等內容均可正常顯示。

- 專案附帶的字型（EB Garamond、Tinos、教育部標準楷書）放在 `fonts/`，由 `tw-thesis.cls` 直接依檔案載入，不必另外安裝到系統。
- `latexmk` 會依需要自動重跑 XeLaTeX，並在每次編譯後呼叫 `citeproc-lua`，讓目次、交叉引用與參考文獻都解開。
- 編譯成功時終端機不會輸出任何東西，有錯誤才會顯示錯誤的檔案與行號。編譯過程的暫存檔都放在隱藏的 `.tw-thesis-build/`，根目錄只會多一個 `main.pdf`。想看 latexmk 的完整輸出，可以設定環境變數 `TW_VERBOSE=1`。

### 填入資訊

用任何文字編輯器打開根目錄的 `config.yml`，把題目、姓名、系所、日期換成自己的，並取消註解、填上學校代碼：

```yaml
school: nccu              # 對應 schools/nccu.yml，代碼見下方「內建學校」

title: "分散式系統的一致性研究"
title-en: "A Study on Consistency in Distributed Systems"

author: "王小明"
author-en: "Wang, Xiao-Ming"
advisor: "陳大文"
advisor-en: "Chen, Da-Wen"

institute: "資訊科學系"
institute-en: "Department of Computer Science"

date: "2027-01-15"        # 封面上的日期，格式 YYYY-MM-DD
```

中英文欄位都要填，不然封面會缺其中一種語言。存檔後重新編譯，檢查封面與審定書；選了學校，格式（邊界、字級、封面樣式等）就會換成該校的設定，沒選則使用預設格式。

想改的設定不在學校預設裡（例如只把上邊界改成 3.5 公分），直接寫進 `config.yml` 即可，它的優先順序最高，不必動 `schools/`。每個可用設定與單位都寫在 `schools/default.yml`。

### 撰寫論文

論文的內容都在 `contents/`，結構如下：

```text
contents/
├── front/           摘要、致謝、符號列表等
├── chapter01.tex    以下為各章內容
├── chapter02.tex
├── chapter03.tex
├── chapter04.tex
├── back/            附錄與參考文獻
└── i18n/en/         英文版教學
```

初次複製下來的檔案內是教學內容，也是可以參考的範例。

各章的順序由 `main.tex` 決定。多一章或少一章，就在裡面加或刪對應的那一行 `\input` 即可：

```latex
\input{contents/chapter01}
\input{contents/chapter02}
```

參考文獻寫在 `contents/back/references.bib`（也可以改用 Hayagriva `.yml` 或 CSL 檔，見教學第四章），內文用識別名稱引用，例如 `references.bib` 裡有一筆 `kocher99`：

```latex
\citep{kocher99}
```

英文版教學放在 `contents/i18n/en/`，不屬於你的論文。想單獨看它的成品（圖表與章節前綴為 Figure、Table、Chapter、Section），執行 `make compile-en`。

### 編輯與預覽

想邊寫邊看結果，可以開監看模式，存檔就會自動重新編譯，PDF 也會跟著更新：

```bash
make watch
```

監看模式的輸出跟 `typst watch` 一樣簡潔：每次存檔顯示 `compiling ...` 與 `compiled successfully`，有錯誤才會列出檔案與行號，修好後就恢復安靜。

用 VS Code 的話，安裝 [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop) 擴充套件，並在它的編譯流程中選用 `latexmk`（XeLaTeX），就能直接預覽。

交稿如果需要浮水印，要先在設定檔指定浮水印圖片（第二章有寫），再用下面的指令編譯：

```bash
python3 scripts/gen.py
latexmk -g -xelatex -usepretex='\def\twwatermark{1}' main.tex
```

若有安裝 `make` 或 [`just`](https://github.com/casey/just)，上面流程可以縮短為：

```bash
make           # 一般編譯
make watch     # 存檔就重新編譯
make release   # 加上浮水印
make clean     # 刪掉 main.pdf 與暫存檔
```

使用 `just` 時，將上面的 `make` 換成 `just` 即可。

## 內建學校

| 代碼 | 學校 | 英文名稱 | 規範版本 |
|---|---|---|---|
| [`ntu`](schools/ntu.yml) | 國立臺灣大學 | National Taiwan University | [民國 112 年 10 月 20 日](docs/國立臺灣大學-1121020-碩博士論文規範.pdf) |
| [`nthu`](schools/nthu.yml) | 國立清華大學 | National Tsing Hua University | [民國 114 年 5 月 29 日](docs/國立清華大學-1140529-碩博士論文規範.pdf) |
| [`nycu`](schools/nycu.yml) | 國立陽明交通大學 | National Yang Ming Chiao Tung University | [民國 115 年 9 月 17 日](docs/國立陽明交通大學-1150917-碩博士論文規範.pdf) |
| [`ncku`](schools/ncku.yml) | 國立成功大學 | National Cheng Kung University | [民國 110 年 1 月 6 日](docs/國立成功大學-1100106-碩博士論文規範.pdf) |
| [`nccu`](schools/nccu.yml) | 國立政治大學 | National Chengchi University | [民國 113 年 12 月 23 日](docs/國立政治大學-1131223-碩博士論文規範.pdf) |
| [`ntpu`](schools/ntpu.yml) | 國立臺北大學 | National Taipei University | [民國 111 年 8 月 16 日](docs/國立臺北大學-1110816-碩博士論文規範.pdf) |
| [`ntnu`](schools/ntnu.yml) | 國立臺灣師範大學 | National Taiwan Normal University | [民國 114 年 3 月 5 日](docs/國立臺灣師範大學-1140305-碩博士論文規範.pdf) |
| [`nknu`](schools/nknu.yml) | 國立高雄師範大學 | National Kaohsiung Normal University | [民國 110 年 8 月 24 日](docs/國立高雄師範大學-1100824-碩博士論文規範.pdf) |
| [`ncue`](schools/ncue.yml) | 國立彰化師範大學 | National Changhua University of Education | [民國 110 年 12 月 15 日](docs/國立彰化師範大學-1101215-碩博士論文規範.pdf) |
| [`ncu`](schools/ncu.yml) | 國立中央大學 | National Central University | [民國 105 年 1 月 27 日](docs/國立中央大學-1050127-碩博士論文規範.pdf) |
| [`nsysu`](schools/nsysu.yml) | 國立中山大學 | National Sun Yat-sen University | [民國 111 年 3 月 15 日](docs/國立中山大學-1110315-碩博士論文規範.pdf) |
| [`nchu`](schools/nchu.yml) | 國立中興大學 | National Chung Hsing University | [民國 111 年 4 月 21 日](docs/國立中興大學-1110421-碩博士論文規範.pdf) |
| [`ccu`](schools/ccu.yml) | 國立中正大學 | National Chung Cheng University | [民國 90 年 1 月](docs/國立中正大學-0900100-碩博士論文規範.pdf) |
| [`ntou`](schools/ntou.yml) | 國立臺灣海洋大學 | National Taiwan Ocean University | [民國 114 年 8 月 6 日](docs/國立臺灣海洋大學-1140806-碩博士論文規範.pdf) |
| [`nuk`](schools/nuk.yml) | 國立高雄大學 | National University of Kaohsiung | [民國 105 年 8 月 26 日](docs/國立高雄大學-1050826-碩博士論文規範.pdf) |

各校的官方規範 PDF 收在 [`docs/`](docs/)，每個設定檔開頭都註明依據的規範與尚未支援的項目。

## 專案結構

| 路徑 | 用途 |
|---|---|
| `config.yml` | 論文資料與設定 |
| `main.tex` | 裝訂順序：前置、各章、參考文獻、附錄 |
| `contents/` | 論文內容（教學章節即範例） |
| `schools/` | 各校格式；`default.yml` 是唯一的預設值來源 |
| `i18n/` | 其他語言範例檔 |
| `scripts/` | 把 `config.yml` 轉成 LaTeX 巨集的 Python 程式 |
| `tw-thesis.cls`、`tw-thesis.sty` | 模板本體：文件類別，以及圖片、表格、程式碼等工具 |
| `Makefile`、`justfile`、`latexmkrc` | 編譯指令；`latexmkrc` 設定 XeLaTeX、`citeproc-lua` 與輸出格式 |
| `fonts/`、`assets/`、`docs/` | 字型、浮水印、各校規範 PDF |

## 貢獻

歡迎新增學校、修正格式、改善教學。請先看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 授權

程式與教學文字採 [MIT](LICENSE)。字型、校徽與各校規範文件不在此授權範圍內，詳見 [THIRD_PARTY.md](THIRD_PARTY.md)。
