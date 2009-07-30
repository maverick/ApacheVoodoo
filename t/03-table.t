#
# $Id: 02-validation.t 17504 2009-07-10 19:59:16Z medwards $
#

use strict;
use warnings;

use Test::More tests => 5;
use Data::Dumper;

BEGIN {
	use_ok('DBI');
	use_ok('Apache::Voodoo::Exception');
	use_ok('Apache::Voodoo::Table');
}


# straight jacked from the DBD::mysql test suite
my $test_dsn      = $ENV{'DBI_DSN'}   || 'DBI:mysql:database=test';
my $test_user     = $ENV{'DBI_USER'}  ||  '';
my $test_password = $ENV{'DBI_PASS'}  ||  '';

################################################################################
# Tests related to checking the config syntax
################################################################################
my $table;
eval {
	$table = Apache::Voodoo::Table->new({ });
};
my $e = Exception::Class->caught();
isa_ok($e,"Apache::Voodoo::Exception::RunTime::BadConfig");

eval {
	$table = Apache::Voodoo::Table->new({
		table       => '_vtable',
		columns => {
			id => {	
				type => 'unsigned_int',
				bytes => 4
			}
		}
	});
};

$e = Exception::Class->caught();
isa_ok($e,"Apache::Voodoo::Exception::RunTime::BadConfig");

my $dbh;
eval {
	$dbh = DBI->connect($test_dsn, $test_user, $test_password, { RaiseError => 1, PrintError => 1, AutoCommit => 0 });
};
if ($@) {
    BAIL_OUT "Can't continue testing without the db.  Giving Up. $DBI::errstr";
}

$dbh->disconnect;
