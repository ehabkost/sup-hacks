
SHELL = /bin/sh

#### Start of system configuration section. ####

srcdir = .
topdir = /usr/lib/ruby/1.8/i486-linux
hdrdir = $(topdir)
VPATH = $(srcdir):$(topdir):$(hdrdir)
prefix = $(DESTDIR)/usr
exec_prefix = $(DESTDIR)/usr
sitedir = $(DESTDIR)/usr/local/lib/site_ruby
rubylibdir = $(libdir)/ruby/$(ruby_version)
docdir = $(datarootdir)/doc/$(PACKAGE)
dvidir = $(docdir)
datarootdir = $(prefix)/share
archdir = $(rubylibdir)/$(arch)
sbindir = $(exec_prefix)/sbin
psdir = $(docdir)
localedir = $(datarootdir)/locale
htmldir = $(docdir)
datadir = $(prefix)/share
includedir = $(prefix)/include
infodir = $(datarootdir)/info
sysconfdir = $(DESTDIR)/etc
mandir = $(datadir)/man
libdir = $(DESTDIR)/usr/lib
sharedstatedir = $(prefix)/com
oldincludedir = $(DESTDIR)/usr/include
pdfdir = $(docdir)
sitearchdir = $(sitelibdir)/$(sitearch)
bindir = $(exec_prefix)/bin
localstatedir = $(DESTDIR)/var
sitelibdir = $(sitedir)/$(ruby_version)
libexecdir = $(exec_prefix)/libexec

CC = gcc
LIBRUBY = $(LIBRUBY_SO)
LIBRUBY_A = lib$(RUBY_SO_NAME)-static.a
LIBRUBYARG_SHARED = -l$(RUBY_SO_NAME)
LIBRUBYARG_STATIC = -l$(RUBY_SO_NAME)-static

RUBY_EXTCONF_H = 
CFLAGS   =  -fPIC -Wall -g -fno-strict-aliasing -O2  -fPIC -g 
INCFLAGS = -I. -I. -I/usr/lib/ruby/1.8/i486-linux -I.
CPPFLAGS = -DHAVE_UNISTD_H -DHAVE_NCURSES_H -DHAVE_NEWSCR -DHAVE_TABSIZE -DHAVE_ESCDELAY -DHAVE_KEYBOUND -DHAVE_CURSES_VERSION -DHAVE_TIGETSTR -DHAVE_GETWIN -DHAVE_PUTWIN -DHAVE_UNGETMOUSE -DHAVE_MOUSEMASK -DHAVE_WENCLOSE -DHAVE_MOUSEINTERVAL -DHAVE_WMOUSE_TRAFO -DHAVE_MCPRINT -DHAVE_HAS_KEY -DHAVE_DELSCREEN -DHAVE_DEFINE_KEY -DHAVE_KEYOK -DHAVE_RESIZETERM -DHAVE_USE_DEFAULT_COLORS -DHAVE_USE_EXTENDED_NAMES -DHAVE_WRESIZE -DHAVE_ATTR_ON -DHAVE_ATTR_OFF -DHAVE_ATTR_SET -DHAVE_CHGAT -DHAVE_COLOR_SET -DHAVE_FILTER -DHAVE_INTRFLUSH -DHAVE_MVCHGAT -DHAVE_MVHLINE -DHAVE_MVVLINE -DHAVE_MVWCHGAT -DHAVE_MVWHLINE -DHAVE_MVWVLINE -DHAVE_NOQIFLUSH -DHAVE_PUTP -DHAVE_QIFLUSH -DHAVE_SCR_DUMP -DHAVE_SCR_INIT -DHAVE_SCR_RESTORE -DHAVE_SCR_SET -DHAVE_SLK_ATTR -DHAVE_SLK_ATTR_SET -DHAVE_SLK_COLOR -DHAVE_TIGETFLAG -DHAVE_TIGETNUM -DHAVE_USE_ENV -DHAVE_VIDATTR -DHAVE_WATTR_ON -DHAVE_WATTR_OFF -DHAVE_WATTR_SET -DHAVE_WCHGAT -DHAVE_WCOLOR_SET -DHAVE_ASSUME_DEFAULT_COLORS -DHAVE_ATTR_GET -DHAVE_PANEL_H -DHAVE_FORM_H 
CXXFLAGS = $(CFLAGS) 
DLDFLAGS =  -rdynamic -Wl,-export-dynamic  
LDSHARED = $(CC) -shared
AR = ar
EXEEXT = 

RUBY_INSTALL_NAME = ruby1.8
RUBY_SO_NAME = ruby1.8
arch = i486-linux
sitearch = i486-linux
ruby_version = 1.8
ruby = /usr/bin/ruby1.8
RUBY = $(ruby)
RM = rm -f
MAKEDIRS = mkdir -p
INSTALL = /usr/bin/install -c
INSTALL_PROG = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 644
COPY = cp

#### End of system configuration section. ####

preload = 

libpath = $(libdir)
LIBPATH =  -L"$(libdir)"
DEFFILE = 

CLEANFILES = 
DISTCLEANFILES = 

extout = 
extout_prefix = 
target_prefix = 
LOCAL_LIBS = 
LIBS = $(LIBRUBYARG_SHARED) -lform -lpanel -lncurses  -lpthread -ldl -lcrypt -lm   -lc
SRCS = ncurses_wrap.c panel_wrap.c form_wrap.c
OBJS = ncurses_wrap.o panel_wrap.o form_wrap.o
TARGET = ncurses
DLLIB = $(TARGET).so
EXTSTATIC = 
STATIC_LIB = 

RUBYCOMMONDIR = $(sitedir)$(target_prefix)
RUBYLIBDIR = /var/lib/gems/1.8/gems/ncurses-0.9.1/lib$(target_prefix)
RUBYARCHDIR = /var/lib/gems/1.8/gems/ncurses-0.9.1/lib$(target_prefix)

TARGET_SO     = $(DLLIB)
CLEANLIBS     = $(TARGET).so $(TARGET).il? $(TARGET).tds $(TARGET).map
CLEANOBJS     = *.o *.a *.s[ol] *.pdb *.exp *.bak

all:		$(DLLIB)
static:		$(STATIC_LIB)

clean:
		@-$(RM) $(CLEANLIBS) $(CLEANOBJS) $(CLEANFILES)

distclean:	clean
		@-$(RM) Makefile $(RUBY_EXTCONF_H) conftest.* mkmf.log
		@-$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)

realclean:	distclean
install: install-so install-rb

install-so: $(RUBYARCHDIR)
install-so: $(RUBYARCHDIR)/$(DLLIB)
$(RUBYARCHDIR)/$(DLLIB): $(DLLIB)
	$(INSTALL_PROG) $(DLLIB) $(RUBYARCHDIR)
install-rb: pre-install-rb install-rb-default
install-rb-default: pre-install-rb-default
pre-install-rb: Makefile
pre-install-rb-default: Makefile
pre-install-rb-default: $(RUBYLIBDIR)
install-rb-default: $(RUBYLIBDIR)/ncurses.rb
$(RUBYLIBDIR)/ncurses.rb: $(srcdir)/lib/ncurses.rb
	$(INSTALL_DATA) $(srcdir)/lib/ncurses.rb $(@D)
$(RUBYARCHDIR):
	$(MAKEDIRS) $@
$(RUBYLIBDIR):
	$(MAKEDIRS) $@

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

.SUFFIXES: .c .m .cc .cxx .cpp .C .o

.cc.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.cxx.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.cpp.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.C.o:
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $<

.c.o:
	$(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) -c $<

$(DLLIB): $(OBJS)
	@-$(RM) $@
	$(LDSHARED) $(DLDFLAGS) $(LIBPATH) -o $@ $(OBJS) $(LOCAL_LIBS) $(LIBS)



$(OBJS): ruby.h defines.h
