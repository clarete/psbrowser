bin_PROGRAMS = psbrowser

psbrowser_SOURCES = \
	main.vala

INCLUDES = \
	-include config.h \
	$(PSBROWSER_CFLAGS) \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DPKGLIBDIR=\""$(pkglibdir)"\"

VALAFLAGS = \
	--vapidir=$(srcdir)/../vapi \
	@PSBROWSER_PACKAGES@

psbrowser_LDADD = \
	$(PSBROWSER_LIBS)
