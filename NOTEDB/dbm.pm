#!/usr/bin/perl
# $Id: dbm.pm,v 1.1.1.1 2000/07/01 14:40:52 zarahg Exp $
# Perl module for note
# DBM database backend. see docu: perldoc NOTEDB::dbm
#

use DB_File;
#use Data::Dumper;
use NOTEDB;
use strict;
package NOTEDB;


# Globals:
my ($dbm_dir, $notefile, $timefile, $version, $cipher, %note, %date);
$notefile  = "note.dbm";
$timefile  = "date.dbm";

$version = "(NOTEDB::dbm, 1.1)";

sub new
{
	my($this, $dbdriver, $dbm_dir) = @_;
	my $class = ref($this) || $this;
	my $self = {};
	bless($self,$class);

	tie %note,  "DB_File", "$dbm_dir/$notefile"  || die $!;
	tie %date,  "DB_File", "$dbm_dir/$timefile"  || die $!;

	return $self;
}


sub DESTROY
{
	# clean the desk!
	untie %note, %date;
}

sub version {
        return $version;
}


sub get_single 
{
	my($this, $num) = @_;
	my($note, $date);
	return ude ($note{$num}), ude($date{$num});
}


sub get_all
{
        my($this, $num, $note, $date, %res, $real);
	foreach $num (sort {$a <=> $b} keys %date) {
                $res{$num}->{'note'} = ude($note{$num});
		$res{$num}->{'date'} = ude($date{$num});
	}
	return %res;
}


sub get_nextnum
{
	my($this, $num);
	foreach (sort {$a <=> $b} keys %date) {
	  $num = $_;
	}
	$num++;
	return $num;
}

sub get_search
{
	my($this, $searchstring) = @_;
	my($num, $note, $date, %res, $match);

        my $regex = $this->generate_search($searchstring);
	eval $regex;
	if ($@) {
	  print "invalid expression: \"$searchstring\"!\n";
	  return;
	}
	$match = 0;
	foreach $num (sort {$a <=> $b} keys %date) {
	  $_ = ude($note{$num});
	  eval $regex;
	  if ($match) {
                $res{$num}->{'note'} = ude($note{$num});
		$res{$num}->{'date'} = ude($date{$num});
	  }
	  $match = 0;
	}

	return %res;
}



sub set_recountnums
{
	my $this = shift;
	my(%Note, %Date, $num, $setnum);
	$setnum = 1;
	foreach $num (sort {$a <=> $b} keys %note) {
	  $Note{$setnum} = $note{$num};
	  $Date{$setnum} = $date{$num};
	  $setnum++;
	}
	%note = %Note;
	%date = %Date;
}



sub set_edit
{
	my($this, $num, $note, $date) = @_;
	$note{$num} = uen($note);
	$date{$num} = uen($date);
}


sub set_new
{
	my($this, $num, $note, $date) = @_;
	$this->set_edit($num, $note, $date); # just the same thing
}


sub set_del
{
        my($this, $num) = @_;
	my($note, $date, $T);
	($note, $date) = $this->get_single($num);
	return "ERROR"  if ($date !~ /^\d/);
	delete $note{$num};
	delete $date{$num};
}

sub set_del_all
{
        my($this) = @_;
	%note = ();
	%date = ();
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
                $T = $_[0];
        }
        chomp $T;
        return $T;
}

sub ude
{
        my($T);
        if($NOTEDB::crypt_supported == 1) {
                eval {
                        $T = $cipher->decrypt(unpack("u",$_[0]))
                };
                return $T;
        }
        else {
                return $_[0];
        }
}



1; # keep this!

__END__

=head1 NAME

NOTEDB::dbm - module lib for accessing a notedb from perl

=head1 SYNOPSIS

	# include the module
	use NOTEDB;
	
	# create a new NOTEDB object (the last 4 params are db table/field names)
	$db = new NOTEDB("mysql","note","/home/user/.notedb/");

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

	# recount all noteids starting by 1 (usefull after deleting one!)
	$db->set_recountnums();

	# modify a certain note
	$db->set_edit(1, "any text", "23.12.2000 10:33:02");

	# create a new note
	$db->set_new(5, "any new text", "23.12.2000 10:33:02");

	# delete a certain note
	$db->set_del(5);

=head1 DESCRIPTION

You can use this module for accessing a note database. This is the dbm module.
It uses the DB_FILE module to store it's data and it uses DBM files for tis purpose.

Currently, NOTEDB module is only used by note itself. But feel free to use it
within your own project! Perhaps someone want to implement a webinterface to
note...

=head1 USAGE

please see the section SYNOPSIS, it says it all.

=head1 AUTHOR

Thomas Linden <tom@daemon.de>.



=cut
