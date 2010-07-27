#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.65])
AC_INIT([psbrowser], [0.1], [http://projects.comum.org/psbrowser])
AC_CONFIG_SRCDIR([src/main.vala])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([foreign])

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

AM_MAINTAINER_MODE

AC_PROG_CC
AC_PROG_CC_STDC
AM_PROG_VALAC([0.7.0])
AC_PROG_INSTALL

pkg_modules="gtk+-2.0 >= 2.14.0"
PSBROWSER_PACKAGES="--pkg gtk+-2.0"
PKG_CHECK_MODULES(PSBROWSER, [$pkg_modules])
AC_SUBST(PSBROWSER_CFLAGS)
AC_SUBST(PSBROWSER_LIBS)
AC_SUBST(PSBROWSER_PACKAGES)

AC_CONFIG_FILES([
	Makefile
        vapi/Makefile
        src/Makefile
])

AC_OUTPUT