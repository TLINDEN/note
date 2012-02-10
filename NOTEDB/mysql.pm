#!/usr/bin/perl
# $Id: mysql.pm,v 1.1.1.1 2000/07/01 14:40:52 zarahg Exp $
# Perl module for note
# mysql database backend. see docu: perldoc NOTEDB::binary
#

use DBI;
use strict;
use Data::Dumper;
use NOTEDB;

package NOTEDB;

# Globals:
my ($DB, $table, $fnum, $fnote, $fdate, $version, $cipher);
$table = "note";
$fnum = "number";
$fnote = "note";
$fdate = "date";
$version = "(NOTEDB::mysql, 1.4)";

# prepare some std statements... #####################################################################
my $sql_getsingle	= "SELECT $fnote,$fdate FROM $table WHERE $fnum = ?";
my $sql_all		= "SELECT $fnum,$fnote,$fdate FROM $table";
my $sql_nextnum		= "SELECT max($fnum) FROM $table";
my $sql_incrnum		= "SELECT $fnum FROM $table ORDER BY $fnum";

my $sql_setnum 		= "UPDATE $table SET $fnum = ? WHERE $fnum = ?";
my $sql_edit		= "UPDATE $table SET $fnote = ?, $fdate = ? WHERE $fnum = ?";

my $sql_insertnew	= "INSERT INTO $table VALUES (?, ?, ?)";

my $sql_del		= "DELETE FROM $table WHERE $fnum = ?";
my $sql_del_all		= "DELETE FROM $table"; 
######################################################################################################

sub new
{
	# no prototype, because of the bin-version, which takes only a filename!
	my($this, $dbdriver, $dbname, $dbhost, $dbuser, $dbpasswd) = @_;

	my $class = ref($this) || $this;
	my $self = {};
	bless($self,$class);
	my $database = "DBI:$dbdriver:$dbname;host=$dbhost";

	$DB = DBI->connect($database, $dbuser, $dbpasswd) || die DBI->errstr();
	return $self;
}


sub DESTROY
{
	# clean the desk!
}


sub lock {
  my($this) = @_;
  # LOCK the database!
  my $lock = $DB->prepare("LOCK TABLES $table WRITE") || die $DB->errstr();
  $lock->execute() || die $DB->errstr();
}


sub unlock {
  my($this) = @_;
  my $unlock = $DB->prepare("UNLOCK TABLES") || die $DB->errstr;
  $unlock->execute() || die $DB->errstr();
  $DB->disconnect || die $DB->errstr;
}


sub version {
	return $version;
}


sub get_single {
	my($this, $num) = @_;

	my($note, $date);
	my $statement = $DB->prepare($sql_getsingle) || die $DB->errstr();

	$statement->execute($num) || die $DB->errstr();
	$statement->bind_columns(undef, \($note, $date)) || die $DB->errstr();

	while($statement->fetch) {
		return ude($note), ude($date);
	}
}


sub get_all
{
        my $this = shift;
        my($num, $note, $date, %res);

	if ($this->unchanged) {
	    return %{$this->{cache}};
	}

        my $statement = $DB->prepare($sql_all) || die $DB->errstr();

        $statement->execute || die $DB->errstr();
        $statement->bind_columns(undef, \($num, $note, $date)) || die $DB->errstr();

        while($statement->fetch) {
                $res{$num}->{'note'} = ude($note);
		$res{$num}->{'date'} = ude($date);
        }

        $this->cache(%res);
	return %res;
}


sub get_nextnum
{
	my($this, $num);
	if ($this->unchanged) {
	    $num = 1;
	    foreach (keys %{$this->{cache}}) {
		$num++;
	    }
	    return $num;
	}

	my $statement = $DB->prepare($sql_nextnum) || die $DB->errstr();

	$statement->execute || die $DB->errstr();
	$statement->bind_columns(undef, \($num)) || die $DB->errstr();

	while($statement->fetch) {
		return $num+1;
	}
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

	my %data;
	if ($this->unchanged) {
	    %data = %{$this->{cache}};
	}
	else {
	    %data = $this->get_all();
	}
	foreach $num (sort { $a <=> $b } keys %data) {
	  $note = ude($data{$num}->{'note'});
	  $date = ude($data{$num}->{'date'});
	  $_ = $note;
	  eval $regex;
	  if($match) {
	    $res{$num}->{'note'} = $note;
	    $res{$num}->{'date'} = $date;
	  }
	  $match = 0;
	}

	return %res;
}




sub set_edit
{
	my($this, $num, $note, $date) = @_;

	$this->lock;
	my $statement = $DB->prepare($sql_edit) || die $DB->errstr();
	$note =~ s/'/\'/g;
        $note =~ s/\\/\\\\/g;
	$statement->execute(uen($note), uen($date), $num) || die $DB->errstr();
	$this->unlock;
	$this->changed;
}


sub set_new
{
	my($this, $num, $note, $date) = @_;
	$this->lock;
	my $statement = $DB->prepare($sql_insertnew) || die $DB->errstr();

	$note =~ s/'/\'/g;
	$note =~ s/\\/\\\\/g;
	$statement->execute($num, uen($note), uen($date)) || die $DB->errstr();
	$this->unlock;
	$this->changed;
}


sub set_del
{
        my($this, $num) = @_;
	my($note, $date, $T);

	$this->lock;
	($note, $date) = $this->get_single($num);

	return "ERROR"  if ($date !~ /^\d/);

	# delete record!
	my $statement = $DB->prepare($sql_del) || die $DB->errstr();
	$statement->execute($num) || die $DB->errstr();
	$this->unlock;
	$this->changed;
	return;
}


sub set_del_all
{
	my($this) = @_;
	$this->lock;
	my $statement = $DB->prepare($sql_del_all) || die $DB->errstr();
	$statement->execute() || die $DB->errstr();
	$this->unlock;
	$this->changed;
	return;
}

sub set_recountnums {
        my $this = shift;

	$this->lock;

        my(@count, $i, $num, $setnum, $pos);
        $setnum = 1;
	$pos=0; $i=0; @count = ();

	my $statement = $DB->prepare($sql_incrnum) || die $DB->errstr();
	$statement->execute || die $DB->errstr();
        $statement->bind_columns(undef, \($num)) || die $DB->errstr();
	# store real id's in an array!
	while($statement->fetch) {
		$count[$i] = $num;
		$i++;
	}
	# now recount them! 
	my $sub_statement = $DB->prepare($sql_setnum) || die $DB->errstr();
	for($pos=0;$pos<$i;$pos++) {
		$setnum = $pos +1;
		$sub_statement->execute($setnum,$count[$pos]) || die $DB->errstr();
	}
        $this->unlock;
        $this->changed;
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

NOTEDB::mysql - module lib for accessing a notedb from perl

=head1 SYNOPSIS

	# include the module
	use NOTEDB;

	# create a new NOTEDB object (the last 4 params are db table/field names)
	$db = new NOTEDB("mysql","note","localhost","username","password","note","number","note","date");

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
