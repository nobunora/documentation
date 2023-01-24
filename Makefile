# The top-level Makefile which builds everything

ASCIIDOC_DIR = documentation/asciidoc
HTML_DIR = documentation/html
JEKYLL_ASSETS_DIR = jekyll-assets
SCRIPTS_DIR = scripts
DOCUMENTATION_REDIRECTS_DIR = documentation/redirects
DOCUMENTATION_INDEX = documentation/index.json
SITE_CONFIG = _config.yml

BUILD_DIR = build
ASCIIDOC_BUILD_DIR = $(BUILD_DIR)/jekyll
ASCIIDOC_INCLUDES_DIR = $(BUILD_DIR)/adoc_includes
AUTO_NINJABUILD = $(BUILD_DIR)/autogenerated.ninja

PICO_SDK_DIR = documentation/pico-sdk
PICO_EXAMPLES_DIR = documentation/pico-examples
DOXYGEN_PICO_SDK_BUILD_DIR = $(BUILD_DIR)/pico-sdk-docs
DOXYGEN_HTML_DIR = $(DOXYGEN_PICO_SDK_BUILD_DIR)/docs/doxygen/html
# The pico-sdk here needs to match up with the "entire_directory" in index.json
ASCIIDOC_DOXYGEN_DIR = $(ASCIIDOC_DIR)/pico-sdk

JEKYLL_CMD = bundle exec jekyll

.DEFAULT_GOAL := html

.PHONY: clean run_ninja clean_ninja html serve_html clean_html build_doxygen_adoc clean_doxygen_adoc

$(BUILD_DIR):
	@mkdir -p $@

# Delete all autogenerated files
clean: clean_html
	rm -rf $(BUILD_DIR)

$(PICO_SDK_DIR)/CMakeLists.txt: | $(PICO_SDK_DIR)
	git submodule update --init $(PICO_SDK_DIR)
	git -C $(PICO_SDK_DIR) submodule update --init

$(PICO_EXAMPLES_DIR)/CMakeLists.txt: | $(PICO_EXAMPLES_DIR)
	git submodule update --init $(PICO_EXAMPLES_DIR)

$(DOXYGEN_PICO_SDK_BUILD_DIR): | $(BUILD_DIR)
	mkdir $@

$(DOXYGEN_PICO_SDK_BUILD_DIR)/Makefile: | $(PICO_SDK_DIR)/CMakeLists.txt $(PICO_EXAMPLES_DIR)/CMakeLists.txt $(DOXYGEN_PICO_SDK_BUILD_DIR)
	cmake -S $(PICO_SDK_DIR) -B $(DOXYGEN_PICO_SDK_BUILD_DIR) -DPICO_EXAMPLES_PATH=`realpath $(PICO_EXAMPLES_DIR)`

$(DOXYGEN_HTML_DIR): | $(DOXYGEN_PICO_SDK_BUILD_DIR)/Makefile
	make -C $(DOXYGEN_PICO_SDK_BUILD_DIR) docs

$(ASCIIDOC_DOXYGEN_DIR): | $(ASCIIDOC_DIR)
	mkdir $@

# Create the Doxygen asciidoc files
# Also need to move index.adoc to a different name, because it conflicts with the autogenerated index.adoc
build_doxygen_adoc: | $(DOXYGEN_HTML_DIR) $(ASCIIDOC_DOXYGEN_DIR)
	python3 $(SCRIPTS_DIR)/transform_doxygen_html.py $(DOXYGEN_HTML_DIR) $(ASCIIDOC_DOXYGEN_DIR)
	cp $(DOXYGEN_HTML_DIR)/*.png $(ASCIIDOC_DOXYGEN_DIR)
	mv $(ASCIIDOC_DOXYGEN_DIR)/index.adoc $(ASCIIDOC_DOXYGEN_DIR)/index_doxygen.adoc

# Clean all the Doxygen files
clean_doxygen_adoc:
	rm -rf $(ASCIIDOC_DIR)/pico-sdk

# AUTO_NINJABUILD contains all the parts of the ninjabuild where the rules themselves depend on other files
$(AUTO_NINJABUILD): $(SCRIPTS_DIR)/create_auto_ninjabuild.py $(DOCUMENTATION_INDEX) $(SITE_CONFIG) | $(BUILD_DIR)
	$< $(DOCUMENTATION_INDEX) $(SITE_CONFIG) $(ASCIIDOC_DIR) $(SCRIPTS_DIR) $(ASCIIDOC_BUILD_DIR) $(ASCIIDOC_INCLUDES_DIR) $(JEKYLL_ASSETS_DIR) $(DOCUMENTATION_REDIRECTS_DIR) $@

# This runs ninjabuild to build everything in the ASCIIDOC_BUILD_DIR (and ASCIIDOC_INCLUDES_DIR)
run_ninja: $(AUTO_NINJABUILD)
	ninja

# Delete all the files created by the 'run_ninja' target
clean_ninja:
	rm -rf $(ASCIIDOC_BUILD_DIR)
	rm -rf $(ASCIIDOC_INCLUDES_DIR)
	rm -f $(AUTO_NINJABUILD)

# Build the html output files
html: run_ninja
	$(JEKYLL_CMD) build

# Build the html output files and additionally run a small webserver for local previews
serve_html: run_ninja
	$(JEKYLL_CMD) serve

# Delete all the files created by the 'html' target
clean_html:
	rm -rf $(HTML_DIR)
