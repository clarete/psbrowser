bin_PROGRAMS = psbrowser

AM_LDFLAGS = -Wl,--export-dynamic

psbrowser_SOURCES = \
	loading.vala \
	bookmarks.vala \
	bookmark-store.vala \
	bookmark-new.vala \
	node-new.vala \
	resources.vala \
	window.vala \
	connections.vala \
	main.vala

VALAFLAGS = \
	--thread \
	--vapidir=$(srcdir)/../vapi \
	--pkg config \
	@PSBROWSER_PACKAGES@

AM_CPPFLAGS = \
	-DCONFIG_PKGDATADIR=\""$(pkgdatadir)"\" \
	$(PSBROWSER_CFLAGS) \
	-include $(CONFIG_HEADER)

psbrowser_LDADD = \
	$(PSBROWSER_LIBS)
