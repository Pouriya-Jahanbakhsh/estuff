# {{header_comment}}

CFG_DIR      = $(CURDIR)/config
TOOLS_DIR    = $(CURDIR)/tools
REBAR        = $(TOOLS_DIR)/rebar3
ERL         := $(shell command -v erl 2> /dev/null)
RELEASE_DIR  = $(CURDIR)/_build/default/rel/{{name}}
VERSION     := $(shell erl -noshell -eval 'io:format("~s", [case file:consult("$(CURDIR)/src/{{name}}.app.src") of {ok, [{_, _, Terms}]} -> proplists:get_value(vsn, Terms, "0.0.0"); _ -> "0.0.0" end]),erlang:halt().')
RELEASE_NAME = {{name}}-$(VERSION)
NAME_UPPER  := $(shell echo {{name}} | awk '{print toupper($$1)}')
BUILD_KEY    = $(NAME_UPPER)_BUILD
EXPORT_VERSION = export $(NAME_UPPER)_VERSION=$(VERSION)

PRE         = @
POST        =
BUILD_DEBUG = 0
REBAR_DEBUG =

v = 1
ifeq ($(v),0)
POST = > /dev/null
endif

ifeq ($(v),2)
PRE =
endif

ifeq ($(v),3)
PRE         =
BUILD_DEBUG = 1
endif

ifeq ($(v),4)
PRE         =
BUILD_DEBUG = 1
REBAR_DEBUG = 1
endif

EXPORT_REBAR_DEBUG = export DEBUG=$(REBAR_DEBUG)
EXPORT_BUILD_DEBUG = export $(NAME_UPPER)_BUILD_DEBUG=$(BUILD_DEBUG)

coverage = 0
ifeq ($(coverage),0)
coverage = /dev/null
endif



ifndef ERL
$(error Could not found Erlang/OTP ('erl' command) installed on this system.)
endif


.PHONY: all compile shell docs test dialyzer cover release package package-src package-app package-release clean clean-packages distclean docker push


all: test docs package


compile:
	@ echo Compiling code
	$(PRE) \
            export $(BUILD_KEY)=COMPILE && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) compile \
        $(POST)
	$(PRE) cp -r $(CURDIR)/_build/default/lib/{{name}}/ebin $(CURDIR)


shell:
	@ echo Compiling user_default module
	$(PRE) erlc -o $(TOOLS_DIR) $(TOOLS_DIR)/user_default.erl $(POST)
	$(PRE) \
            export $(BUILD_KEY)=SHELL && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) compile \
        $(POST) && \
        erl     -pa `ls -d _build/default/lib/*/ebin` \
                -pz $(TOOLS_DIR) \
                -config $(CFG_DIR)/sys.config \
                -args_file $(CFG_DIR)/vm.args \
                -eval "begin application:load('{{name}}'), catch code:load_file('{{name}}') end" \
                +B


docs:
	@ echo Building documentation
	$(PRE) \
            export $(BUILD_KEY)=DOC && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) edoc \
        $(POST)


test: cover dialyzer


dialyzer: compile
	@ echo Running dialyzer
	$(PRE) \
            export $(BUILD_KEY)=DIALYZER && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) dialyzer \
        $(POST)


cover: compile
	@ echo Running tests
	$(PRE) \
            export $(BUILD_KEY)=TEST && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) do ct, cover \
        $(POST)
	@ echo Coverage summary:
	$(PRE) \
            awk -f $(TOOLS_DIR)/coverage_summary.awk \
                -v indent="\t" \
                -v colorize=1 \
                $(CURDIR)/_build/test/cover/index.html \
            || true
	$(PRE) \
            awk -f $(TOOLS_DIR)/coverage_summary.awk \
                   $(CURDIR)/_build/test/cover/index.html \
            > $(coverage) || true


release: compile
	@ echo Building release $(RELEASE_NAME)
	$(PRE) \
            export $(BUILD_KEY)=RELEASE && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) release \
        $(POST)
	$(PRE) mkdir -p $(CURDIR)/$(RELEASE_NAME) $(POST)
	$(PRE) cp -r $(RELEASE_DIR)/* $(CURDIR)/$(RELEASE_NAME) $(POST)


package-release: release clean-packages
	@ echo Packaging release to $(RELEASE_NAME)-release.tar.gz
	$(PRE) \
            rm -rf .tar && \
            find $(RELEASE_NAME)/ -type f > .tar && \
            tar -zcvf $(RELEASE_NAME)-release.tar.gz -T .tar $(POST) && \
            rm -rf .tar $(POST)

package-src: compile clean-packages
	@ echo Packaging source to $(RELEASE_NAME)-src.tar.gz
	$(PRE) \
            rm -rf .tar && \
            find src/ -type f > .tar && \
            find include/ -type f >> .tar || true && \
            find config/ -type f >> .tar || true && \
            find tools/ -type f >> .tar || true && \
            find test/ -type f >> .tar || true && \
            find priv/ -type f >> .tar || true && \
            echo Dockerfile >> .tar || true && \
            echo LICENSE >> .tar || true && \
            echo Makefile >> .tar && \
            echo README.md >> .tar || true && \
            echo rebar.config >> .tar || true && \
            echo rebar.config.script >> .tar && \
            tar -zcvf $(RELEASE_NAME)-src.tar.gz -T .tar $(POST) && \
            rm -rf .tar $(POST)


package-app: compile clean-packages
	@ echo Packaging application to $(RELEASE_NAME)-app.tar.gz
	$(PRE) \
            rm -rf .tar && \
            find src/ -type f > .tar && \
            find include/ -type f >> .tar || true && \
            find ebin/ -type f >> .tar && \
            find priv/ -type f >> .tar || true && \
            tar -zcvf $(RELEASE_NAME)-app.tar.gz -T .tar $(POST) && \
            rm -rf .tar $(POST)


package: package-src package-app package-release


clean: clean-packages
	@ echo Cleaning out
	$(PRE) \
            export $(BUILD_KEY)=CLEAN && \
            $(EXPORT_REBAR_DEBUG) && \
            $(EXPORT_VERSION) && \
            $(EXPORT_BUILD_DEBUG) && \
            $(REBAR) clean $(POST)
	$(PRE) rm -rf $(CURDIR)/ebin $(POST)


clean-packages:
	$(PRE) rm -rf $(RELEASE_NAME)-*.tar.gz $(POST)


distclean: clean
	$(PRE) rm -rf _build rebar.lock $(RELEASE_NAME) $(RELEASE_NAME)-*.tar.gz ebin tools/user_default.beam *.crashdump $(POST)


docker:
	$(PRE) docker build -t {{name}} ./ $(POST)


push: cover
	@ echo Pushing to master branch
	$(PRE) git push origin master
