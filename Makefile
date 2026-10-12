# texlua scripts/gen.lua turns config.yml into .tw-thesis-config.tex (and
# converts Hayagriva bibliographies to CSL JSON), then latexmk runs XeLaTeX and
# citeproc-lua (see latexmkrc) as many times as the build needs.
LATEXMK   ?= latexmk
# texlua comes with every TeX distribution, so no Python is needed
TEXLUA    ?= texlua
MAIN      := main
OUTPUT    := $(MAIN).pdf
FLAGS     := -xelatex -interaction=nonstopmode -halt-on-error

# watermark is off unless this is passed
RELEASE   := -usepretex='\def\twwatermark{1}'

# private build files: never edit or commit these
PRIVATE   := .tw-thesis-config.tex .tw-thesis-build

.PHONY: generate compile release watch watch-release generate-en compile-en watch-en clean

# `make` when nothing else is specified; nothing is echoed unless something fails
.DEFAULT_GOAL := compile
.SILENT:

# config.yml, the school preset and the bibliography are converted before every
# build; the script leaves unchanged outputs alone, so this stays cheap
generate:
	$(TEXLUA) scripts/gen.lua

# draft, no watermark: the default target. latexmkrc prints nothing on success
# and Typst-style errors on failure
compile: generate
	if [ -f .release ]; then rm -f .release; G=-g; fi; \
	$(LATEXMK) $${G:-} $(FLAGS) $(MAIN).tex

# final, with watermark; -g rebuilds even if nothing changed since the draft
release: generate
	@touch .release   # so the next plain `make` rebuilds without the watermark
	$(LATEXMK) -g $(FLAGS) $(RELEASE) $(MAIN).tex

watch: generate
	$(LATEXMK) -pvc $(FLAGS) $(MAIN).tex

watch-release: generate
	$(LATEXMK) -pvc -g $(FLAGS) $(RELEASE) $(MAIN).tex

# the English tutorial, with English prefixes (Figure, Table, Chapter, Section)
generate-en: generate
	$(TEXLUA) scripts/gen.lua contents/i18n/en/config.yml -o .tw-thesis-build/config-en.tex

compile-en: generate-en
	$(LATEXMK) $(FLAGS) $(MAIN)-en.tex

watch-en: generate-en
	$(LATEXMK) -pvc $(FLAGS) $(MAIN)-en.tex

clean:
	$(LATEXMK) -C $(MAIN).tex
	rm -rf $(PRIVATE) $(MAIN).bbl $(MAIN).xdv $(MAIN)-en.pdf .release
