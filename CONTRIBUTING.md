# 參與貢獻

謝謝你願意幫忙！這個模板的價值在於「格式正確」，所以最有用的貢獻通常是：新增學校、修正某校的格式、指出規範已經改了。

## 回報問題

到 Issues 選擇對應的表單：

- **格式問題**：排版跟學校規範對不上。請附上學校代碼、規範的條文（或頁碼），以及編譯後的截圖。
- **新增學校**：請附學校官方論文格式規範的網址。
- **規範更新**：學校改了規範，請附新版的網址與日期。

請不要在公開 Issue 貼含個人資料的論文內容。

## 新增一所學校

1. 在 `schools/` 建立 `<代碼>.yml`（代碼用學校英文縮寫小寫，如 `ntu`）。必填 `university` 與 `university-en`，其餘**只寫和 `schools/default.yml` 不同的項目**；`default.yml` 記載每個 key 與單位。
2. 檔案開頭用註解寫明依據的規範 PDF 與網址，以及「尚未支援」的項目，可參考 `schools/nccu.yml`。
3. 把規範 PDF 放進 `docs/`，檔名 `國立○○大學-<民國年月日>-碩博士論文規範.pdf`。
4. 需要浮水印的話，放進 `assets/watermarks/<代碼>.<副檔名>`，並在設定檔的 `watermark.image` 指定。
5. 更新教學第一章的「內建學校代碼」表（中文 `contents/chapter01.tex`，英文 `contents/i18n/en/chapter01.tex`）與 `README.md` 的學校清單。
6. 用該校設定編譯，逐頁對照規範，確認 0 個錯誤：

   ```bash
   texlua scripts/gen.lua && latexmk -xelatex main.tex
   ```

要讓自動提醒涵蓋新學校，還需要到 [tw-thesis-updater](https://github.com/TW-Thesis/tw-thesis-updater) 的 `sources.json` 加上規範網址，這是另一個 repo。

## 修改格式或程式

- 這個 repo 與 [tw-thesis-typ](https://github.com/TW-Thesis/tw-thesis-typ) 共用 `schools/`、`i18n/` 與 `config.yml` 的格式；改動這些檔案的鍵值時，請一併確認另一個版本是否要跟著改。
- 設定的預設值只放在 `schools/default.yml`；新增設定項目時，也要在那裡加上註解說明單位。
- 拼錯的 key 會直接報錯（`scripts/gen.lua` 印出 `unknown key`），這是刻意的，請維持。
- 修改後先在幾所不同學校的設定下編譯，確認沒有讓其他學校跑版。
- 改動排版行為時，請在 PR 說明依據的是哪一條規範。

## 修改教學文件

教學就是範例，所以文中的圖表與範例都會真的被編譯。改完務必重新編譯。

- 中文是正本（`contents/chapter*.tex`）；英文版在 `contents/i18n/en/`，沒有接進 `main.tex`，要看成品請執行 `make compile-en`（入口是 `main-en.tex`，設定是 `contents/i18n/en/config.yml`）。改了中文，請盡量同步英文。
- 程式碼、設定範例與函式名稱不要翻譯；只翻譯說明文字。

## 送出 Pull Request

1. Fork 後建立新分支，一個 PR 只做一件事。
2. commit 訊息用一句話說明「為什麼改」。
3. 確認 `texlua scripts/gen.lua && latexmk -xelatex main.tex` 沒有錯誤。
4. 填寫 PR 範本裡的檢查項目。

## 授權

送出貢獻即表示你同意以本專案的 [MIT 授權](LICENSE) 釋出你的貢獻。若要加入第三方的字型、圖片或文件，請先確認它可以被再散布，並更新 [THIRD_PARTY.md](THIRD_PARTY.md)。
