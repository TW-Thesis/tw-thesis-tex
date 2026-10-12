# Third-party material

The MIT license in `LICENSE` covers this project's own work: the template
code (`tw-thesis.cls`, `tw-thesis.sty`, `scripts/`, `schools/`, `i18n/`, `main.tex`), the tutorial
text in `contents/`, and the sample figures in `figures/`. The files below are
not the author's and keep their own terms.

## Fonts (`fonts/`)

| Files | License | Notes |
|---|---|---|
| `fonts/english/EBGaramond/` | SIL Open Font License 1.1 (`OFL.txt` beside the files) | (c) 2017 The EB Garamond Project Authors. The four static styles were generated from the official variable fonts; no glyphs were changed. |
| `fonts/english/Tinos/` | SIL Open Font License 1.1 (`OFL.txt` beside the files) | (c) 2026 The Tinos Project Authors. Metrically compatible with Times New Roman. |
| `fonts/chinese/edukai-5.1.ttf` | Creative Commons Attribution-NoDerivs 3.0 Taiwan | TW-MOE-Std-Kai. Redistributable only unchanged and in whole, with credit to the Ministry of Education, R.O.C. |

## School material

- `docs/*.pdf` are the universities' own thesis-format regulations, fetched
  from their public websites. The copyright belongs to each school.
- `assets/watermarks/*` are university emblems. They are the property of the
  respective universities and are included only so that a thesis can carry its
  own school's watermark; the MIT license does not grant any right to them.

## LaTeX packages

Nothing from CTAN is bundled. The class loads standard packages (`ctex`, `fontspec`, `geometry`, `titlesec`, `titletoc`, `fancyhdr`, `caption`, `booktabs`, `listings`, `citation-style-language` (with its `citeproc-lua` and the CSL styles and locales it ships), `hyperref`, ...) that come with a TeX distribution, each under its own license.

## Fonts installed from a system

Times New Roman (Monotype) is a commercial system font. It is **not** bundled with this repository, and the MIT license does not cover it. If you list `"Times New Roman"` in `layout.font-latin`, the template uses the copy installed on your own computer. Do not commit copies of it (`.gitignore` already skips `fonts/english/Times New Roman*.ttf`).
