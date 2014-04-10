DESTDIR?=

CFLAGS=--target-glib=2.38 --pkg gtk+-3.0
LDFLAGS=-X -DGETTEXT_PACKAGE=\"$(BINARY)\"
SOURCE=wpset.vala
BINARY=wpset

all:
	valac $(CFLAGS) $(LDFLAGS) $(SOURCE) -o $(BINARY)

clean:
	rm $(BINARY)
	rm po/sr/$(BINARY).mo

gen_mo:
	msgfmt -c -v -o po/sr/$(BINARY).mo po/sr/$(BINARY).po

gen_po:
	xgettext --language=C --keyword=_ --escape --sort-output -o po/$(BINARY).pot $(SOURCE)
	msgmerge -s -U po/sr/$(BINARY).po po/$(BINARY).pot

install: all gen_mo
	install -Dm755 $(BINARY) $(DESTDIR)/usr/bin/$(BINARY)
	install -Dm755 data/$(BINARY)-shell $(DESTDIR)/usr/bin/$(BINARY)-shell
	install -Dm644 data/org.alphaos.$(BINARY).gschema.xml $(DESTDIR)/usr/share/glib-2.0/schemas/org.alphaos.$(BINARY).gschema.xml
	install -Dm644 po/sr/$(BINARY).mo $(DESTDIR)/usr/share/locale/sr/LC_MESSAGES/$(BINARY).mo

uninstall:
	rm $(DESTDIR)/usr/bin/$(BINARY)
	rm $(DESTDIR)/usr/bin/$(BINARY)-shell
	rm $(DESTDIR)/usr/share/glib-2.0/schemas/org.alphaos.$(BINARY).gschema.xml
	rm $(DESTDIR)/usr/share/locale/sr/LC_MESSAGES/$(BINARY).mo