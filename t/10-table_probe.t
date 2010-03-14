use strict;
use warnings;

use Data::Dumper;
use Test::More no_plan => 1;

BEGIN {
	use_ok('DBI');
	use_ok('Apache::Voodoo::Table::Probe');
	use_ok('Apache::Voodoo::Table');
	use_ok('Apache::Voodoo::Exception');
}

my $dbh = DBI->connect("dbi:mysql:test:localhost",'root','') || die DBI->errstr;

my $probe = Apache::Voodoo::Table::Probe->new($dbh);

my $no_such = $probe->probe_table('no_such_table_as_this_in_the_db');
ok($no_such->{ERRORS}->[0] =~ /^explain of table /, "no such table") || diag($no_such);

my $p = $probe->probe_table('av_test_types');
eval {
	my $table = Apache::Voodoo::Table->new($p);
};
my $e = Exception::Class->caught();
ok(!$e,"probe produces output that table accepts") || diag($e);


