# AutoPandoc Makefile
# (c) Fabian Schmieder - This is free software and licensed under GPL3 (https://www.gnu.org/licenses/gpl-3.0)
# https://gist.github.com/metaneutrons/8816ff49bbce5047a5308b3cf6fbb603
# Version: 1.4.2

# Project configuration
PROJECT_NAME ?= $(shell basename $(CURDIR))
OUTPUT_DIR = output
TEMPLATES_DIR = templates
IMAGES_DIR = images

# File discovery
MD_FILES = $(filter-out README.md, $(wildcard *.md))
MMD_FILES = $(wildcard *.mmd)
IMAGE_FILES = $(wildcard $(IMAGES_DIR)/*.png $(IMAGES_DIR)/*.jpg $(IMAGES_DIR)/*.jpeg $(IMAGES_DIR)/*.svg $(IMAGES_DIR)/*.pdf)

# Output files
OUTPUT_PDF = $(OUTPUT_DIR)/$(PROJECT_NAME).pdf
OUTPUT_DOCX = $(OUTPUT_DIR)/$(PROJECT_NAME).docx
OUTPUT_HTML = $(OUTPUT_DIR)/$(PROJECT_NAME).html

# Diagram outputs
PDF_DIAGRAMS = $(patsubst %.mmd,$(IMAGES_DIR)/%.pdf,$(MMD_FILES))
PNG_DIAGRAMS = $(patsubst %.mmd,$(IMAGES_DIR)/%.png,$(MMD_FILES))
SVG_DIAGRAMS = $(patsubst %.mmd,$(IMAGES_DIR)/%.svg,$(MMD_FILES))

# Template detection
AVAILABLE_TEMPLATES = $(wildcard $(TEMPLATES_DIR)/*.latex)
DEFAULT_TEMPLATE = $(TEMPLATES_DIR)/eisvogel.latex
TEMPLATE_ARG = $(if $(wildcard $(DEFAULT_TEMPLATE)),--template=$(DEFAULT_TEMPLATE),)

# Pandoc filters and options
PANDOC_MERMAID := $(shell command -v pandoc-mermaid 2>/dev/null)
PANDOC_FILTERS := $(if $(PANDOC_MERMAID),--filter pandoc-mermaid,) --citeproc
PANDOC_OPTIONS = --standalone --toc --number-sections

# Logging functions
define log_info
	@echo "ℹ️ $(1)"
endef

define log_success
	@echo "✅ $(1)"
endef

define log_error
	@echo "❌ $(1)"
endef

# Silent version check
define check_version
	@GIST_ID="8816ff49bbce5047a5308b3cf6fbb603"; \
	LOCAL_VERSION=$$(grep "^# Version:" Makefile | head -1 | awk '{print $$3}' || echo "unknown"); \
	if command -v curl >/dev/null 2>&1; then \
		REMOTE_VERSION=$$(curl -s "https://gist.githubusercontent.com/metaneutrons/$$GIST_ID/raw/Makefile" | grep "^# Version:" | head -1 | awk '{print $$3}' 2>/dev/null || echo ""); \
		if [ -n "$$REMOTE_VERSION" ] && [ "$$LOCAL_VERSION" != "$$REMOTE_VERSION" ]; then \
			echo "⚠️ New AutoPandoc version available: $$REMOTE_VERSION (current: $$LOCAL_VERSION). Run 'make update' to upgrade."; \
		fi; \
	fi
endef

# Auto-update Makefile from gist
update:
	@echo "🔄 Checking for AutoPandoc Makefile updates..."
	@GIST_ID="8816ff49bbce5047a5308b3cf6fbb603"; \
	GIST_URL="https://gist.githubusercontent.com/metaneutrons/$$GIST_ID/raw/Makefile"; \
	LOCAL_VERSION=$$(grep "^# Version:" Makefile | head -1 | awk '{print $$3}' || echo "unknown"); \
	echo "📍 Local version: $$LOCAL_VERSION"; \
	if command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then \
		echo "📥 Checking remote version via GitHub API..."; \
		REMOTE_VERSION=$$(curl -s "https://api.github.com/gists/$$GIST_ID" | jq -r '.files.Makefile.content' | grep "^# Version:" | head -1 | awk '{print $$3}'); \
	elif command -v curl >/dev/null 2>&1; then \
		echo "📥 Checking remote version..."; \
		REMOTE_VERSION=$$(curl -s "$$GIST_URL" | grep "^# Version:" | head -1 | awk '{print $$3}'); \
	elif command -v wget >/dev/null 2>&1; then \
		echo "📥 Checking remote version..."; \
		REMOTE_VERSION=$$(wget -q "$$GIST_URL" -O - | grep "^# Version:" | head -1 | awk '{print $$3}'); \
	else \
		echo "❌ Neither curl nor wget available. Cannot update."; \
		exit 1; \
	fi; \
	if [ -z "$$REMOTE_VERSION" ]; then \
		echo "❌ No version found in remote gist. Refusing to update."; \
		echo "ℹ️ Remote Makefile must contain '# Version: X.X.X' line"; \
		exit 1; \
	fi; \
	echo "🌐 Remote version: $$REMOTE_VERSION"; \
	if [ "$$LOCAL_VERSION" = "$$REMOTE_VERSION" ]; then \
		echo "✅ Makefile is already up to date (v$$LOCAL_VERSION)"; \
	elif [ "$$LOCAL_VERSION" != "unknown" ] && printf '%s\n%s\n' "$$REMOTE_VERSION" "$$LOCAL_VERSION" | sort -V | head -1 | grep -q "$$REMOTE_VERSION"; then \
		echo "⚠️ Remote version ($$REMOTE_VERSION) is older than local ($$LOCAL_VERSION)"; \
		echo "❌ Refusing to downgrade. Use 'make update-force' to override."; \
	else \
		echo "🆕 New version available ($$LOCAL_VERSION → $$REMOTE_VERSION)"; \
		echo "📥 Downloading latest version..."; \
		if command -v curl >/dev/null 2>&1; then \
			curl -s "$$GIST_URL" > Makefile.new; \
		else \
			wget -q "$$GIST_URL" -O Makefile.new; \
		fi; \
		if [ -s Makefile.new ]; then \
			echo "💾 Backing up current Makefile to Makefile.backup"; \
			cp Makefile Makefile.backup; \
			echo "✅ Installing updated Makefile"; \
			mv Makefile.new Makefile; \
			echo "🎉 AutoPandoc updated successfully to v$$REMOTE_VERSION!"; \
			echo "ℹ️ Previous version saved as Makefile.backup"; \
		else \
			echo "❌ Download failed or empty file"; \
			rm -f Makefile.new; \
			exit 1; \
		fi; \
	fi

.PHONY: all pdf docx html clean diagrams setup help check-deps watch open build-and-open status templates download-eisvogel init readme check-build-deps update
.DEFAULT_GOAL := readme

all: pdf docx html
	$(call check_version)

# Check dependencies and show status
check-deps:
	$(call log_info,Checking dependencies...)
	@INSTALL_CMD=""; \
	if [ -f /etc/os-release ]; then \
		. /etc/os-release; \
		case "$$ID" in \
			ubuntu|debian) INSTALL_CMD="sudo apt install pandoc texlive-xetex";; \
			fedora) INSTALL_CMD="sudo dnf install pandoc texlive-xetex";; \
			centos|rhel) INSTALL_CMD="sudo yum install pandoc texlive-xetex";; \
			arch|manjaro) INSTALL_CMD="sudo pacman -S pandoc texlive-core";; \
			opensuse*) INSTALL_CMD="sudo zypper install pandoc texlive-xetex";; \
		esac; \
	elif command -v brew >/dev/null 2>&1; then \
		INSTALL_CMD="brew install pandoc"; \
	else \
		INSTALL_CMD="Install pandoc and xelatex via your package manager"; \
	fi; \
	command -v pandoc >/dev/null 2>&1 || (echo "❌ pandoc not found. Install with: $$INSTALL_CMD" && exit 1); \
	command -v xelatex >/dev/null 2>&1 || (echo "❌ xelatex not found. Install with: $$INSTALL_CMD" && exit 1)
	@if [ "$(words $(MMD_FILES))" != "0" ]; then \
		command -v npx >/dev/null 2>&1 || (echo "❌ npx not found. Install Node.js for mermaid diagrams" && exit 1); \
	fi
	$(call log_success,All dependencies satisfied!)

# Check dependencies before building
check-build-deps:
	@echo "🔍 Checking build dependencies..."
	@MISSING_REQUIRED=0; \
	MISSING_OPTIONAL=0; \
	INSTALL_CMD=""; \
	if [ -f /etc/os-release ]; then \
		. /etc/os-release; \
		case "$$ID" in \
			ubuntu|debian) INSTALL_CMD="sudo apt install pandoc texlive-xetex";; \
			fedora) INSTALL_CMD="sudo dnf install pandoc texlive-xetex";; \
			centos|rhel) INSTALL_CMD="sudo yum install pandoc texlive-xetex";; \
			arch|manjaro) INSTALL_CMD="sudo pacman -S pandoc texlive-core";; \
			opensuse*) INSTALL_CMD="sudo zypper install pandoc texlive-xetex";; \
		esac; \
	elif command -v brew >/dev/null 2>&1; then \
		INSTALL_CMD="brew install pandoc && brew install --cask mactex"; \
	else \
		INSTALL_CMD="Install pandoc and xelatex via your package manager"; \
	fi; \
	printf "📦 pandoc: "; \
	if command -v pandoc >/dev/null 2>&1; then \
		echo "🟢 Available"; \
	else \
		echo "🔴 REQUIRED - Install with: $$INSTALL_CMD"; \
		MISSING_REQUIRED=1; \
	fi; \
	printf "🔧 xelatex: "; \
	if command -v xelatex >/dev/null 2>&1; then \
		echo "🟢 Available"; \
	else \
		echo "🔴 REQUIRED - Install with: $$INSTALL_CMD"; \
		MISSING_REQUIRED=1; \
	fi; \
	if [ "$(words $(MMD_FILES))" != "0" ]; then \
		printf "🎨 mermaid-cli (for .mmd files): "; \
		if command -v npx >/dev/null 2>&1; then \
			echo "🟢 Available via npx"; \
		else \
			echo "🔴 REQUIRED for mermaid diagrams - Install Node.js"; \
			MISSING_REQUIRED=1; \
		fi; \
	else \
		echo "🔵 mermaid-cli: Not needed (no .mmd files)"; \
	fi; \
	if grep -q "^\`\`\`mermaid" *.md 2>/dev/null; then \
		printf "🔗 mermaid filters: "; \
		MERMAID_FILTERS=""; \
		if command -v pandoc-mermaid >/dev/null 2>&1; then \
			MERMAID_FILTERS="$$MERMAID_FILTERS pandoc-mermaid"; \
		fi; \
		if command -v mermaid-filter >/dev/null 2>&1; then \
			MERMAID_FILTERS="$$MERMAID_FILTERS mermaid-filter"; \
		fi; \
		if [ -n "$$MERMAID_FILTERS" ]; then \
			echo "🟢 Available:$$MERMAID_FILTERS"; \
		else \
			echo "🔴 REQUIRED - Install pandoc-mermaid or mermaid-filter"; \
			MISSING_REQUIRED=1; \
		fi; \
	else \
		echo "🔵 mermaid filters: Not needed (no inline mermaid)"; \
	fi; \
	if grep -q "titlepage-background:" *.md 2>/dev/null; then \
		printf "🖼️ inkscape (for PDF backgrounds): "; \
		if command -v inkscape >/dev/null 2>&1; then \
			echo "🟢 Available"; \
		else \
			echo "🟡 OPTIONAL - Install for better PDF background handling"; \
			MISSING_OPTIONAL=1; \
		fi; \
	fi; \
	if [ $$MISSING_REQUIRED -eq 1 ]; then \
		echo ""; \
		echo "❌ Missing required dependencies. Please install them first."; \
		exit 1; \
	elif [ $$MISSING_OPTIONAL -eq 1 ]; then \
		echo ""; \
		echo "⚠️ Some optional features may not work optimally."; \
	else \
		echo "✅ All dependencies satisfied!"; \
	fi

# Create output directory
$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

# PDF generation with enhanced dependency checking
$(OUTPUT_PDF): $(MD_FILES) $(PDF_DIAGRAMS) $(PNG_DIAGRAMS) $(IMAGE_FILES) | $(OUTPUT_DIR) check-build-deps
	$(call log_info,Building PDF: $(OUTPUT_PDF))
	@if [ -z "$(MD_FILES)" ]; then \
		echo "❌ No markdown files found"; \
		exit 1; \
	fi
	@NUMBERING=$$(grep -h "^numbersections:" *.md 2>/dev/null | head -1 | awk -F': *' '{print $$2}' | tr -d '"' || echo "true"); \
	if [ "$$NUMBERING" = "false" ]; then \
		NUMBER_FLAG=""; \
	else \
		NUMBER_FLAG="--number-sections"; \
	fi; \
	TOPLEVEL=$$(grep -h "^top-level-division:" *.md 2>/dev/null | head -1 | awk -F': *' '{gsub(/[\"]/, "", $$2); print $$2}'); \
	DOCUMENTCLASS=$$(awk '/^---$$/{if(in_yaml) exit; in_yaml=1; next} in_yaml && /^documentclass:/{gsub(/^documentclass: *["\047]?/, ""); gsub(/["\047] *#.*$$/, ""); gsub(/["\047]$$/, ""); print; exit}' *.md 2>/dev/null | head -1); \
	\
	if [ -z "$$TOPLEVEL" ] && [ -z "$$DOCUMENTCLASS" ]; then \
		TOPLEVEL="section"; DOCUMENTCLASS="article"; \
	elif [ -z "$$TOPLEVEL" ] && [ -n "$$DOCUMENTCLASS" ]; then \
		case "$$DOCUMENTCLASS" in \
			book|scrbook|report|scrreprt) TOPLEVEL="chapter";; \
			*) TOPLEVEL="section";; \
		esac; \
	elif [ -n "$$TOPLEVEL" ] && [ -z "$$DOCUMENTCLASS" ]; then \
		case "$$TOPLEVEL" in \
			chapter) DOCUMENTCLASS="book";; \
			*) DOCUMENTCLASS="article";; \
		esac; \
	fi; \
	\
	BOOK_MODE="false"; \
	if [ "$$DOCUMENTCLASS" = "book" ] || [ "$$DOCUMENTCLASS" = "scrbook" ] || [ "$$DOCUMENTCLASS" = "report" ] || [ "$$DOCUMENTCLASS" = "scrreprt" ]; then \
		BOOK_MODE="true"; \
	fi; \
	\
	LANG_VAL=$$(grep -h "^lang:" *.md 2>/dev/null | head -1 | awk -F': *' '{gsub(/[\"]/, "", $$2); print $$2}'); \
	if [ -z "$$LANG_VAL" ]; then \
		LANG_VAL=$$(echo "$$LANG" | cut -d'.' -f1 | tr '_' '-' | tr '[:upper:]' '[:lower:]' 2>/dev/null || echo "en"); \
		if [ -z "$$LANG_VAL" ] || [ "$$LANG_VAL" = "c" ]; then LANG_VAL="en"; fi; \
	fi; \
	BABEL_LANG=$$(grep -h "^babel-lang:" *.md 2>/dev/null | head -1 | awk -F': *' '{gsub(/[\"]/, "", $$2); print $$2}'); \
	if [ -z "$$BABEL_LANG" ]; then \
		case "$$LANG_VAL" in \
			de*) BABEL_LANG="ngerman";; \
			fr*) BABEL_LANG="french";; \
			es*) BABEL_LANG="spanish";; \
			it*) BABEL_LANG="italian";; \
			pt*) BABEL_LANG="portuguese";; \
			nl*) BABEL_LANG="dutch";; \
			ru*) BABEL_LANG="russian";; \
			*) BABEL_LANG="english";; \
		esac; \
	fi; \
	if [ -n "$(TEMPLATE_ARG)" ]; then \
		echo "📄 Using template: $(DEFAULT_TEMPLATE)"; \
		echo "🌐 Language: $$LANG_VAL (babel: $$BABEL_LANG)"; \
		echo "📑 Top-level division: $$TOPLEVEL"; \
		echo "📖 Document class: $$DOCUMENTCLASS"; \
		if [ "$$BOOK_MODE" = "true" ]; then \
			pandoc --listings --top-level-division=$$TOPLEVEL $$NUMBER_FLAG $(PANDOC_FILTERS) $(TEMPLATE_ARG) \
				--pdf-engine=xelatex \
				--metadata lang=$$LANG_VAL \
				--metadata babel-lang=$$BABEL_LANG \
				--metadata book=true \
				--metadata documentclass=$$DOCUMENTCLASS \
				$(MD_FILES) -o $(OUTPUT_PDF); \
		else \
			pandoc --listings --top-level-division=$$TOPLEVEL $$NUMBER_FLAG $(PANDOC_FILTERS) $(TEMPLATE_ARG) \
				--pdf-engine=xelatex \
				--metadata lang=$$LANG_VAL \
				--metadata babel-lang=$$BABEL_LANG \
				--metadata documentclass=$$DOCUMENTCLASS \
				$(MD_FILES) -o $(OUTPUT_PDF); \
		fi; \
	else \
		echo "📄 No template found, using default"; \
		echo "🌐 Language: $$LANG_VAL (babel: $$BABEL_LANG)"; \
		echo "📑 Top-level division: $$TOPLEVEL"; \
		echo "📖 Document class: $$DOCUMENTCLASS"; \
		if [ "$$BOOK_MODE" = "true" ]; then \
			pandoc --listings --top-level-division=$$TOPLEVEL $$NUMBER_FLAG $(PANDOC_FILTERS) \
				--pdf-engine=xelatex \
				--metadata lang=$$LANG_VAL \
				--metadata babel-lang=$$BABEL_LANG \
				--metadata book=true \
				--metadata documentclass=$$DOCUMENTCLASS \
				$(MD_FILES) -o $(OUTPUT_PDF); \
		else \
			pandoc --listings --top-level-division=$$TOPLEVEL $$NUMBER_FLAG $(PANDOC_FILTERS) \
				--pdf-engine=xelatex \
				--metadata lang=$$LANG_VAL \
				--metadata babel-lang=$$BABEL_LANG \
				--metadata documentclass=$$DOCUMENTCLASS \
				$(MD_FILES) -o $(OUTPUT_PDF); \
		fi; \
	fi
	$(call log_success,PDF generated: $(OUTPUT_PDF))

# DOCX generation
$(OUTPUT_DOCX): $(MD_FILES) | $(OUTPUT_DIR)
	$(call log_info,Building DOCX: $(OUTPUT_DOCX))
	@pandoc $(PANDOC_OPTIONS) $(MD_FILES) -o $(OUTPUT_DOCX)
	$(call log_success,DOCX generated: $(OUTPUT_DOCX))

# HTML generation
$(OUTPUT_HTML): $(MD_FILES) $(SVG_DIAGRAMS) | $(OUTPUT_DIR)
	$(call log_info,Building HTML: $(OUTPUT_HTML))
	@pandoc $(PANDOC_OPTIONS) --self-contained $(MD_FILES) -o $(OUTPUT_HTML)
	$(call log_success,HTML generated: $(OUTPUT_HTML))

# Individual format targets
pdf: $(OUTPUT_PDF)
	$(call check_version)

docx: $(OUTPUT_DOCX)
	$(call check_version)

html: $(OUTPUT_HTML)
	$(call check_version)

# Diagram generation
$(IMAGES_DIR)/%.pdf: %.mmd | $(IMAGES_DIR)
	$(call log_info,🎨 Converting $< to PDF)
	@npx -p @mermaid-js/mermaid-cli mmdc -i $< -o $@ -t neutral -b white

$(IMAGES_DIR)/%.png: %.mmd | $(IMAGES_DIR)
	$(call log_info,🎨 Converting $< to PNG)
	@npx -p @mermaid-js/mermaid-cli mmdc -i $< -o $@ -t neutral -b white

$(IMAGES_DIR)/%.svg: %.mmd | $(IMAGES_DIR)
	$(call log_info,🎨 Converting $< to SVG)
	@npx -p @mermaid-js/mermaid-cli mmdc -i $< -o $@ -t neutral -b white

diagrams: $(PDF_DIAGRAMS) $(PNG_DIAGRAMS) $(SVG_DIAGRAMS)

# Download latest Eisvogel template
download-eisvogel:
	$(call log_info,Downloading latest Eisvogel template...)
	@mkdir -p $(TEMPLATES_DIR)
	@curl -s https://api.github.com/repos/Wandmalfarbe/pandoc-latex-template/releases/latest | \
		grep "browser_download_url.*zip" | \
		cut -d '"' -f 4 | \
		head -1 | \
		xargs curl -L -o eisvogel-temp.zip
	@unzip -q eisvogel-temp.zip "*/eisvogel.latex" -d temp-extract
	@find temp-extract -path "*/Eisvogel-*/eisvogel.latex" -not -path "*/template-multi-file/*" -exec cp {} $(TEMPLATES_DIR)/ \;
	@rm -rf eisvogel-temp.zip temp-extract
	$(call log_success,Eisvogel template downloaded to $(TEMPLATES_DIR)/eisvogel.latex)

# Clean generated files
clean:
	$(call log_info,Cleaning generated files...)
	@rm -rf $(OUTPUT_DIR)
	@rm -f $(PDF_DIAGRAMS) $(PNG_DIAGRAMS) $(SVG_DIAGRAMS)
	$(call log_success,Cleanup complete)

# Project setup
setup: download-eisvogel
	$(call log_info,Setting up project structure...)
	@mkdir -p $(OUTPUT_DIR) $(TEMPLATES_DIR) $(IMAGES_DIR)
	@if [ ! -f "00-setup.md" ]; then \
		echo "Creating 00-setup.md..."; \
		SYSTEM_LANG=$$(echo "$$LANG" | cut -d'.' -f1 | tr '_' '-' | tr '[:upper:]' '[:lower:]' 2>/dev/null || echo "en"); \
		if [ -z "$$SYSTEM_LANG" ] || [ "$$SYSTEM_LANG" = "c" ]; then SYSTEM_LANG="en"; fi; \
		echo "---" > 00-setup.md; \
		echo "# Document Metadata" >> 00-setup.md; \
		echo "title: \"$(PROJECT_NAME)\"" >> 00-setup.md; \
		echo "author: \"Your Name\"" >> 00-setup.md; \
		echo "date: \"$$(date +'%Y-%m-%d')\"" >> 00-setup.md; \
		echo "# Document subtitle" >> 00-setup.md; \
		echo "# subtitle: \"Document Subtitle\"" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# Language and Localization" >> 00-setup.md; \
		echo "lang: \"$$SYSTEM_LANG\"" >> 00-setup.md; \
		echo "# For specific babel language" >> 00-setup.md; \
		echo "# babel-lang: \"ngerman\"" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# Document Structure" >> 00-setup.md; \
		echo "# Use 'section' for articles, 'chapter' for books/reports" >> 00-setup.md; \
		echo "top-level-division: \"section\"" >> 00-setup.md; \
		echo "numbersections: true" >> 00-setup.md; \
		echo "# Numbering depth (1-6)" >> 00-setup.md; \
		echo "# secnumdepth: 3" >> 00-setup.md; \
		echo "# Table of contents" >> 00-setup.md; \
		echo "# toc: true" >> 00-setup.md; \
		echo "# TOC depth" >> 00-setup.md; \
		echo "# toc-depth: 3" >> 00-setup.md; \
		echo "# List of figures" >> 00-setup.md; \
		echo "# lof: true" >> 00-setup.md; \
		echo "# List of tables" >> 00-setup.md; \
		echo "# lot: true" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# Document Class and Layout" >> 00-setup.md; \
		echo "# Options: article, book, report, scrartcl, scrbook, scrreprt" >> 00-setup.md; \
		echo "# documentclass: \"article\"" >> 00-setup.md; \
		echo "# classoption: [\"11pt\", \"a4paper\"]" >> 00-setup.md; \
		echo "# geometry: [\"margin=2.5cm\"]" >> 00-setup.md; \
		echo "# fontsize: \"11pt\"" >> 00-setup.md; \
		echo "# mainfont: \"Times New Roman\"" >> 00-setup.md; \
		echo "# Used for headings in Eisvogel template" >> 00-setup.md; \
		echo "# sansfont: \"Arial\"" >> 00-setup.md; \
		echo "# monofont: \"Courier New\"" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# Bibliography and Citations" >> 00-setup.md; \
		echo "# bibliography: \"references.bib\"" >> 00-setup.md; \
		echo "# Citation style" >> 00-setup.md; \
		echo "# csl: \"ieee.csl\"" >> 00-setup.md; \
		echo "# link-citations: true" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# PDF-specific Options" >> 00-setup.md; \
		echo "# colorlinks: true" >> 00-setup.md; \
		echo "# linkcolor: \"blue\"" >> 00-setup.md; \
		echo "# urlcolor: \"blue\"" >> 00-setup.md; \
		echo "# citecolor: \"blue\"" >> 00-setup.md; \
		echo "# Use book class (enables chapters)" >> 00-setup.md; \
		echo "# book: true" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# Eisvogel Template Options" >> 00-setup.md; \
		echo "# titlepage: true" >> 00-setup.md; \
		echo "# titlepage-color: \"06386e\"" >> 00-setup.md; \
		echo "# titlepage-text-color: \"FFFFFF\"" >> 00-setup.md; \
		echo "# titlepage-rule-color: \"FFFFFF\"" >> 00-setup.md; \
		echo "# titlepage-rule-height: 1" >> 00-setup.md; \
		echo "# titlepage-background: \"background.pdf\"" >> 00-setup.md; \
		echo "# logo: \"logo.png\"" >> 00-setup.md; \
		echo "# logo-width: \"100\"" >> 00-setup.md; \
		echo "# footer-left: \"Footer Text\"" >> 00-setup.md; \
		echo "# header-right: \"Header Text\"" >> 00-setup.md; \
		echo "# disable-header-and-footer: false" >> 00-setup.md; \
		echo "# listings-disable-line-numbers: false" >> 00-setup.md; \
		echo "# code-block-font-size: \"\\\\footnotesize\"" >> 00-setup.md; \
		echo "" >> 00-setup.md; \
		echo "# HTML Output Options" >> 00-setup.md; \
		echo "# css: \"style.css\"" >> 00-setup.md; \
		echo "# self-contained: true" >> 00-setup.md; \
		echo "---" >> 00-setup.md; \
	fi
	$(call log_success,Project setup complete!)

# Watch for changes and rebuild
watch:
	$(call log_info,Watching for changes... Press Ctrl+C to stop)
	@while true; do \
		inotifywait -e modify,create,delete *.md *.mmd 2>/dev/null || \
		(sleep 2); \
		make pdf; \
	done

# Open generated PDF
open: pdf
	@open $(OUTPUT_PDF) 2>/dev/null || xdg-open $(OUTPUT_PDF) 2>/dev/null || echo "Cannot open PDF automatically"

# Quick build and open
build-and-open: pdf open

# Project status
status:
	@echo "📊 PROJECT STATUS"
	@echo "=================="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Markdown files: $(words $(MD_FILES))"
	@echo "Mermaid diagrams: $(words $(MMD_FILES))"
	@echo "Images: $(words $(IMAGE_FILES))"
	@echo ""
	@echo "📁 FILES"
	@echo "========="
	@for file in $(MD_FILES); do echo " 📝 $$file"; done
	@for file in $(MMD_FILES); do echo " 📊 $$file"; done
	@for file in $(IMAGE_FILES); do echo " 🖼️ $$file"; done
	@echo ""
	@echo "🎯 OUTPUTS"
	@echo "==========="
	@if [ -f "$(OUTPUT_PDF)" ]; then echo " ✅ $(OUTPUT_PDF)"; else echo " ❌ $(OUTPUT_PDF)"; fi
	@if [ -f "$(OUTPUT_DOCX)" ]; then echo " ✅ $(OUTPUT_DOCX)"; else echo " ❌ $(OUTPUT_DOCX)"; fi
	@if [ -f "$(OUTPUT_HTML)" ]; then echo " ✅ $(OUTPUT_HTML)"; else echo " ❌ $(OUTPUT_HTML)"; fi

# List available templates
templates:
	@echo "Available templates:"
	@if [ -n "$(AVAILABLE_TEMPLATES)" ]; then \
		for tmpl in $(AVAILABLE_TEMPLATES); do echo " - $$tmpl"; done; \
	else \
		echo " No templates found in $(TEMPLATES_DIR)/"; \
	fi
ifdef DEFAULT_TEMPLATE
	@echo "Default: $(DEFAULT_TEMPLATE)"
endif

# Initialize new project
init: setup
	$(call log_info,Initializing new AutoPandoc project...)
	@EXISTING_MD=$$(ls *.md 2>/dev/null | grep -v "^00-setup.md$$" | wc -l | tr -d ' '); \
	if [ "$$EXISTING_MD" -eq 0 ]; then \
		echo "Creating sample content..."; \
		echo "# Introduction" > 01-introduction.md; \
		echo "" >> 01-introduction.md; \
		echo "Welcome to your new document project!" >> 01-introduction.md; \
	else \
		echo "Found existing markdown files, skipping sample content creation."; \
	fi
	$(call log_success,Project initialized! Edit the .md files and run 'make pdf')
	$(call check_version)

# Show README information
readme:
	@echo "    █████╗ ██╗   ██╗████████╗ ██████╗ ██████╗  █████╗ ███╗   ██╗██████╗  ██████╗  ██████╗"
	@echo "   ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗████╗  ██║██╔══██╗██╔═══██╗██╔════╝"
	@echo "   ███████║██║   ██║   ██║   ██║   ██║██████╔╝███████║██╔██╗ ██║██║  ██║██║   ██║██║"
	@echo "   ██╔══██║██║   ██║   ██║   ██║   ██║██╔═══╝ ██╔══██║██║╚██╗██║██║  ██║██║   ██║██║"
	@echo "   ██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║     ██║  ██║██║ ╚████║██████╔╝╚██████╔╝╚██████╗"
	@echo "   ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝  ╚═════╝"
	@echo ""
	@echo "           🚀 Automated Document Generation with Pandoc | (c) 2025 Fabian Schmieder"
	@echo "     This is free software and licensed under GPL3 (https://www.gnu.org/licenses/gpl-3.0)"
	@echo ""
	@echo "🎯 QUICK START"
	@echo "   make init              Initialize new project"
	@echo "   make pdf               Build PDF document"
	@echo "   make docx              Build Word document"
	@echo "   make html              Build HTML document"
	@echo "   make all               Build all formats"
	@echo ""
	@echo "📋 COMMON TASKS"
	@echo "   make setup              Setup project structure"
	@echo "   make diagrams           Generate mermaid diagrams"
	@echo "   make clean              Remove generated files"
	@echo "   make watch              Auto-rebuild on changes"
	@echo "   make open               Build and open PDF"
	@echo "   make build-and-open     Build PDF and open it"
	@echo "   make status             Show project status and file info"
	@echo "   make templates          Download/update Eisvogel template"
	@echo "   make update             Update AutoPandoc Makefile from gist"
	@echo "   make help               Show detailed help information"
	@echo ""
	@echo "⚙️  CONFIGURATION"
	@echo "   Edit 00-setup.md to configure:"
	@echo "   • Document structure (book/article, language, numbering)"
	@echo "   • Title, author, date metadata"
	@echo "   • Custom styling and layout options"
	@echo ""
	@echo "📚 FEATURES"
	@echo "   ✓ Multi-format output (PDF, DOCX, HTML)"
	@echo "   ✓ Auto-converts .mmd files to SVG/PDF/PNG diagrams"
	@echo "   ✓ Professional LaTeX templates (Eisvogel)"
	@echo "   ✓ Automatic table of contents and numbering"
	@echo "   ✓ Citation support with pandoc-citeproc"
	@echo "   ✓ Live rebuild with file watching"
	@echo "   ✓ Dependency checking and validation"
	@echo "   ✓ Self-updating from GitHub gist"

# Detailed help
help: readme
	@echo ""
	@echo "🔧 DETAILED HELP"
	@echo "================"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make pdf TEMPLATE=custom.latex        # Use specific template"
	@echo "  make pdf EXCLUDE_FILES=\"README.md\"   # Custom exclusions"
	@echo "  make templates                        # List available templates"
	@echo "  make download-eisvogel                # Download latest Eisvogel"
	@echo "  make all                              # Build all formats"

# Debug information
debug:
	@echo "Debug Information:"
	@echo "MD_FILES: $(MD_FILES)"
	@echo "MMD_FILES: $(MMD_FILES)"
	@echo "IMAGE_FILES: $(IMAGE_FILES)"
	@echo "TEMPLATE_ARG: $(TEMPLATE_ARG)"
	@echo "DEFAULT_TEMPLATE: $(DEFAULT_TEMPLATE)"
	@echo "AVAILABLE_TEMPLATES: $(AVAILABLE_TEMPLATES)"
