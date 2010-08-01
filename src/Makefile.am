bin_PROGRAMS = psbrowser

psbrowser_SOURCES = \
	loading.vala \
	bookmarks.vala \
	bookmark-store.vala \
	bookmark-new.vala \
	window.vala \
	main.vala

INCLUDES = \
	-include config.h \
	$(PSBROWSER_CFLAGS) \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DPKGLIBDIR=\""$(pkglibdir)"\"

VALAFLAGS = \
	--thread \
	--vapidir=$(srcdir)/../vapi \
	@PSBROWSER_PACKAGES@

psbrowser_LDADD = \
	$(PSBROWSER_LIBS)
