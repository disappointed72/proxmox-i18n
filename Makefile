LINGUAS=de it fr ja es sv ru tr zh_CN da ca pl sl nb nn pt_BR eu fa gl hu

VERSION=1.0
PKGREL=2

PVE_I18N_DEB=pve-i18n_${VERSION}-${PKGREL}_all.deb
PMG_I18N_DEB=pmg-i18n_${VERSION}-${PKGREL}_all.deb

DEBS=${PMG_I18N_DEB} ${PVE_I18N_DEB}

PMGLOCALEDIR=${DESTDIR}/usr/share/pmg-i18n
PVELOCALEDIR=${DESTDIR}/usr/share/pve-i18n

PMG_LANG_FILES=$(patsubst %, pmg-lang-%.js, $(LINGUAS))
PVE_LANG_FILES=$(patsubst %, pve-lang-%.js, $(LINGUAS))

all:

.PHONY: deb
deb: $(DEBS)
$(DEBS): | submodule
	rm -rf dest
	rsync -a * dest
	cd dest; dpkg-buildpackage -b -us -uc
	lintian $(DEBS)

.PHONY: submodule
submodule:
	test -f "pmg-gui/Makefile" || git submodule update --init

.PHONY: install
install: ${PMG_LANG_FILES} ${PVE_LANG_FILES}
	install -d ${PMGLOCALEDIR}
	install -m 0644 ${PMG_LANG_FILES} ${PMGLOCALEDIR}
	install -d ${PVELOCALEDIR}
	install -m 0644 ${PVE_LANG_FILES} ${PVELOCALEDIR}


pmg-lang-%.js: %.po
	./po2js.pl -t pmg -v "${VERSION}-${PKGREL}" -o pmg-lang-$*.js $?

pve-lang-%.js: %.po
	./po2js.pl -t pve -v "${VERSION}-${PKGREL}" -o pve-lang-$*.js $?

# parameter 1 is the name
# parameter 2 is the directory
define potupdate
    ./jsgettext.pl -p "$(1) $(shell cd $(2);git rev-parse HEAD)" -o $(1).pot $(2)
endef

.PHONY: update update_pot
update_pot: submodule
	git submodule foreach 'git pull --ff-only origin master'
	$(call potupdate,proxmox-widget-toolkit,proxmox-widget-toolkit/)
	$(call potupdate,pve-manager,pve-manager/www/manager6/)
	$(call potupdate,proxmox-mailgateway,pmg-gui/js/)

update: | update_pot messages.pot
	for i in $(LINGUAS); do echo -n "$$i: "; msgmerge -s -v $$i.po messages.pot >$$i.po.tmp && mv $$i.po.tmp $$i.po; done;

init-%.po: messages.pot
	msginit -i $^ -l $^ -o $*.po --no-translator

.INTERMEDIATE: messages.pot
messages.pot: proxmox-widget-toolkit.pot proxmox-mailgateway.pot pve-manager.pot
	msgcat $^ > $@

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	find . -name '*~' -exec rm {} ';'
	rm -rf dest *.po.tmp *.js.tmp *.deb *.buildinfo *.changes *.js messages.pot

.PHONY: upload-pve
upload-pve: ${PVE_I18N_DEB}
	tar cf - ${PVE_I18N_DEB}|ssh -X repoman@repo.proxmox.com -- upload --product pve --dist stretch

.PHONY: upload-pmg
upload-pmg: ${PMG_I18N_DEB}
	tar cf - ${PMG_I18N_DEB}|ssh -X repoman@repo.proxmox.com -- upload --product pmg --dist stretch
