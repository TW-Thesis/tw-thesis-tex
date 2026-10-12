% tw-thesis.cls -- thesis class for Taiwanese universities.
%
% Page layout, front matter, headings and references live here. Nothing here
% knows which thesis it is typesetting: every number and string comes from
% .tw-thesis-config.tex, which scripts/gen.py writes from config.yml and
% schools/*.yml. The companion package tw-thesis.sty, loaded at the end of this
% class, holds the helpers used in the chapters (figures, tables, code).
% Build with XeLaTeX from the project root (see Makefile).
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{tw-thesis}[2026/10/12 Taiwanese thesis class]

\RequirePackage{iftex}
\RequireXeTeX

% --------------------------------------------------------------------------
% config access
% --------------------------------------------------------------------------
\makeatletter
\def\twcfg#1#2{\expandafter\gdef\csname twc@#1\endcsname{#2}}
\newcommand\twget[1]{\csname twc@#1\endcsname}
\newcommand\twifcfg[3]{\@ifundefined{twc@#1}{#3}{#2}}
% \twgenerated points elsewhere only when the tests build a throwaway thesis
\ifdefined\twgenerated\else\def\twgenerated{.tw-thesis-config.tex}\fi
\IfFileExists{\twgenerated}{\input{\twgenerated}}{%
  \ClassError{tw-thesis}{\twgenerated\space is missing}{%
    Run `python3 scripts/gen.py` (or `make`) in the project root first.}}

\newif\iftw@zh
\def\tw@lang{chinese}
\edef\tw@a{\twget{cfg.layout.language}}
\ifx\tw@a\tw@lang\tw@zhtrue\else\tw@zhfalse\fi
\newif\if@tw@appendix
\@tw@appendixfalse

\LoadClass[a4paper]{report}

\RequirePackage{etoolbox}
% \ifstrequal does not expand its arguments, so \ifstrequal{\twget{k}}{top}
% never matches; this does
\newcommand\twifstr[2]{%
  \ifnum\strcmp{#1}{#2}=\z@\expandafter\@firstoftwo\else\expandafter\@secondoftwo\fi}
\RequirePackage{ifthen}
\RequirePackage{xcolor}
\RequirePackage{graphicx}
\RequirePackage{chngcntr}
\RequirePackage{amsmath,amssymb}
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{enumitem}
\RequirePackage{fancyhdr}
\RequirePackage{eso-pic}
\RequirePackage{tikz}

% --------------------------------------------------------------------------
% page
% --------------------------------------------------------------------------
\edef\tw@geo{%
  \twget{cfg.layout.paper}paper,%
  top=\twget{d.margin.top},bottom=\twget{d.margin.bottom},%
  left=\twget{d.margin.left},right=\twget{d.margin.right},%
  headheight=14pt,headsep=10pt,footskip=\dimexpr\twget{d.margin.bottom}/2\relax}
\expandafter\RequirePackage\expandafter[\tw@geo]{geometry}

% --------------------------------------------------------------------------
% fonts: the first family of each list that can be found is used. The ones
% shipped in fonts/ are matched by name; anything else is looked up on the
% system, like Typst's --font-path fonts/ plus installed fonts.
% --------------------------------------------------------------------------
\RequirePackage[fontset=none,scheme=plain,heading=false]{ctex}
\RequirePackage{fontspec}

\def\tw@latin{}
\def\tw@cjk{}

\newcommand\tw@setlatinfiles[2]{% dir, stem
  \setmainfont{#2-Regular.ttf}[Path=#1/,BoldFont={#2-Bold.ttf},
    ItalicFont={#2-Italic.ttf},BoldItalicFont={#2-BoldItalic.ttf}]}

\newcommand\tw@trylatin[1]{%
  \ifdefempty\tw@latin{%
    \ifstrequal{#1}{EB Garamond}{%
      \IfFileExists{fonts/english/EBGaramond/EBGaramond-Regular.ttf}{%
        \def\tw@latin{#1}\tw@setlatinfiles{fonts/english/EBGaramond}{EBGaramond}}{}}{%
    \ifstrequal{#1}{Tinos}{%
      \IfFileExists{fonts/english/Tinos/Tinos-Regular.ttf}{%
        \def\tw@latin{#1}\tw@setlatinfiles{fonts/english/Tinos}{Tinos}}{}}{%
    \ifstrequal{#1}{Times New Roman}{%
      \IfFileExists{fonts/english/Times New Roman.ttf}{%
        \def\tw@latin{#1}%
        \setmainfont{Times New Roman.ttf}[Path=fonts/english/,
          BoldFont={Times New Roman-Bold.ttf},ItalicFont={Times New Roman-Italic.ttf},
          BoldItalicFont={Times New Roman-BoldItalic.ttf}]}{%
        \IfFontExistsTF{Times New Roman}{\def\tw@latin{#1}\setmainfont{#1}}{}}}{%
      \IfFontExistsTF{#1}{\def\tw@latin{#1}\setmainfont{#1}}{}}}}}{}}

\newcommand\tw@setcjk[2]{% file, path
  \setCJKmainfont{#1}[Path=#2]\setCJKsansfont{#1}[Path=#2]\setCJKmonofont{#1}[Path=#2]}
\newcommand\tw@trycjk[1]{%
  \ifdefempty\tw@cjk{%
    \ifstrequal{#1}{TW-MOE-Std-Kai}{%
      \IfFileExists{fonts/chinese/edukai-5.1.ttf}{%
        \def\tw@cjk{#1}\tw@setcjk{edukai-5.1.ttf}{fonts/chinese/}}{}}{%
      \IfFontExistsTF{#1}{\def\tw@cjk{#1}\setCJKmainfont{#1}\setCJKsansfont{#1}\setCJKmonofont{#1}}{}}}{}}

\newcounter{tw@i}
\newcommand\tw@pickfonts{%
  \setcounter{tw@i}{0}%
  \whiledo{\value{tw@i}<\twget{d.font-latin.n}}{%
    \stepcounter{tw@i}\edef\tw@name{\twget{d.font-latin.\arabic{tw@i}}}%
    \expandafter\tw@trylatin\expandafter{\tw@name}}%
  \setcounter{tw@i}{0}%
  \whiledo{\value{tw@i}<\twget{d.font-cjk.n}}{%
    \stepcounter{tw@i}\edef\tw@name{\twget{d.font-cjk.\arabic{tw@i}}}%
    \expandafter\tw@trycjk\expandafter{\tw@name}}%
  \ifdefempty\tw@latin{\ClassError{tw-thesis}{No Latin font from layout.font-latin found}{}}{}%
  \ifdefempty\tw@cjk{\ClassError{tw-thesis}{No CJK font from layout.font-cjk found}{}}{}}
\tw@pickfonts

% Taiwanese punctuation sits in the middle of the em box
\xeCJKsetup{PunctStyle=plain}
% the placeholder circle is in the CJK font, not the Latin one
\xeCJKDeclareCharClass{CJK}{"2500,"25CB,"25CF,"3007}

% the hair gap a `~` opens up inside a title: 目~次 -> 目 次
\newcommand\twspread{\hspace{\twget{d.title-spread}}}

% --------------------------------------------------------------------------
% text size and line height. baselineskip is line-height x font size; the
% Typst template pins the line box to 1em to get the same thing.
% --------------------------------------------------------------------------
\renewcommand\normalsize{%
  \@setfontsize\normalsize{\twget{d.fs}}{\twget{d.ls}}%
  \abovedisplayskip 8\p@ \@plus2\p@ \@minus4\p@
  \abovedisplayshortskip 4\p@ \@plus1\p@
  \belowdisplayshortskip 4\p@ \@plus1\p@
  \belowdisplayskip \abovedisplayskip
  \let\@listi\@listI}
\renewcommand\small{%
  \@setfontsize\small{\twget{d.fs-small}}{\twget{d.ls-small}}%
  \abovedisplayskip 6\p@ \@plus2\p@ \@minus3\p@
  \belowdisplayskip \abovedisplayskip}
\renewcommand\footnotesize{\@setfontsize\footnotesize{\twget{d.fs-foot}}{\twget{d.ls-foot}}}
\renewcommand\scriptsize{\@setfontsize\scriptsize{\twget{d.fs-foot}}{\twget{d.ls-foot}}}
\def\@listI{\leftmargin\leftmargini \topsep 4\p@ \@plus2\p@ \@minus2\p@
  \parsep 0\p@ \itemsep 2\p@ \@plus1\p@}
\let\@listi\@listI
\renewcommand\baselinestretch{1}
\setlength\parindent{\twget{d.indent}}
\setlength\parskip{\twget{d.parskip}}
\normalsize

\ifnum\twget{d.justify}=1 \else \AtBeginDocument{\raggedright}\fi
\sloppy
\emergencystretch=3em
\setlength\footnotesep{6pt}

% --------------------------------------------------------------------------
% numbering of footnotes, equations, figures, tables
% --------------------------------------------------------------------------
\def\tw@fmt@zhnumber#1{\zhnumber{\arabic{#1}}}
\def\tw@fmt@arabic#1{\arabic{#1}}
\def\tw@fmt@alph#1{\alph{#1}}
\def\tw@fmt@Alph#1{\Alph{#1}}
\def\tw@fmt@roman#1{\roman{#1}}
\def\tw@fmt@Roman#1{\Roman{#1}}
\def\tw@fmt@fnsymbol#1{\fnsymbol{#1}}
\newcommand\tw@fmt[2]{\csname tw@fmt@#1\endcsname{#2}}
\renewcommand\thefootnote{\tw@fmt{\twget{d.footnote-style}}{footnote}}
\ifnum\twget{d.footnote-per-chapter}=1 \counterwithin*{footnote}{chapter}\else
  \counterwithout*{footnote}{chapter}\fi
\ifnum\twget{d.equation-per-chapter}=1
  \counterwithin{equation}{chapter}
  \renewcommand\theequation{\arabic{chapter}.\tw@fmt{\twget{d.equation-style}}{equation}}
\else
  \counterwithout{equation}{chapter}
  \renewcommand\theequation{\tw@fmt{\twget{d.equation-style}}{equation}}
\fi
\counterwithout{figure}{chapter}
\counterwithout{table}{chapter}

\renewcommand\figurename{\twget{d.figure-name}}
\renewcommand\tablename{\twget{d.table-name}}

% --------------------------------------------------------------------------
% headings. Displayed numbers (第一章 / 第一節 / 一、) are built from the
% counters; \thechapter etc. hold the form used in the table of contents.
% --------------------------------------------------------------------------
\RequirePackage{titlesec}
\RequirePackage{titletoc}

\newcommand\tw@appendixpre{\twget{d.appendix.pre}}
\newcommand\tw@appendixpost{\twget{d.appendix.post}}

% level 1
\newcommand\tw@chapnum{%
  \if@tw@appendix\tw@appendixpre\Alph{chapter}\tw@appendixpost
  \else\iftw@zh\twget{d.ch.pre}\zhnumber{\arabic{chapter}}\twget{d.ch.post}%
  \else\twget{d.ch-en}~\arabic{chapter}\fi\fi}
% level 2
\newcommand\tw@secnum{%
  \if@tw@appendix\Alph{chapter}.\arabic{section}%
  \else\iftw@zh\twget{d.se.pre}\zhnumber{\arabic{section}}\twget{d.se.post}%
  \else\twget{d.se-en}~\arabic{section}\fi\fi}
% level 3
\newcommand\tw@subnum{%
  \if@tw@appendix\Alph{chapter}.\arabic{section}.\arabic{subsection}%
  \else\iftw@zh\zhnumber{\arabic{subsection}}\else\arabic{subsection}\fi
    \twget{d.subsection.mark}\fi}

\renewcommand\thechapter{%
  \if@tw@appendix\tw@appendixpre\Alph{chapter}\tw@appendixpost
  \else\iftw@zh\twget{d.ch.pre}\zhnumber{\arabic{chapter}}\twget{d.ch.post}%
  \else\arabic{chapter}\fi\fi}
\renewcommand\thesection{%
  \if@tw@appendix\Alph{chapter}.\arabic{section}%
  \else\iftw@zh\twget{d.se.pre}\zhnumber{\arabic{section}}\twget{d.se.post}%
  \else\arabic{chapter}.\arabic{section}\fi\fi}
\renewcommand\thesubsection{%
  \if@tw@appendix\Alph{chapter}.\arabic{section}.\arabic{subsection}%
  \else\iftw@zh\zhnumber{\arabic{subsection}}\twget{d.subsection.mark}%
  \else\arabic{chapter}.\arabic{section}.\arabic{subsection}\fi\fi}

\setcounter{secnumdepth}{3}
% Typst leaves the paragraph after a heading unindented unless
% layout.first-line-indent-all is set
\ifnum\twget{d.first-line-indent-all}=1
  \def\tw@titlespacing{\titlespacing}
\else
  \def\tw@titlespacing{\titlespacing*}
\fi
\newcommand\tw@head[1]{% level -> font, leading, alignment
  \fontsize{\twget{d.heading.size.#1}}{\twget{d.heading.lead.#1}}\selectfont
  \ifnum\twget{d.heading.bold}=1\bfseries\else\mdseries\fi
  \twget{d.heading.align.#1}}
\titleformat{\chapter}[block]{\tw@head1}{\tw@chapnum}{\twget{d.heading.gap.1}}{}
\titleformat{name=\chapter,numberless}[block]{\tw@head1}{}{0pt}{}
\tw@titlespacing{\chapter}{0pt}{\twget{d.heading.above.1}}{\twget{d.heading.below.1}}
\titleformat{\section}[block]{\tw@head2}{\tw@secnum}{\twget{d.heading.gap.2}}{}
\tw@titlespacing{\section}{0pt}{\twget{d.heading.above.2}}{\twget{d.heading.below.2}}
\titleformat{\subsection}[block]{\tw@head3}{\tw@subnum}{\twget{d.heading.gap.3}}{}
\tw@titlespacing{\subsection}{0pt}{\twget{d.heading.above.3}}{\twget{d.heading.below.3}}
\titleformat{\subsubsection}[block]{\tw@head4}{}{0pt}{}
\tw@titlespacing{\subsubsection}{0pt}{\twget{d.heading.above.4}}{\twget{d.heading.below.4}}
% unnumbered level-1 heading that still appears in the table of contents
\newcommand\twunnumbered[1]{%
  \chapter*{#1}\phantomsection\addcontentsline{toc}{chapter}{#1}}

\renewcommand\appendix{%
  \par\clearpage
  \setcounter{chapter}{0}\setcounter{section}{0}\setcounter{subsection}{0}%
  \@tw@appendixtrue}

% --------------------------------------------------------------------------
% cross-references: \ref{...} to a heading prints 第一章 / 第一章第二節 /
% 第一章第二節第一小節 (or whatever cross-ref: in config.yml says), and
% 附錄 A in an appendix. \figref, \tblref and \lstref add the caption prefix.
% --------------------------------------------------------------------------
\newcount\tw@crlev
\newcommand\twcrC{\tw@fmt{\twget{d.cr.style}}{chapter}}
\newcommand\twcrS{\ifnum\tw@crlev>1 \tw@fmt{\twget{d.cr.style}}{section}\fi}
\newcommand\twcrB{\ifnum\tw@crlev>2 \tw@fmt{\twget{d.cr.style}}{subsection}\fi}

\def\tw@fix@chapter{%
  \tw@crlev=1
  \xdef\@currentlabel{\if@tw@appendix\tw@appendixpre\Alph{chapter}\tw@appendixpost
    \else\twget{d.cr.chapter}\fi}}
\def\tw@fix@section{%
  \tw@crlev=2
  \xdef\@currentlabel{\if@tw@appendix\tw@appendixpre\Alph{chapter}.\arabic{section}\tw@appendixpost
    \else\twget{d.cr.section}\fi}}
\def\tw@fix@subsection{%
  \tw@crlev=3
  \xdef\@currentlabel{\if@tw@appendix\tw@appendixpre\Alph{chapter}.\arabic{section}.\arabic{subsection}\tw@appendixpost
    \else\twget{d.cr.subsection}\fi}}

\newcommand\figref[1]{\twget{d.figure-name}~\ref{#1}}
\newcommand\tblref[1]{\twget{d.table-name}~\ref{#1}}
\newcommand\lstref[1]{\lstlistingname~\ref{#1}}

% --------------------------------------------------------------------------
% page numbers
% --------------------------------------------------------------------------
\newcommand\tw@pnbox{\hb@xt@\textwidth{%
  \twifstr{\twget{d.pn.align}}{L}{}{\hfil}\twget{d.pn.format}%
  \twifstr{\twget{d.pn.align}}{R}{}{\hfil}}}
\newcommand\tw@pnfill{%
  \fancyhf{}\renewcommand\headrulewidth{0pt}\renewcommand\footrulewidth{0pt}%
  \twifstr{\twget{d.pn.position}}{top}{\fancyhead[C]{\tw@pnbox}}{\fancyfoot[C]{\tw@pnbox}}}
\fancypagestyle{tw@style}{\tw@pnfill}
\fancypagestyle{plain}{\tw@pnfill}
\pagestyle{tw@style}

% --------------------------------------------------------------------------
% captions
% --------------------------------------------------------------------------
\RequirePackage[font=normalsize,labelsep=quad,skip=0.6em]{caption}
\RequirePackage{subcaption}

% --------------------------------------------------------------------------
% cover page
% --------------------------------------------------------------------------
\newcommand\tw@covertext[2]{% size key, text
  {\fontsize{\twget{d.cover.size.#1}}{\twget{d.cover.lead.#1}}\selectfont
   \ifnum\twget{d.cover.bold.#1}=1\bfseries\else\mdseries\fi #2\par}}

\newcommand\tw@cover{%
  \newgeometry{top=\twget{d.cover.margin.top},bottom=\twget{d.cover.margin.bottom},%
    left=\twget{d.cover.margin.left},right=\twget{d.cover.margin.right}}%
  \thispagestyle{empty}%
  \begingroup\centering\parindent=0pt\parskip=0pt
  \tw@covertext{org}{\twget{cfg.university}\twget{cfg.college}\twget{cfg.institute}}%
  \tw@covertext{org}{\twget{cfg.degree}\twget{cfg.type}}%
  \vspace{\twget{d.cover.gap.org-en}}%
  \tw@covertext{org-en}{\twget{cfg.institute-en}}%
  \tw@covertext{org-en}{\twget{cfg.college-en}}%
  \vspace{\twget{d.cover.gap.university-en}}%
  \tw@covertext{university-en}{\twget{cfg.university-en}}%
  \tw@covertext{university-en}{\twget{cfg.degree-en}\ \twget{cfg.type-en}}%
  \vspace{\stretch{\twget{d.cover.flex}}}%
  \tw@covertext{title}{\twget{cfg.title}}%
  \tw@covertext{title-en}{\twget{cfg.title-en}}%
  \vspace{\stretch{\twget{d.cover.flex}}}%
  \tw@covertext{author}{\twget{cfg.author}}%
  \tw@covertext{author}{\twget{cfg.author-en}}%
  \vspace{\stretch{\twget{d.cover.flex}}}%
  \tw@covertext{advisor}{\twget{d.cover.advisor-zh}}%
  \tw@covertext{advisor}{\twget{d.cover.advisor-en}}%
  \vspace{\stretch{\twget{d.cover.flex}}}%
  \tw@covertext{date}{\twget{d.cover.date-zh}}%
  \tw@covertext{date}{\twget{d.cover.date-en}}%
  \endgroup
  \clearpage
  \restoregeometry}

% --------------------------------------------------------------------------
% verification letter (口試委員會審定書)
% --------------------------------------------------------------------------
\newcommand\tw@vtext[2]{%
  {\fontsize{\twget{d.verification.size.#1}}{\twget{d.verification.lead.#1}}\selectfont
   \ifnum\twget{d.verification.bold.#1}=1\bfseries\else\mdseries\fi #2\par}}

\newdimen\tw@cone \newdimen\tw@ctwo \newdimen\tw@pair
\newcommand\tw@vrow[3]{% height, left cell, right cell; both bottom-aligned
  \hbox to\linewidth{%
    \parbox[b][#1][b]{\tw@cone}{\raggedleft #2}%
    \parbox[b][#1][b]{\tw@ctwo}{\centering #3}}}
\newcommand\tw@vrule[1]{\rule[-0.2em]{#1}{0.8pt}}

\newcommand\tw@verification{%
  \thispagestyle{empty}%
  \begingroup\centering\parindent=0pt\parskip=0pt
  \tw@vtext{university}{\twget{d.verification.degree-line}}%
  \tw@vtext{title}{\twget{d.verification.title}}%
  \vspace{\stretch{\twget{d.verification.flex}}}%
  \tw@vtext{thesis-title}{\twget{cfg.title}}%
  \tw@vtext{thesis-title}{\twget{cfg.title-en}}%
  \vspace{\stretch{\twget{d.verification.flex}}}%
  \endgroup
  \begingroup\parindent=\twget{d.indent}\ifnum\twget{d.justify}=1\else\raggedright\fi
  \fontsize{\twget{d.verification.size.body}}{\twget{d.verification.lead.body}}\selectfont
  \ifnum\twget{d.verification.bold.body}=1\bfseries\fi
  \twget{d.verification.statement}\par
  \endgroup
  \vspace{\stretch{\twget{d.verification.flex}}}%
  \begingroup
  \fontsize{\twget{d.verification.size.body}}{\twget{d.verification.lead.body}}\selectfont
  \parindent=0pt
  \tw@cone=\twget{d.verification.col1}\linewidth
  \tw@ctwo=\twget{d.verification.col2}\linewidth
  \tw@pair=\twget{d.verification.pair}\tw@ctwo
  \vbox{\offinterlineskip\lineskip=0pt
    \tw@vrow{\twget{d.verification.row.1}}{\twget{cfg.strings.committee}}{\tw@vrule{\twget{d.verification.rule}\tw@ctwo}}%
    \tw@vrow{\twget{d.verification.row.2}}{}{\twget{cfg.strings.committee-advisor}}%
    \tw@vrow{\twget{d.verification.row.3}}{}{\hbox to\tw@ctwo{\tw@vrule{\tw@pair}\hfil\tw@vrule{\tw@pair}}}%
    \tw@vrow{\twget{d.verification.row.4}}{}{\hbox to\tw@ctwo{\tw@vrule{\tw@pair}\hfil\tw@vrule{\tw@pair}}}%
    \tw@vrow{\twget{d.verification.row.5}}{\twget{cfg.strings.director}}{%
      \hspace*{\twget{d.verification.director-indent}}%
      \raisebox{-\twget{d.verification.dy}}{\hspace*{\twget{d.verification.dx}}\tw@vrule{\tw@ctwo}}}}%
  \endgroup
  \vspace{\stretch{\twget{d.verification.flex-end}}}%
  \clearpage}

% --------------------------------------------------------------------------
% table of contents, list of figures, list of tables
% --------------------------------------------------------------------------
\setcounter{tocdepth}{\numexpr\twget{cfg.outline.depth}-1\relax}
\newcommand\tw@outlinetitle[1]{%
  \chapter*{{\fontsize{\twget{d.outline.title-size}}{\twget{d.outline.title-lead}}\selectfont #1}}}

\newcommand\tw@entrygap{\addvspace{\twget{d.outline.entry-gap}}}
\newcommand\tw@entrybold{\ifnum\twget{cfg.outline.entry-bold}=1\bfseries\fi}
\newcommand\tw@toclead{\titlerule*[0.6pc]{.}\contentspage}

\titlecontents{chapter}[0pt]{\tw@entrygap\tw@entrybold}%
  {\thecontentslabel\hspace{\twget{d.heading.gap.1}}}{}{\tw@toclead}
\titlecontents{section}[\twget{d.outline.indent.1}]{}%
  {\thecontentslabel\hspace{\twget{d.heading.gap.2}}}{}{\tw@toclead}
\titlecontents{subsection}[\twget{d.outline.indent.2}]{}%
  {\thecontentslabel\hspace{\twget{d.heading.gap.3}}}{}{\tw@toclead}
\titlecontents{subsubsection}[\twget{d.outline.indent.3}]{}%
  {}{}{\tw@toclead}
\titlecontents{figure}[0pt]{}%
  {\twget{d.figure-name}~\thecontentslabel\hspace{1em}}{}{\tw@toclead}
\titlecontents{table}[0pt]{}%
  {\twget{d.table-name}~\thecontentslabel\hspace{1em}}{}{\tw@toclead}

% entries are links, but only the references in the text are coloured
\renewcommand\tableofcontents{%
  \tw@outlinetitle{\twget{d.titles.toc}}\begingroup\hypersetup{linkcolor=black}\@starttoc{toc}\endgroup}
\renewcommand\listoffigures{%
  \tw@outlinetitle{\twget{d.titles.lof}}\begingroup\hypersetup{linkcolor=black}\@starttoc{lof}\endgroup}
\renewcommand\listoftables{%
  \tw@outlinetitle{\twget{d.titles.lot}}\begingroup\hypersetup{linkcolor=black}\@starttoc{lot}\endgroup}

% --------------------------------------------------------------------------
% watermark, drawn behind every main-matter page when built with
% \def\twwatermark{1} (make release)
% --------------------------------------------------------------------------
\newcommand\tw@watermark{%
  \ifdefined\twwatermark
    \twifcfg{d.watermark.image}{%
      \AddToShipoutPictureBG{%
        \AtPageCenter{\makebox(0,0){%
          \includegraphics[width=\twget{d.watermark.width}\paperwidth]{\twget{d.watermark.image}}}}%
        \AtPageLowerLeft{\begin{tikzpicture}
          \fill[white,opacity=\twget{d.watermark.veil}] (0,0) rectangle (\paperwidth,\paperheight);
        \end{tikzpicture}}}}{}%
  \fi}

% --------------------------------------------------------------------------
% the pages before the body: cover, verification letter, 目次/圖次/表次
% --------------------------------------------------------------------------
\newcommand\thesisfront{%
  \tw@cover
  \tw@verification
  \pagenumbering{\twget{d.outline.numbering.front}}%
  \tableofcontents\clearpage
  \listoffigures\clearpage
  \listoftables\clearpage
  \pagenumbering{\twget{d.outline.numbering.body}}%
  \tw@watermark}

% --------------------------------------------------------------------------
% front-matter sections
% --------------------------------------------------------------------------
\newenvironment{acknowledgement}{\twunnumbered{\twget{cfg.sections.acknowledgement}}}{}
\newenvironment{denotation}{\twunnumbered{\twget{cfg.sections.denotation}}}{}
\setlist[description]{leftmargin=!,labelindent=0pt,labelwidth=5em,labelsep=1em,itemsep=2pt}
\newenvironment{abstractzh}{\twunnumbered{\twget{cfg.sections.abstract}}}%
  {\par\vspace{1em}\noindent\textbf{\twget{cfg.sections.keywords-label}}\twget{d.keywords.zh}\par}
\newenvironment{abstracten}{\twunnumbered{\twget{cfg.sections.abstract-en}}}%
  {\par\vspace{1em}\noindent\textbf{\twget{cfg.sections.keywords-label-en}}\ \twget{d.keywords.en}\par}

% --------------------------------------------------------------------------
% links: only citations and cross-references are coloured
% --------------------------------------------------------------------------
\definecolor{twlink}{HTML}{\twget{d.bibliography.color}}
\RequirePackage[colorlinks=true,linkcolor=twlink,citecolor=twlink,urlcolor=twlink,
  bookmarksnumbered=false,pdfencoding=auto,psdextra]{hyperref}
\hypersetup{unicode=true}

% headings store the reference text as their label (see \tw@fix@... above)
\def\tw@patchref{%
  \let\tw@refstep\refstepcounter
  \def\refstepcounter##1{\tw@refstep{##1}\csname tw@fix@##1\endcsname}}
\AtBeginDocument{\tw@patchref}

% --------------------------------------------------------------------------
% bibliography: citation-style-language reads .bib, CSL JSON/YAML (and the CSL
% JSON scripts/gen.py converts Hayagriva to); citeproc-lua formats it with any
% CSL style. d.bibliography.style.id is a built-in name or a path to a .csl.
% --------------------------------------------------------------------------
\edef\tw@cslstyle{\twget{d.bibliography.style.id}}
\RequirePackage[style=\tw@cslstyle]{citation-style-language}
\forcsvlist{\addbibresource}{\twget{d.bibliography.resources}}
% citeproc-lua reads these files, not TeX; opening them once puts them in the
% .fls file so that latexmk reruns the build when one of them changes
\newread\tw@trackfile
\newcommand\tw@track[1]{\openin\tw@trackfile=#1\relax\ifeof\tw@trackfile\else\closein\tw@trackfile\fi}
\forcsvlist{\tw@track}{\twget{d.bibliography.resources}}
\ifnum\twget{d.bibliography.style.custom}=1 \expandafter\tw@track\expandafter{\twget{d.bibliography.style}}\fi
\newcommand\twbibtitle{\twget{d.bibliography.title}}
\newcommand\references{%
  \begingroup
  \ifnum\twget{d.bibliography.full}=1 \nocite{*}\fi
  \clearpage
  \chapter*{\twbibtitle}\phantomsection
  \addcontentsline{toc}{chapter}{\protect\twbibtitle}%
  \printbibliography[heading=none]%
  \endgroup}

% --------------------------------------------------------------------------
% content helpers
% --------------------------------------------------------------------------
\RequirePackage{tw-thesis}
\makeatother
\endinput
