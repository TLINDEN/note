# -*-perl-*-
use Test::More tests => 8;
#use Test::More qw(no_plan);

BEGIN { use_ok "NOTEDB" };
require_ok("NOTEDB");

require_ok("NOTEDB::binary");


my $db = new NOTEDB::binary(dbname => "t/1.out");
ok(ref($db), "Database object loaded");




my $r = $db->set_new(1, "any new text", "23.12.2000 10:33:02");
ok($r, "true");



my $next = $db->get_nextnum();
if ($next == 2) {
  pass("Get next note id");
}
else {
  fail("Get next note id");
}





my ($note, $date) = $db->get_single(1);
if ($note =~ /any new text/) {
  ok("Reading note");
}
else {
  fail("Reading note");
}



my $expect = {
	      1 => {
		    'date' => '23.12.2000 10:33:02',
		    'note' => 'any new text'
		   }
	     };

my %all = $db->get_all();
is_deeply($expect, \%all, "Get all notes hash");

