# does not use ExtUtils::MakeMaker, because
# NOTEDB::mysql and NOTEDB::binary are internals
# of note.
#
# $Id: Makefile.PL,v 1.2 2000/08/10 09:21:56 zarahg Exp $
# 
# check for the existence of optional modules:
sub chk_mod
{
	my($mod, $msg) = @_;
	print "<====\tchecking $mod \t====>\n";
	eval {
		$mod .= ".pm";
		$mod =~ s/::/\//g;
		require $mod;
	};
	if($@) {
		print $msg;
	}
	else {
		print "  ... installed.\n";
	}
	print "\n";
}

&chk_mod(
	"Getopt::Long",
	"WARNING: Getopt::Long seems not to be installed on your system!\n"
	."But it is strongly required in order to run note!\n"
	);

&chk_mod(
        "DB_File",
        "WARNING: DB_File seems not to be installed on your system!\n"
        ."It is required, if you want to use the DBM backend.\n"
        );


&chk_mod(
	"DBI",
	" WARNING: module DBI is not installed on your system.\n"
	." It is required, if you want to use a SQL database with\n"
	."note.\n"
	);

&chk_mod(
	"Crypt::IDEA",
	" WARNING: module Crypt::IDEA is not installed on your system.\n"
	." It is required, if you want to encrypt your data using IDEA.\n"
	);

&chk_mod(
        "Crypt::DES",
        " WARNING: module Crypt::DES is not installed on your system.\n"
        ." It is required, if you want to encrypt your data using DES.\n"
        ); 

&chk_mod(
        "Crypt::CBC",
        " WARNING: module Crypt::CBC is not installed on your system.\n"
        ." It is required, if you want to encrypt your data using CBC.\n"
        );

&chk_mod(
        "MD5",
        " WARNING: module MD5 is not installed on your system.\n"
        ." It is required by Crypt::CBC.\n"
        );

foreach $dir (@INC) {
	if($dir =~ /site_perl/)
	{ $LIBDIR = $dir; last; }
}
print "directory, where to install libs [$LIBDIR]: ";
$input = <>;
chomp $input;
$LIBDIR = $input if($input ne "");

$BINDIR = "/usr/local/bin";
print "directory, where to install note [$BINDIR]: ";
$input = <>;
chomp $input;
$BINDIR = $input if($input ne "");

$install = `which install`;

open M, "> Makefile" || die $!;
print M qq~BIN = bin/note
MAN = note.1
LIBS = NOTEDB/mysql.pm NOTEDB/binary.pm NOTEDB/dbm.pm
CORE = NOTEDB.pm
INSTBIN = $BINDIR
INSTLIB = $LIBDIR
INSTMAN = /usr/man/man1
INSTALL = $install
all:
	\@echo "done. Type make install.\\n"

install:
	\$(INSTALL) -m 755 \$(CORE) \$(INSTLIB)
	\$(INSTALL) -d -m 755 \$(INSTLIB)/NOTEDB
	\$(INSTALL) -m 755 \$(LIBS) \$(INSTLIB)/NOTEDB
	\$(INSTALL) -m 755 \$(BIN) \$(INSTBIN)
	\$(INSTALL) -m 644 \$(MAN) \$(INSTMAN)
~;

print "Type \"make install\" to install all files.\n\n";
print "Please note: You may also copy the file \"config/noterc\" to\n"
      ."your home: \"cp config/noterc ~/.noterc\". Don't forget to edit\n"
      ."your config-file. Read the README for more informations on this\n"
      ."topic.\n"
      ."Thanks for choosing \"note\"! You are helping to keep the \n"
      ."OpenSource idea alive! Enjoy and tell me, what you think!\n\n";
