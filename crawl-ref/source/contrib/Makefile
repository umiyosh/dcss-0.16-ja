PREFIX := install

SUBDIRS = sqlite sdl2 sdl2-image sdl2-mixer freetype libpng pcre zlib
ARCH = unknown

# On macOS these come from upstream releases via build-macos-deps.sh rather
# than from the submodules below, which are 2014 snapshots that no longer
# compile. Building them here rather than taking Homebrew's bottles is what
# fixes the deployment target: a bottle is built for the exact macOS of the
# build machine, so a bundle carrying one only runs on that macOS or newer.
# sqlite and lua still come from the submodules; those still build.
ifeq ($(shell uname -s),Darwin)
  MACOS_DEPS := sdl2 sdl2-image freetype libpng zlib
endif

ifdef USE_LUAJIT
SUBDIRS += luajit/src
else
SUBDIRS += lua/src
endif

# After every addition to SUBDIRS, or lua/src ends up with no rule at all and
# make quietly reports nothing to be done for it.
SUBMODULE_SUBDIRS := $(filter-out $(MACOS_DEPS),$(SUBDIRS))

all:
	@$(MAKE) $(SUBDIRS)

clean distclean:
	@for a in $(SUBDIRS); do \
	    $(MAKE) -C $$a distclean; \
	done
	rm -rf $(PREFIX)

$(MACOS_DEPS):
	@ARCH=$(ARCH) PREFIX=$(PREFIX) ./build-macos-deps.sh $@

$(SUBMODULE_SUBDIRS):
	@if [ ! -x $@ ]; then \
	    echo "**********************************************************"; \
	    echo; \
	    echo "The '$@' directory is missing. Have you run"; \
	    echo "   'git submodule update --init'?"; \
	    echo "(It's probably better to install all native dependencies instead.)"; \
	    echo; \
	    echo "**********************************************************"; \
	    exit 1; \
	fi
	@if [ ! -f $@/Makefile ] && [ ! -f $@/makefile ]; then \
	    echo "**********************************************************"; \
	    echo; \
	    echo "The '$@' directory exists, but the Makefile is missing!"; \
	    echo "Did 'git submodule update' work properly?"; \
	    echo "(It's probably better to install all native dependencies instead.)"; \
	    echo; \
	    echo "**********************************************************"; \
	    exit 1; \
	fi
	@cd $@ && \
	$(MAKE) all prefix=$(shell echo $@ | perl -pe 's/[^\/]+/../g')/$(PREFIX)/$(ARCH) && \
	$(MAKE) install prefix=$(shell echo $@ | perl -pe 's/[^\/]+/../g')/$(PREFIX)/$(ARCH)

libpng freetype: zlib
sdl2-image: sdl2 libpng
sdl2-mixer: sdl2

.PHONY: $(SUBDIRS)
