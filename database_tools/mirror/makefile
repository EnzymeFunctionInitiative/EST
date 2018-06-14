#
#
#
# Copyright (C) 1990 - 1998   Lee McLoughlin
#
# Permission to use, copy, and distribute this software and its
# documentation for any purpose with or without fee is hereby granted,
# provided that the above copyright notice appear in all copies and
# that both that copyright notice and this permission notice appear
# in supporting documentation.
#
# Permission to modify the software is granted, but not the right to
# distribute the modified code.  Modifications are to be distributed
# as patches to released version.
#
# This software is provided "as is" without express or implied warranty.
#
#
#
WEBFILES = \
	index.html \
	mirror.html mirror.txt \
	quickstart.html quickstart.txt \
	mm.html copyright.html mirror-faq.html \
	Lake.class mirror-on-dusk.gif \
	CHANGES-since-2.8.txt 

FILES=	README.txt \
	mirror.pl \
	lsparse.pl dateconv.pl ftp.pl lchat.pl \
	install.pl \
	makefile \
	mirror.defaults \
	mirror.nightly socket.ph socket.ph-solaris \
	mm.pl pkgs_to_mmin.pl mmin \
	prune_logs.pl do_unlinks.pl \
	support/cyber-patches support/lstest.pl \
	packages/sunsite.org.uk \
	logs/ \
	mirror.man mm.man \
	$(WEBFILES)

all:
	echo try make mirror.tar

mirror.tar: $(FILES)
	rev=`./mirror.pl -v | perl -ane 'print "$$F[2]\n";'`; echo $rev; \
		tar czvf mirror-$$rev.tar.gz $(FILES)

mirror.zip: $(FILES)
	rev=`./mirror.pl -v | perl -ane 'print "$$F[2]\n";'`; echo $rev; \
		rm -f mirror-$$rev.zip ; \
		zip  mirror-$$rev.zip $(FILES)

mirror.shar: $(FILES)
	rev=`./mirror.pl -v | perl -ane 'print "$$F[2]\n";'`; echo $rev; \
		shar $(FILES) > mirror-$$rev.shar

ci:
	checkin $(FILES)

#  install, clean ...
# mode to install .pl files
PLMODE = 644
# mode to install executables
EXMODE = 755
# group to own all the files
GRP = gnu
# directory to install .pl (perl library) files
PLDIR = /usr/local/perl5/lib/perl5
# directory to install public executables
BINDIR = /usr/local/sbin
# directory to install man pages
MANDIR = /usr/local/man/man1

install:
	install -m $(PLMODE) -g $(GRP) lchat.pl $(PLDIR)
	install -m $(PLMODE) -g $(GRP) dateconv.pl $(PLDIR)
	install -m $(PLMODE) -g $(GRP) ftp.pl $(PLDIR)
	install -m $(PLMODE) -g $(GRP) lsparse.pl $(PLDIR)
	install -m $(EXMODE) -g $(GRP) mirror.pl $(BINDIR)/mirror
	install -m $(EXMODE) -g $(GRP) do_unlinks.pl $(BINDIR)/do_unlinks
	install -m $(EXMODE) -g $(GRP) pkgs_to_mmin.pl $(BINDIR)/pkgs_to_mmin
	install -m $(EXMODE) -g $(GRP) mm.pl $(BINDIR)/mirror-master
	install -m $(PLMODE) -g $(GRP) mirror.man $(MANDIR)/mirror.1
	install -m $(PLMODE) -g $(GRP) mm.man $(MANDIR)/mirror-master.1

# directory to install .pl (perl library) files for rperl
RPLDIR = /usr/local/rperl5/lib/perl5

rinstall:
	sed 's/^\#!\/bin\/perl5/\#!\/bin\/rperl5/g' < mirror.pl > rmirror.pl
	install -m $(PLMODE) -g $(GRP) lchat.pl $(RPLDIR)
	install -m $(PLMODE) -g $(GRP) dateconv.pl $(RPLDIR)
	install -m $(PLMODE) -g $(GRP) ftp.pl $(RPLDIR)
	install -m $(PLMODE) -g $(GRP) lsparse.pl $(RPLDIR)
	install -m $(EXMODE) -g $(GRP) rmirror.pl $(BINLDIR)/mirror
	install -m $(EXMODE) -g $(GRP) do_unlinks.pl $(BINDIR)/do_unlinks
	install -m $(EXMODE) -g $(GRP) pkgs_to_mmin.pl $(BINDIR)/pkgs_to_mmin
	install -m $(EXMODE) -g $(GRP) mm.pl $(BINDIR)/mirror-master
	install -m $(PLMODE) -g $(GRP) mirror.man $(MANDIR)/mirror.1
	install -m $(PLMODE) -g $(GRP) mm.man $(MANDIR)/mirror-master.1
