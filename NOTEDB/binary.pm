#!/usr/bin/perl
# $Id: binary.pm,v 1.3 2000/08/11 00:05:58 zarahg Exp $
# Perl module for note
# binary database backend. see docu: perldoc NOTEDB::binary
#
package NOTEDB;

use strict;
use Data::Dumper;
use IO::Seekable;

use NOTEDB;

use Fcntl qw(LOCK_EX LOCK_UN);



sub new
{
    my($this, $dbdriver, $dbname, $MAX_NOTE, $MAX_TIME) = @_;

    my $class = ref($this) || $this;
    my $self = {};
    bless($self,$class);

    if(! -e $dbname) {
	open(TT,">$dbname") or die "Could not create $dbname: $!\n";
	close (TT);
    }
    elsif(! -w $dbname) {
	print "$dbname is not writable!\n";
	exit(1);
    }

    $self->{version} = "(NOTEDB::binary, 1.7)";
    $self->{NOTEDB}  = $dbname;
    my $TYPEDEF      = "i a$MAX_NOTE a$MAX_TIME";
    my $SIZEOF       = length pack($TYPEDEF, () );

    $self->{sizeof}  = $SIZEOF;
    $self->{typedef} = $TYPEDEF;

    return $self;
}


sub DESTROY
{
    # clean the desk!
}

sub version {
    my $this = shift;
    return $this->{version};
}



sub set_del_all
{
    my $this = shift;
    unlink $this->{NOTEDB};
    open(TT,">$this->{NOTEDB}") or die "Could not create $this->{NOTEDB}: $!\n";
    close (TT);
}


sub get_single {
    my($this, $num) = @_;
    my($address, $note, $date, $buffer, $n, $t, $buffer, );

    open NOTE, "+<$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX; 

    $address = ($num-1) * $this->{sizeof};
    seek(NOTE, $address, IO::Seekable::SEEK_SET);
    read(NOTE, $buffer, $this->{sizeof});
    ($num, $n, $t) = unpack($this->{typedef}, $buffer);

    $note = $this->ude($n);
    $date = $this->ude($t);

    flock NOTE, LOCK_UN;
    close NOTE;

    return $note, $date;
}


sub get_all
{
    my $this = shift;
    my($num, $note, $date, %res);

    if ($this->unchanged) {
	return %{$this->{cache}};
    }
    open NOTE, "+<$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX;
    my($buffer, $t, $n);
    seek(NOTE, 0, 0); # START FROM BEGINNING
    while(read(NOTE, $buffer, $this->{sizeof})) {
	($num, $note, $date) = unpack($this->{typedef}, $buffer);
	$t = $this->ude($date);
	$n = $this->ude($note);
	$res{$num}->{'note'} = $n;
	$res{$num}->{'date'} = $t;
    }
    flock NOTE, LOCK_UN;
    close NOTE;

    $this->cache(%res);
    return %res;
}


sub get_nextnum
{
    my $this = shift;
    my($num, $te, $me, $buffer);

    if ($this->unchanged) {
	$num = 1;
	foreach (keys %{$this->{cache}}) {
	    $num++;
	}
	return $num;
    }
    open NOTE, "+<$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX;

    seek(NOTE, 0, 0); # START FROM BEGINNING
    while(read(NOTE, $buffer, $this->{sizeof})) {
	($num, $te, $me) = unpack($this->{typedef}, $buffer);
    }
    $num += 1;
    flock NOTE, LOCK_UN;
    close NOTE;

    return $num;
}

sub get_search
{
    my($this, $searchstring) = @_;
    my($buffer, $num, $note, $date, %res, $t, $n, $match);

    my $regex = $this->generate_search($searchstring);
    eval $regex;
    if ($@) {
	print "invalid expression: \"$searchstring\"!\n";
	return;
    }
    $match = 0;

    if ($this->unchanged) {
	foreach my $num (keys %{$this->{cache}}) {
	    $_ = $this->{cache}{$num}->{note};
	    eval $regex;
	    if ($match) {
		$res{$num}->{note} = $this->{cache}{$num}->{note};
		$res{$num}->{date} = $this->{cache}{$num}->{date}
	    }
	    $match = 0;
	}
	return %res;
    }

    open NOTE, "+<$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX;

    seek(NOTE, 0, 0); # START FROM BEGINNING
    while(read(NOTE, $buffer, $this->{sizeof})) {
	($num, $note, $date) = unpack($this->{typedef}, $buffer);
	$n = $this->ude($note);
	$t = $this->ude($date);
	$_ = $n;
	eval $regex;
	if($match)
	  {
	      $res{$num}->{'note'} = $n;
	      $res{$num}->{'date'} = $t;
	  }
	$match = 0;
    }
    flock NOTE, LOCK_UN;
    close NOTE;

    return %res;
}




sub set_edit
{
    my($this, $num, $note, $date) = @_;
    my $address = ($num -1 ) * $this->{sizeof};

    open NOTE, "+<$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX;

    seek(NOTE, $address, IO::Seekable::SEEK_SET);
    my $n = $this->uen($note);
    my $t = $this->uen($date);

    my $buffer = pack($this->{typedef}, $num, $n, $t);
    print NOTE $buffer;

    flock NOTE, LOCK_UN;
    close NOTE;

    $this->changed;
}


sub set_new
{
    my($this, $num, $note, $date) = @_;
    open NOTE, "+<$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX;

    seek(NOTE, 0, IO::Seekable::SEEK_END); # APPEND
    my $n = $this->uen($note);
    my $t = $this->uen($date);
    my $buffer = pack($this->{typedef}, $num, $n, $t);
    print NOTE $buffer;

    flock NOTE, LOCK_UN;
    close NOTE;

    $this->changed;
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
    open NOTE, ">$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX; 
    seek(NOTE, 0, 0); # START FROM BEGINNING
    foreach $N (keys %orig) {
	$n = $this->uen($orig{$N}->{'note'});
	$t = $this->uen($orig{$N}->{'date'});
	$buffer = pack( $this->{typedef}, $N, $n, $t);
	# keep orig number, note have to call recount!
	print NOTE $buffer;
	seek(NOTE, 0, IO::Seekable::SEEK_END);
	$setnum++;
    }
    flock NOTE, LOCK_UN;
    close NOTE;

    $this->changed;

    return;
}

sub set_recountnums
{
    my($this) = @_;
    my(%orig, $note, $date, $T, $setnum, $buffer, $n, $N, $t);

    $setnum = 1;
    %orig = $this->get_all();

    open NOTE, ">$this->{NOTEDB}" or die "could not open $this->{NOTEDB}\n";
    flock NOTE, LOCK_EX;
    seek(NOTE, 0, 0); # START FROM BEGINNING

    foreach $N (sort {$a <=> $b} keys %orig) {
	$n = $this->uen($orig{$N}->{'note'});
	$t = $this->uen($orig{$N}->{'date'});
	$buffer = pack( $this->{typedef}, $setnum, $n, $t);
	print NOTE $buffer;
	seek(NOTE, 0, IO::Seekable::SEEK_END);
	$setnum++;
    }
    flock NOTE, LOCK_UN;
    close NOTE;

    $this->changed;

    return;
}

sub uen
{
    my $this = shift;
    my($T);
    if($NOTEDB::crypt_supported == 1) {
	eval {
	    $T = pack("u", $this->{cipher}->encrypt($_[0]));
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
    my $this = shift;
    my($T);
    if($NOTEDB::crypt_supported == 1) {
	eval {
	    $T = $this->{cipher}->decrypt(unpack("u",$_[0]));
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

        # turn on encryption. CryptMethod must be IDEA, DES or BLOWFISH
        $db->use_crypt("passphrase", "CryptMethod");

        # turn off encryption. This is the default.
        $db->no_crypt();


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
