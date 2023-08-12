#!/usr/bin/perl
use warnings;
use strict;
no strict "refs";

use IO::All;
use Encode;
# only  YAML::XS  is able  to  properly  load  our data  (others  fail
# invariably)
use YAML::XS qw(Load);
# only  YAML is  able to  properly  Dump the  data YAML::XS  generates
# various kinds of multiline  entries like "line\nline2\nline3" end up
# literally  in the  generated  yaml,  which note  is  then unable  to
# feed. So,  the pure perl  version is  better as it  always generates
# multiline entries for data containing newlines
use YAML qw(Dump);
use Data::Dumper;

my ($yf1, $yf2) = @ARGV;

# read  both input  files  and  parse yaml  into  data structure,  fix
# non-printables
my $badutf81 < io $yf1;
my $yaml1 = decode( 'UTF-8', $badutf81 =~ s/[^\x00-\x7F]+//gr );
my $y1 = Load $yaml1 or die "Could not load $yf1: $!";

my $badutf82 < io $yf2;
my $yaml2 = decode( 'UTF-8', $badutf82 =~ s/[^\x00-\x7F]+//gr );
my $y2 = Load $yaml2 or die "Could not load $yf2: $!";

# convert to comparable hashes with unique keys
my $hash1 = &hashify($y1);
my $hash2 = &hashify($y2);

# diff and recombine the two into a new one
my $combinedhash = &hash2note(&diff($hash1, $hash2));

#print Dumper($combinedhash); exit;

# turn into yaml
my $combindedyaml = Dump($combinedhash);

# perl uses scalars as hash keys (read: strings) so we need to unquote
# them here to make note happy
$combindedyaml =~ s/^'(\d+)':/$1:/gm;


print $combindedyaml;


sub hash2note {
    # convert given hash into note format with number as key
    my $hash = shift;
    my $new;
    my $i = 0;
    
    foreach my $path (sort keys %{$hash}) {
        $new->{++$i} = $hash->{$path};
    }

    return $new;
}

sub diff {
    # diff the two hashes, create a new combined one
    my($hash1, $hash2) = @_;
    my $new;

    # iterate over hash1, store duplicates and remove them in hash2,
    # store different entries and remove in both,
    # store those missing in hash2 and delete them in hash1
    foreach my $path (sort keys %{$hash1}) {
        if (exists $hash2->{$path}) {
            if ($hash2->{$path}->{body} eq $hash1->{$path}->{body}) {
                printf STDERR "%s => %s is duplicate\n", $path, $hash1->{$path}->{title};
                $new->{$path} = delete $hash2->{$path};
                delete $hash1->{$path};
            }
            else {
                printf STDERR "%s => %s is different\n", $path, $hash1->{$path}->{title};
                $new->{$path} = delete $hash1->{$path};
                $new->{$path . 2} = delete $hash2->{$path};
            }
        }
        else {
            printf STDERR "%s => %s is missing in hash2\n", $path, $hash1->{$path}->{title};
            $new->{$path} = delete $hash1->{$path};
        }
    }

    # store any lefovers of hash1
    foreach my $path (sort keys %{$hash1}) {
        printf STDERR "%s => %s is left in hash1\n", $path, $hash1->{$path}->{title};
        $new->{$path} = $hash1->{$path};
    }

    # store any lefovers of hash2
    foreach my $path (sort keys %{$hash2}) {
        printf STDERR "%s => %s is left in hash2\n", $path, $hash2->{$path}->{title};
        $new->{$path} = $hash2->{$path};
    }

    return $new
}

sub hashify {
    # create new hash with path+title as key instead of id's
    my $data = shift;
    my $new = {};

    foreach my $id (keys %{$data} ) {
        my $path = $data->{$id}->{path} . '|' . $data->{$id}->{title};
        if (exists $new->{$path}) {
            die "$path already exists!\n";
        }
        else {
            $new->{$path} = $data->{$id};
        }
    }

    return $new;
}

