DESTDIR?=

CFLAGS=--target-glib=2.38 --pkg gio-2.0 --pkg gdk-x11-3.0
LDFLAGS=-X -fPIC -X -shared -X -Wl,-soname,$(SONAME) -o $(LIBRARY).so.$(VERSION)
LIBRARY=libmp-control
VERSION=0.0.1
SONAME=$(LIBRARY).so.0

all:
	valac --library=$(LIBRARY) -H $(LIBRARY).h $(LIBRARY).vala $(LDFLAGS) $(CFLAGS)
	ln -sf $(LIBRARY).so.$(VERSION) $(LIBRARY).so
	ln -sf $(LIBRARY).so.$(VERSION) $(SONAME)

clean:
	rm $(LIBRARY).h
	rm $(LIBRARY).so.$(VERSION)
	rm $(LIBRARY).so
	rm $(SONAME)
	rm $(LIBRARY).vapi

install: all
	install -Dm755 $(LIBRARY).so.$(VERSION) $(DESTDIR)/usr/lib/$(LIBRARY).so.$(VERSION)
	cp -R $(LIBRARY).so $(DESTDIR)/usr/lib/$(LIBRARY).so
	cp -R $(SONAME) $(DESTDIR)/usr/lib/$(SONAME)
	install -Dm644 $(LIBRARY).h $(DESTDIR)/usr/include/$(LIBRARY).h
	install -Dm644 $(LIBRARY).vapi $(DESTDIR)/usr/share/vala/vapi/$(LIBRARY).vapi
	install -Dm644 data/$(LIBRARY).deps $(DESTDIR)/usr/share/vala/vapi/$(LIBRARY).deps
	install -Dm644 data/$(LIBRARY).pc $(DESTDIR)/usr/lib/pkgconfig/$(LIBRARY).pc

uninstall:
	rm $(DESTDIR)/usr/lib/$(LIBRARY).so.$(VERSION)
	rm $(DESTDIR)/usr/lib/$(LIBRARY).so
	rm $(DESTDIR)/usr/lib/$(SONAME)
	rm $(DESTDIR)/usr/include/$(LIBRARY).h
	rm $(DESTDIR)/usr/share/vala/vapi/$(LIBRARY).vapi
	rm $(DESTDIR)/usr/share/vala/vapi/$(LIBRARY).deps
	rm $(DESTDIR)/usr/lib/pkgconfig/$(LIBRARY).pc