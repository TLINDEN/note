#!/usr/bin/perl -w
#
# generic tool functions
#
# Copyright (c) 2000 ConSol* GmbH, Munich.
# All Rights Reserved. Unauthorized use forbidden.
#
# $Id: Tools.pm,v 1.11 2000/08/04 17:41:40 tom Exp $
package Consol::Util::Tools;

use Exporter ();
use strict;
use Carp qw(cluck);
use FileHandle ();
use Date::Manip;
use Data::Dumper;
use vars qw(@ISA @EXPORT @EXPORT_OK @EXPORT_TAGS $DEBUG);

@ISA=qw(Exporter);
# auto export subs
@EXPORT=qw(getyesterdate debug generate_regex crypt_data);
@EXPORT_OK=qw();
@EXPORT_TAGS=();


=head1 NAME

Tools - general utilitiy package, no OOP.

=head1 SYNOPSIS

use Tools qw (getyesterdate debug);


=head1 SUB getyesterdate

 my $onedayago = getyesterdate();

returns the date one day ago in the following format: YYYYMMDD

=cut

sub getyesterdate
{
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my($lastmonth, $lastyear);
    $year += 1900;
    $mon += 1;

    if ($mon == 1) {
      $lastmonth = 12;
      $lastyear  = $year - 1;
    }
    else {
      $lastmonth = $mon - 1;
      $lastyear = $year;
    }
    my @DAYS_IN_MONTH = qw(0 31 28 31 30 31 30 31 31 30 31 30 31);
    my ($day,@days);
    if ((($year % 4) == 0) && ((($year % 100) != 0) || (($year % 400) == 0))) {
      $DAYS_IN_MONTH[2]++;
    }

    if ($mday == 1) {
      $mday = $DAYS_IN_MONTH[$lastmonth];
      $year = $lastyear;
      $mon  = $lastmonth;
    }
    else {
      $mday--;
    }
    $mon =~ s/^(\d)$/0$1/;
    $hour =~ s/^(\d)$/0$1/;
    $min =~ s/^(\d)$/0$1/;
    $sec =~ s/^(\d)$/0$1/;
    $mday =~ s/^(\d)$/0$1/;
    return "$year$mon$mday";
}


=head1 SUB debug

 BEGIN { $DEBUG = 1; }
 debug("some odd errors occured");

prints the given message to STDERR if $DEBUG is true (1).
It adds the packagename and the linenumber of the caller to the output.

=cut

sub debug {
  my(@msg) = @_;
  return if(!$DEBUG);
  my($package, $filename, $line) = caller;
  print "$package $line: @msg\n";
}





=head1 SUB generate_regex

This subroutine generates valid perlcode based on userinput
for further validation using B<eval>. You can catch exceptions
using the B<$@> variable. A user supplied expression an contain
AND, OR, brackets (), wildcards (* for any characters, ? for one character),
or even valid perl regex(in this special case, it will not transformed
in any way). See below for example usage!

 $code = generate_regex(
			-string => "(max AND moritz) OR (tina AND ute)",
                        -case   => 1,
			-if     => 1,
			);

If you set B<-if> to B<1> the following output will be created:

 $match = 1 if(  (/max/i   and /moritz/i  )  or  (/tina/i   and /ute/i  ) );

otherwise you will only get a code fragment:

 (/max/i   and /moritz/i  )  or  (/tina/i   and /ute/i  )

If you set B<-case> to B<1>, the code will search case sensitive.

If B<-string> is empty, "/^/" will be returned.

Sample usage:

 #!/usr/bin/perl
 use Tools qw(generate_regex);
 my $match = undef;
 my $input = <>;
 chomp $input;
 my $regex = generate_regex(-string => $input, -if => 1);
 eval $regex;
 if ($@) {
   die "invalid expression: $@\n";
 }
 open FILE, "<textfile" or die $!;
 while (<FILE>) {
   eval $regex;
   if ($match) {
     print "$. matched the expression \"$input\"\n";
   }
 }
 close FILE;

Allowed expressions:

 "Hans Wurst"                                   # exact match
 max AND moritz                                 # AND
 max OR moritz                                  # OR
 (max AND moritz) OR tina                       # combined with ()
 ((max AND moritz) AND tina) OR (hans AND mike) # more complicated with ()
 (*aol.com OR *gmx.de) AND (*free* OR *money*)  # slightly more complicated with wildcards
 /^[a-zA-Z]+?.*\d{4}$/                          # yes, a user can also supply a regex!

=cut


sub generate_regex {
  #
  # interface sub for generate_search()
  #
  my %params = @_;
  my($result);
  $result = &generate_search($params{-string}, $params{-case});
  if ($params{-if}) {
    $result = qq(\$match = 1 if($result););
  }
  return $result;
}



sub generate_search {
    #
    # get user input and create perlcode ready for eval
    #  sample input:
    # "ann.a OR eg???on AND u*do$"
    #  resulting output:
    # "$match = $_ if(/ann\.a/i or /eg...on/i and /u.*do\$/i );
    #
    my($string,$case) = @_;

    if ($string =~ /^\/.+?\/$/) {
      return $string;
    }
    elsif (!$string) {
      return "/^/";
    }

    # per default case sensitive
    $case = ($case ? "" : "i");

    # we will get a / in front of the first word too!
    $string = " " . $string . " ";

    # check for apostrophs
    $string =~ s/(?<=\s)(\(??)("[^"]+"|\S+)(\)??)(?=\s)/$1 . &check_exact($2) . $3/ge;

    # remove odd spaces infront of and after »and« and »or«
    $string =~ s/\s\s*(AND|OR)\s\s*/ $1 /g;

    # remove odd spaces infront of »(« and after »)«
    $string =~ s/(\s*\()/\(/g;
    $string =~ s/(\)\s*)/\)/g;

    # remove first and last space so it will not masked!
    $string =~ s/^\s//;
    $string =~ s/\s$//;

    # mask spaces if not infront of or after »and« and »or«
    $string =~ s/(?<!AND)(?<!OR)(\s+?)(?!AND|OR)/'\s' x length($1)/ge;

    # add first space again
    $string = " " . $string;

    # lowercase AND and OR
    $string =~ s/(\s??OR\s??|\s??AND\s??)/\L$1\E/g;

    # surround brackets with at least one space
    $string =~ s/(?<!\\)(\)|\()/ $1 /g;

    # surround strings with slashes
    $string =~ s/(?<=\s)(\S+)/ &check_or($1, $case) /ge;

    # remove slashes on »and« and »or«
    $string =~ s/\/(and|or)\/$case/$1/g;

    # remove spaces inside /string/ constructs
    $string =~ s/(?<!and)(?<!or)\s*\//\//g;

    $string =~ s/\/\s*(?!and|or)/\//g;

    return $string;
}

sub check_or {
  #
  # surrounds string with slashes if it is not
  # »and« or »or«
  #
  my($str, $case) = @_;
  if ($str =~ /^\s*(or|and)\s*$/) {
    return " $str ";
  }
  elsif ($str =~ /(?<!\\)[)(]/) {
    return $str;
  }
  else {
    return " \/$str\/$case ";
  }
}


sub check_exact {
  #
  # helper for generate_search()
  # masks special chars if string
  # not inside ""
  #
  my($str) = @_;

  my %globs = (
	       '*' => '.*',
	       '?' => '.',
	       '[' => '[',
	       ']' => ']',
	       '+' => '\+',
	       '.' => '\.',
	       '$' => '\$',
	       '@' => '\@',
	      );

  # mask backslash
  $str =~ s/\\/\\\\/g;

  if ($str =~ /^"/ && $str =~ /"$/) {
    # mask bracket-constructs
    $str =~ s/(\(|\))/\\$1/g;
  }
  $str =~ s/(.)/$globs{$1} || "$1"/ge;

  $str =~ s/^"//;
  $str =~ s/"$//;

  # mask spaces
  $str =~ s/\s/\\s/g;
  return $str;
}








sub crypt_data {
  #
  # enrypt a passwd
  #
  my($cleartext) = @_;
  debug("\"$cleartext\"");
  return if(!$cleartext);

  # create a random salt
  my @range=('0'..'9','a'..'z','A'..'Z');

  my $salt=$range[rand(int($#range)+1)] . $range[rand(int($#range)+1)];

  return crypt($cleartext, "$salt");
}



=head1 AUTHOR

Thomas Linden

=cut

1;

# Local Variables: ***
# perl-master-file: ../../webmin/index.pl ***
# End: ***
