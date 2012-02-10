#!/usr/bin/perl
# $Id: binary.pm,v 1.4 2000/04/17 17:39:27 thomas Exp thomas $
# Perl module for note
# binary database backend. see docu: perldoc NOTEDB::binary
#
use strict;
use Data::Dumper;
use IO::Seekable;

package NOTEDB;
use Fcntl qw(LOCK_EX LOCK_UN);
BEGIN {
	# make sure, it works, although encryption
	# not supported on this system!
	eval { require Crypt::CBC; };
	if($@) {
		$NOTEDB::crypt_supported = 0;
	}
	else {
		$NOTEDB::crypt_supported = 1;
	}
}
	
# Globals:
my ($NOTEDB, $sizeof, $typedef,$version);
my ($cipher);

$version = "(NOTEDB::binary, 1.4)";


sub new
{
	my($this, $dbdriver, $dbname, $MAX_NOTE, $MAX_TIME) = @_;

	my $class = ref($this) || $this;
	my $self = {};
	bless($self,$class);
	$NOTEDB = $dbname;

	if(! -e $NOTEDB)
	{
	        open(TT,">$NOTEDB") or die "Could not create $NOTEDB: $!\n";
	        close (TT);
	}
	elsif(! -w $NOTEDB)
	{
	        print "$NOTEDB is not writable!\n";
	        exit(1);
	}

	
	my $TYPEDEF = "i a$MAX_NOTE a$MAX_TIME";	
	my $SIZEOF  = length pack($TYPEDEF, () );

	$sizeof = $SIZEOF;
	$typedef = $TYPEDEF;
	return $self;
}


sub DESTROY
{
	# clean the desk!
}

sub version {
        return $version;
}

sub no_crypt {
	$NOTEDB::crypt_supported = 0;
}

sub use_crypt {
	my($this,$key,$method) = @_;
	if($NOTEDB::crypt_supported == 1) {
		eval {
			$cipher = new Crypt::CBC($key, $method);
		};
		if($@) {
                        $NOTEDB::crypt_supported == 0;
                }
	}
	else{
		print "warning: Crypt::CBC not supported by system!\n";
	}
}

sub get_single 
{
	my($this, $num) = @_;
	my($address, $note, $date, $buffer, $n, $t, $buffer, );

	open NOTE, "+<$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 

	$address = ($num-1) * $sizeof;
	seek(NOTE, $address, IO::Seekable::SEEK_SET);
	read(NOTE, $buffer, $sizeof);
	($num, $n, $t) = unpack($typedef, $buffer);

	$note = ude($n);
	$date = ude($t);

	flock NOTE, LOCK_UN;
        close NOTE;
	
	return $note, $date;
}


sub get_all
{
        my($this, $num, $note, $date, %res);

	open NOTE, "+<$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 
	my($buffer, $t, $n);	
	seek(NOTE, 0, 0); # START FROM BEGINNING
	while(read(NOTE, $buffer, $sizeof)) {        
		($num, $note, $date) = unpack($typedef, $buffer);
		$t = ude($date);
                $n = ude($note);
        	$res{$num}->{'note'} = $n;
		$res{$num}->{'date'} = $t;
	}
	flock NOTE, LOCK_UN;
        close NOTE;

	return %res;
}


sub get_nextnum
{
	my($this, $num, $te, $me, $buffer);

	open NOTE, "+<$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 
	
	seek(NOTE, 0, 0); # START FROM BEGINNING 
	while(read(NOTE, $buffer, $sizeof)) {
		($num, $te, $me) = unpack($typedef, $buffer);
	}
	$num += 1;
	flock NOTE, LOCK_UN;
        close NOTE;

	return $num;
}

sub get_search
{
	my($this, $searchstring) = @_;
	my($buffer, $num, $note, $date, %res, $t, $n);

        open NOTE, "+<$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 

	seek(NOTE, 0, 0); # START FROM BEGINNING
	while(read(NOTE, $buffer, $sizeof))
	{
		($num, $note, $date) = unpack($typedef, $buffer);
		$n = ude($note);
                $t = ude($date);
                if($n =~ /$searchstring/i)
                {
			$res{$num}->{'note'} = $n;
                	$res{$num}->{'date'} = $t;
		}
	}
        flock NOTE, LOCK_UN;
        close NOTE;

	return %res;
}




sub set_edit
{
	my($this, $num, $note, $date) = @_;
	my $address = ($num -1 ) * $sizeof;

        open NOTE, "+<$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 

	seek(NOTE, $address, IO::Seekable::SEEK_SET);
	my $n = uen($note);
	my $t = uen($date);

	my $buffer = pack($typedef, $num, $n, $t);
        print NOTE $buffer;

        flock NOTE, LOCK_UN;
        close NOTE;
}


sub set_new
{
	my($this, $num, $note, $date) = @_;
        open NOTE, "+<$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 

	seek(NOTE, 0, IO::Seekable::SEEK_END); # APPEND
        my $n = uen($note);
        my $t = uen($date);
	my $buffer = pack($typedef, $num, $n, $t);
	print NOTE $buffer;

	flock NOTE, LOCK_UN;
        close NOTE;
}


sub set_del
{
        my($this, $num) = @_;
	my(%orig, $note, $date, $T, $setnum, $buffer, $n, $N, $t);

        $setnum = 1;

	%orig = $this->get_all();
	return "ERROR" if (! exists $orig{$num});

	delete $orig{$num};

	# overwrite, but keep number!
	open NOTE, ">$NOTEDB" or die "could not open $NOTEDB\n";
        flock NOTE, LOCK_EX; 
        seek(NOTE, 0, 0); # START FROM BEGINNING
	foreach $N (keys %orig) {
		$n = uen($orig{$N}->{'note'});
		$t = uen($orig{$N}->{'date'});
		$buffer = pack( $typedef, $N, $n, $t); # keep orig number, note have to call recount!
		print NOTE $buffer;
		seek(NOTE, 0, IO::Seekable::SEEK_END);
		$setnum++;
	}
        flock NOTE, LOCK_UN;
        close NOTE;
	return;
}

sub set_recountnums
{
	my($this) = @_;
	my(%orig, $note, $date, $T, $setnum, $buffer, $n, $N, $t);
	
	$setnum = 1;
	%orig = $this->get_all();

	open NOTE, ">$NOTEDB" or die "could not open $NOTEDB\n";
	flock NOTE, LOCK_EX;
	seek(NOTE, 0, 0); # START FROM BEGINNING
	
        foreach $N (sort {$a <=> $b} keys %orig) {
                $n = uen($orig{$N}->{'note'});
                $t = uen($orig{$N}->{'date'});
                $buffer = pack( $typedef, $setnum, $n, $t);
                print NOTE $buffer;
                seek(NOTE, 0, IO::Seekable::SEEK_END);
                $setnum++;
        }
	flock NOTE, LOCK_UN;
	close NOTE;
        return;
}

sub uen
{
	my($T);
	if($NOTEDB::crypt_supported == 1) {
		eval {
			$T = pack("u", $cipher->encrypt($_[0]));
		};
	}
	else {
    		$T = pack("u", $_[0]);
	}
    	chomp $T;
    	return $T;
}

sub ude
{
	my($T);
	if($NOTEDB::crypt_supported == 1) {
		eval {
			$T = $cipher->decrypt(unpack("u",$_[0]));
		};
	}
	else {
		$T = unpack("u", $_[0]);
	}
	return $T;
}

1; # keep this!

__END__

=head1 NAME

NOTEDB::binary - module lib for accessing a notedb from perl

=head1 SYNOPSIS

	# include the module
	use NOTEDB;
	
	# create a new NOTEDB object
	$db = new NOTEDB("binary", "/home/tom/.notedb", 4096, 24);

	# decide to use encryption
	# $key is the cipher to use for encryption
	# $method must be either Crypt::IDEA or Crypt::DES
	# you need Crypt::CBC, Crypt::IDEA and Crypt::DES to have installed.
	$db->use_crypt($key,$method);

	# do not use encryption
	# this is the default
	$db->no_crypt;

	# get a single note
	($note, $date) = $db->get_single(1);

	# search for a certain note 
	%matching_notes = $db->get_search("somewhat");
	# format of returned hash:
	#$matching_notes{$numberofnote}->{'note' => 'something', 'date' => '23.12.2000 10:33:02'}

	# get all existing notes
	%all_notes = $db->get_all();
	# format of returnes hash like the one from get_search above

	# get the next noteid available
	$next_num = $db->get_nextnum();

	# modify a certain note
	$db->set_edit(1, "any text", "23.12.2000 10:33:02");

	# create a new note
	$db->set_new(5, "any new text", "23.12.2000 10:33:02");

	# delete a certain note
	$db->set_del(5);

=head1 DESCRIPTION

You can use this module for accessing a note database. There are currently
two versions of this module, one version for a SQL database and one for a
binary file (note's own database-format).
However, both versions provides identical interfaces, which means, you do
not need to change your code, if you want to switch to another database format.

Currently, NOTEDB module is only used by note itself. But feel free to use it
within your own project! Perhaps someone want to implement a webinterface to
note...

=head1 USAGE

please see the section SYNOPSIS, it says it all.

=head1 AUTHOR

Thomas Linden <tom@daemon.de>.



=cut
