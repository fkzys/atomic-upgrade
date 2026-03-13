.PHONY: install uninstall reinstall install-conf

PREFIX     = /usr
SYSCONFDIR = /etc
DESTDIR    =
pkgname    = atomic-upgrade

BINDIR       = $(PREFIX)/bin
LIBDIR       = $(PREFIX)/lib/atomic
SHAREDIR     = $(PREFIX)/share
ZSH_COMPDIR  = $(SHAREDIR)/zsh/site-functions
BASH_COMPDIR = $(SHAREDIR)/bash-completion/completions
HOOKSDIR     = $(SHAREDIR)/libalpm/hooks
LICENSEDIR   = $(SHAREDIR)/licenses/$(pkgname)

install:
	install -Dm755 bin/atomic-upgrade     $(DESTDIR)$(BINDIR)/atomic-upgrade
	install -Dm755 bin/atomic-gc          $(DESTDIR)$(BINDIR)/atomic-gc
	install -Dm755 bin/atomic-guard       $(DESTDIR)$(BINDIR)/atomic-guard
	install -Dm755 bin/atomic-rebuild-uki $(DESTDIR)$(BINDIR)/atomic-rebuild-uki

	install -Dm644 lib/atomic/common.sh  $(DESTDIR)$(LIBDIR)/common.sh
	install -Dm755 lib/atomic/fstab.py   $(DESTDIR)$(LIBDIR)/fstab.py
	install -Dm755 lib/atomic/rootdev.py $(DESTDIR)$(LIBDIR)/rootdev.py

	install -Dm644 completions/_atomic-gc \
		$(DESTDIR)$(ZSH_COMPDIR)/_atomic-gc
	install -Dm644 completions/_atomic-rebuild-uki \
		$(DESTDIR)$(ZSH_COMPDIR)/_atomic-rebuild-uki
	install -Dm644 completions/atomic-gc.bash \
		$(DESTDIR)$(BASH_COMPDIR)/atomic-gc
	install -Dm644 completions/atomic-rebuild-uki.bash \
		$(DESTDIR)$(BASH_COMPDIR)/atomic-rebuild-uki

	install -Dm644 hooks/00-block-direct-upgrade.hook \
		$(DESTDIR)$(HOOKSDIR)/00-block-direct-upgrade.hook

	install -Dm755 extras/pacman-wrapper $(DESTDIR)$(PREFIX)/local/bin/pacman

	install -Dm644 LICENSE $(DESTDIR)$(LICENSEDIR)/LICENSE

	@if [ ! -f "$(DESTDIR)$(SYSCONFDIR)/atomic.conf" ]; then \
		install -Dm644 etc/atomic.conf "$(DESTDIR)$(SYSCONFDIR)/atomic.conf"; \
		echo "Installed default config"; \
	else \
		echo "Config exists, skipping (see etc/atomic.conf for defaults)"; \
	fi

uninstall:
	rm -f  $(DESTDIR)$(BINDIR)/atomic-upgrade
	rm -f  $(DESTDIR)$(BINDIR)/atomic-gc
	rm -f  $(DESTDIR)$(BINDIR)/atomic-guard
	rm -f  $(DESTDIR)$(BINDIR)/atomic-rebuild-uki
	rm -rf $(DESTDIR)$(LIBDIR)/
	rm -f  $(DESTDIR)$(ZSH_COMPDIR)/_atomic-gc
	rm -f  $(DESTDIR)$(ZSH_COMPDIR)/_atomic-rebuild-uki
	rm -f  $(DESTDIR)$(BASH_COMPDIR)/atomic-gc
	rm -f  $(DESTDIR)$(BASH_COMPDIR)/atomic-rebuild-uki
	rm -f  $(DESTDIR)$(HOOKSDIR)/00-block-direct-upgrade.hook
	rm -f  $(DESTDIR)$(PREFIX)/local/bin/pacman
	rm -rf $(DESTDIR)$(LICENSEDIR)/
	@echo "Note: $(SYSCONFDIR)/atomic.conf preserved. Remove manually if needed."

reinstall: uninstall install

install-conf:
	install -Dm644 etc/atomic.conf $(DESTDIR)$(SYSCONFDIR)/atomic.conf
	@echo "Config force-installed."
