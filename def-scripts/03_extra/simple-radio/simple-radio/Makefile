DESTDIR?=

CFLAGS=--target-glib=2.38 --pkg gtk+-3.0 --pkg libmp-control
LDFLAGS=-X -DGETTEXT_PACKAGE=\"$(BINARY)\"
SOURCE=simple-radio.vala
BINARY=simple-radio

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
	install -Dm755 data/$(BINARY)-notify $(DESTDIR)/usr/bin/$(BINARY)-notify
	install -Dm644 data/$(BINARY)-play.png $(DESTDIR)/usr/share/icons/hicolor/96x96/apps/$(BINARY)-play.png
	install -Dm644 data/$(BINARY)-stop.png $(DESTDIR)/usr/share/icons/hicolor/96x96/apps/$(BINARY)-stop.png
	install -Dm644 data/$(BINARY)-notification.png $(DESTDIR)/usr/share/icons/hicolor/96x96/apps/$(BINARY)-notification.png
	install -Dm644 data/$(BINARY).desktop $(DESTDIR)/usr/share/applications/$(BINARY).desktop
	install -Dm644 data/org.alphaos.$(BINARY).gschema.xml $(DESTDIR)/usr/share/glib-2.0/schemas/org.alphaos.$(BINARY).gschema.xml
	install -Dm644 po/sr/$(BINARY).mo $(DESTDIR)/usr/share/locale/sr/LC_MESSAGES/$(BINARY).mo

uninstall:
	rm $(DESTDIR)/usr/bin/$(BINARY)
	rm $(DESTDIR)/usr/bin/$(BINARY)-notify
	rm $(DESTDIR)/usr/share/icons/hicolor/96x96/apps/$(BINARY)-play.png
	rm $(DESTDIR)/usr/share/icons/hicolor/96x96/apps/$(BINARY)-stop.png
	rm $(DESTDIR)/usr/share/icons/hicolor/96x96/apps/$(BINARY)-notification.png
	rm $(DESTDIR)/usr/share/applications/$(BINARY).desktop
	rm $(DESTDIR)/usr/share/glib-2.0/schemas/org.alphaos.$(BINARY).gschema.xml
	rm $(DESTDIR)/usr/share/locale/sr/LC_MESSAGES/$(BINARY).mo