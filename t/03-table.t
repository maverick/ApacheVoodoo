#
# $Id: 02-validation.t 17504 2009-07-10 19:59:16Z medwards $
#

use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 6;

BEGIN {
	use_ok('File::Temp');
	use_ok('DBI');
	use_ok('Apache::Voodoo::Exception');
	use_ok('Apache::Voodoo::Table');
}

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
	require DBD::SQLite;
};

SKIP: {
	skip "To enable more complete testing, please install DBD::SQLite.",0 if $@;

	my ($fh,$filename) = File::Temp::tmpnam();

	my $dbh = DBI->connect("dbi:SQLite:dbname=$filename","","") || BAIL_OUT("Couldn't make a testing database: $DBI::errstr");

	{
		local $/ = ';';
		while (<DATA>) {
			$_ =~ s/^\s*//;
			$_ =~ s/\s*$//;
			$_ =~ s/;$//;
			next unless length($_);
			$dbh->do($_);
		}
	}

	$dbh->disconnect();
	unlink($filename);
};


__DATA__
CREATE TABLE a_table (
    id integer not null primary key autoincrement,
	a_fkey integer,
	a_bit  bit,
	a_date date,
	a_time time,
	a_datetime datetime,
	a_signed_decimal decimal,
	a_unsigned_decimal decimal,
	a_signed_int integer,
	a_unsigned_int integer,
	a_varchar varchar(128),
	a_text text
);

CREATE TABLE a_ref_table (
	id integer not null primary key autoincrement,
	name varchar(64)
);

INSERT INTO a_ref_table (name) VALUES ('First Value');
INSERT INTO a_ref_table (name) VALUES ('Second Value');

INSERT INTO a_table VALUES(1,1,0,'2009-01-01','13:00','2000-01-01 12:00',12.34,-56.78,910,-1112,'a text string', 'a much larger text string');
