# nothing is echoed unless something fails
set quiet := true

latexmk := "latexmk"
python := "python3"
main := "main"
flags := "-xelatex -interaction=nonstopmode -halt-on-error"

# `just compile` when nothing else is specified
default: compile

# config.yml, the school preset and the bibliography are converted before every
# build (see scripts/gen.py); latexmkrc then runs XeLaTeX and citeproc-lua
generate:
    {{ python }} scripts/gen.py

# draft, no watermark; latexmkrc prints nothing on success and Typst-style errors on failure
[no-exit-message]
compile: generate
    if [ -f .release ]; then rm -f .release; G=-g; fi; {{ latexmk }} ${G:-} {{ flags }} {{ main }}.tex

# final, with watermark; -g rebuilds even if nothing changed since the draft
[no-exit-message]
release: generate
    @touch .release
    {{ latexmk }} -g {{ flags }} -usepretex='\def\twwatermark{1}' {{ main }}.tex

[no-exit-message]
watch: generate
    {{ latexmk }} -pvc {{ flags }} {{ main }}.tex

[no-exit-message]
watch-release: generate
    {{ latexmk }} -pvc -g {{ flags }} -usepretex='\def\twwatermark{1}' {{ main }}.tex

# the English tutorial, with English prefixes (Figure, Table, Chapter, Section)
generate-en: generate
    {{ python }} scripts/gen.py contents/i18n/en/config.yml -o .tw-thesis-build/config-en.tex

[no-exit-message]
compile-en: generate-en
    {{ latexmk }} {{ flags }} {{ main }}-en.tex

[no-exit-message]
watch-en: generate-en
    {{ latexmk }} -pvc {{ flags }} {{ main }}-en.tex

clean:
    {{ latexmk }} -C {{ main }}.tex
    rm -rf .tw-thesis-config.tex .tw-thesis-bibliography.json .tw-thesis-build {{ main }}.bbl {{ main }}.xdv {{ main }}-en.pdf .release
