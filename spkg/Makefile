DESTDIR?=

install:
	install -Dm755 spkg $(DESTDIR)/usr/bin/spkg
	install -Dm755 paka $(DESTDIR)/usr/bin/paka
	install -Dm644 data/main.config $(DESTDIR)/etc/spkg/main.config
	install -Dm644 data/main.functions $(DESTDIR)/etc/spkg/main.functions
	install -Dm644 data/application-x-spkg.png $(DESTDIR)/usr/share/icons/hicolor/128x128/mimetypes/application-x-spkg.png
	install -Dm644 data/spkg.xml $(DESTDIR)/usr/share/mime/packages/spkg.xml
	install -Dm644 data/def.xml $(DESTDIR)/usr/share/mime/packages/def.xml

uninstall:
	rm -r $(DESTDIR)/usr/bin/spkg
	rm -r $(DESTDIR)/usr/bin/paka
	rm -r $(DESTDIR)/etc/spkg/main.config
	rm -r $(DESTDIR)/etc/spkg/main.functions
	rm -r $(DESTDIR)/usr/share/icons/hicolor/128x128/mimetypes/application-x-spkg.png
	rm -r $(DESTDIR)/usr/share/mime/packages/spkg.xml
	rm -r $(DESTDIR)/usr/share/mime/packages/def.xml