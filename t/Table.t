use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 54;

my $mysql_skip  = 22;
my $sqlite_skip = 17;

use_ok('File::Temp');
use_ok('DBI');
use_ok('Apache::Voodoo::Exception');
use_ok('Apache::Voodoo::Table');
use_ok('Apache::Voodoo::Table::Probe');


################################################################################
# Internal objects
################################################################################
my $join = Apache::Voodoo::Table::Join->new({
	table       => 'foo',
	foreign_key => 'bar_id',
	primary_key => 'id',
	columns     => ['name','foo.thing']
});

is($join->primary_key,'id',    'primary key accessor');
is($join->foreign_key,'bar_id','foreign key accessor');

is($join->table,$join->alias,"join alias defaults correctly");
is_deeply([$join->columns],['foo.name','foo.thing'],"column name namespaced correctly");
is($join->context,'common','context defaults correctly');
is($join->type,'LEFT','join type defautls correctly');
is($join->enabled,1,'join enabled by default');

$join->enabled(0);
is($join->enabled,0,'setter for join enabled works');

$join = Apache::Voodoo::Table::Join->new({
	table       => 'avt_ref_table',
	alias       => 'second_ref',
	context     => 'list',
	foreign_key => 'avt_ref_table_id',
	primary_key => 'id',
	columns     => ['name']
});

################################################################################
# Tests related to checking the config syntax
################################################################################
my $table;
eval {
	$table = Apache::Voodoo::Table->new({ });
};
my $e = Exception::Class->caught();
isa_ok($e,"Apache::Voodoo::Exception::RunTime::BadConfig") || diag($e);

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

my $simple_table = Apache::Voodoo::Table->new({
	table => 'avt_table',
	primary_key => 'id',
	columns => {
		id  => { type => 'unsigned_int', bytes => 4, required => 1 },
		avt_ref_table_id => { 
			type => 'unsigned_int', 
			bytes => 4, 
			required => 1,
			references => {
				table => 'avt_ref_table',
				primary_key => 'id',
				columns => ['name'],
				select_label => 'name'
			}
		},
		a_date     => { type => 'date' },
		a_time     => { type => 'time' },
		a_datetime => { type => 'datetime' },
		a_varchar  => { type => 'varchar', length => 128},
		a_text     => { type => 'text'}
	},
	'list_options' => {
		'default_sort' => 'varchar',
		'sort' => {
			'varchar' => 'a_varchar',
			'text' => 'a_text',
			'datetime' => 'a_datetime'
		},
		search => [
			['Varchar','a_varchar'],
			['Text','a_text']
		]
	}
});

my $dbh;

SKIP: {
	my $dbh;
	eval { require DBD::mysql; };
	skip "DBD::mysql not found, skipping these tests",$mysql_skip if $@;

	eval {
		$dbh = DBI->connect("dbi:mysql:test:localhost",'root','',{RaiseError => 1});
	};
	skip "Can't connect to mysql test database on localhost, skipping these tests",$mysql_skip if $@;

	setup_db(         'MySQL',$dbh);
	simple_view_list( 'MySQL',$dbh);
	complex_view_list('MySQL',$dbh);
	nested_join_list( 'MySQL',$dbh);
	having_clause(    'MySQL',$dbh);
	add_tests(        'MySQL',$dbh);
	edit_tests(       'MySQL',$dbh);
	probe_tests(      'MySQL',$dbh);

	my $res = $dbh->selectall_arrayref("SHOW TABLES LIKE 'avt_%'");
	foreach (@{$res}) {
		$dbh->do("DROP TABLE $_->[0]");
	}
	$dbh->disconnect;
}

SKIP: {
	eval { require DBD::SQLite; };
	skip "DBD::SQLite not found, skipping these tests",$sqlite_skip if $@;

	my ($fh,$filename) = File::Temp::tmpnam();
	$dbh = DBI->connect("dbi:SQLite:dbname=$filename","","",{RaiseError => 1}) || BAIL_OUT("Couldn't make a testing database: ".DBI->errstr);

	setup_db(         'SQLite',$dbh);
	simple_view_list( 'SQLite',$dbh);
	complex_view_list('SQLite',$dbh);
	add_tests(        'SQLite',$dbh);
	edit_tests(       'SQLite',$dbh);
	$dbh->disconnect;
	unlink($filename);
}

sub setup_db {
	my $type = lc(shift);
	my $dbh  = shift;

	open(F,"t/test_data/test_db_$type.sql") || BAIL_OUT("Can't open test db source file: $!");
	{
		local $/ = ';';
		while (<F>) {
			$_ =~ s/^\s*//;
			$_ =~ s/\s*$//;
			$_ =~ s/;$//;
			next unless length($_);
			$dbh->do($_);
		}
	}
	close(F);

	open(F,"t/test_data/test_db.sql") || BAIL_OUT("Can't open test db source file: $!");
	{
		local $/ = ';';
		while (<F>) {
			$_ =~ s/^\s*//;
			$_ =~ s/\s*$//;
			$_ =~ s/;$//;
			next unless length($_);
			$dbh->do($_);
		}
	}
	close(F);
}

sub simple_view_list {
	my $type = shift;
	my $dbh  = shift;

	is_deeply(
		$simple_table->view({dbh => $dbh,'params' => {'id' => 1}}),
		{
          'a_text' => 'a much larger text string',
          'a_date' => '01/01/2009',
          'a_varchar' => 'a text string',
          'avt_ref_table_id' => 1,
          'a_datetime' => '2000-02-01 12:00:00',
          'a_time' => ' 1:00 PM',
		  'avt_ref_table.name' => 'First Value',
          'id' => 1
        },
		"($type) Simple view with valid id"
	);

	my $v;
	eval {
		$v = $simple_table->view({dbh => $dbh,'params' => {'id' => 100}});
	};
	$e = Exception::Class->caught();
	isa_ok($e,"Apache::Voodoo::Exception::Application::DisplayError");

	is_deeply(
		$simple_table->list({ dbh => $dbh }),
		{
			'PATTERN' => '',
			'SORT_PARAMS' => 'desc=1&amp;last_sort=varchar&amp;showall=0',
			'DATA' => [
				{
					'a_text' => 'a much larger text string',
					'a_date' => '01/01/2009',
					'a_varchar' => 'a text string',
					'avt_ref_table.name' => 'First Value',
					'a_datetime' => '2000-02-01 12:00:00',
					'avt_ref_table_id' => 1,
					'id' => 1,
					'a_time' => ' 1:00 PM'
				},
				{
					'a_text' => 'different much longer string',
					'a_date' => '01/01/2010',
					'a_varchar' => 'another text string',
					'avt_ref_table.name' => 'Second Value',
					'a_datetime' => '2010-02-01 14:00:00',
					'avt_ref_table_id' => 2,
					'id' => 2,
					'a_time' => ' 5:00 PM'
				},
				{
					'a_varchar' => 'loren ipsum solor sit amet',
					'a_text' => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
					'a_date' => '03/15/2010',
					'avt_ref_table.name' => 'Fourth Value',
					'a_datetime' => '2010-01-01 12:00:00',
					'avt_ref_table_id' => 4,
					'id' => 3,
					'a_time' => ' 4:00 PM'
				}
			],
			'NUM_MATCHES' => 3,
			'LIMIT' => [
				{
					'ID' => 'a_varchar',
					'ID.a_varchar' => 1,
					'NAME' => 'Varchar',
					'NAME.Varchar' => 1,
					'SELECTED' => 0
				},
				{
					'ID' => 'a_text',
					'ID.a_text' => 1,
					'NAME' => 'Text',
					'NAME.Text' => 1,
					'SELECTED' => 0
				}
			]
		},
		"($type) list results"
	);

	is_deeply(
		$simple_table->list({ dbh => $dbh, params => { 'search_a_varchar' => 'a text' }}),
		{
			'PATTERN' => '',
			'SORT_PARAMS' => 'desc=1&amp;last_sort=varchar&amp;showall=0',
			'DATA' => [
				{
					'a_text' => 'a much larger text string',
					'a_date' => '01/01/2009',
					'a_varchar' => 'a text string',
					'avt_ref_table.name' => 'First Value',
					'a_datetime' => '2000-02-01 12:00:00',
					'avt_ref_table_id' => 1,
					'id' => 1,
					'a_time' => ' 1:00 PM'
				}
			],
			'NUM_MATCHES' => 1,
			'LIMIT' => [
				{
					'ID' => 'a_varchar',
					'ID.a_varchar' => 1,
					'NAME' => 'Varchar',
					'NAME.Varchar' => 1,
					'SELECTED' => 0
				},
				{
					'ID' => 'a_text',
					'ID.a_text' => 1,
					'NAME' => 'Text',
					'NAME.Text' => 1,
					'SELECTED' => 0
				}
			]
		},
		"($type) list search results"
	);

	is_deeply(
		$simple_table->list({ dbh => $dbh, params => { 'limit' => 'a_text', 'pattern' => 'elit' }}),
		{
			'PATTERN' => 'elit',
			'SORT_PARAMS' => 'pattern=elit&amp;desc=1&amp;last_sort=varchar&amp;limit=a_text&amp;showall=0',
			'DATA' => [
				{
					'a_text' => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
					'a_date' => '03/15/2010',
					'a_varchar' => 'loren ipsum solor sit amet',
					'avt_ref_table.name' => 'Fourth Value',
					'a_datetime' => '2010-01-01 12:00:00',
					'avt_ref_table_id' => 4,
					'id' => 3,
					'a_time' => ' 4:00 PM'
				}
			],
			'NUM_MATCHES' => 1,
			'LIMIT' => [
				{
					'ID' => 'a_varchar',
					'NAME' => 'Varchar',
					'ID.a_varchar' => 1,
					'SELECTED' => 0,
					'NAME.Varchar' => 1
				},
				{
					'ID.a_text' => 1,
					'ID' => 'a_text',
					'NAME.Text' => 1,
					'NAME' => 'Text',
					'SELECTED' => 'SELECTED'
				}
			]
        }
	);

	is_deeply(
		$simple_table->list({ dbh => $dbh, params => {'sort' => 'datetime'}}),
		{
			'PATTERN' => '',
			'SORT_PARAMS' => 'desc=1&amp;last_sort=datetime&amp;showall=0',
			'DATA' => [
				{
					'a_text' => 'a much larger text string',
					'a_date' => '01/01/2009',
					'a_varchar' => 'a text string',
					'avt_ref_table.name' => 'First Value',
					'a_datetime' => '2000-02-01 12:00:00',
					'avt_ref_table_id' => 1,
					'id' => 1,
					'a_time' => ' 1:00 PM'
				},
				{
					'a_varchar' => 'loren ipsum solor sit amet',
					'a_text' => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
					'a_date' => '03/15/2010',
					'avt_ref_table.name' => 'Fourth Value',
					'a_datetime' => '2010-01-01 12:00:00',
					'avt_ref_table_id' => 4,
					'id' => 3,
					'a_time' => ' 4:00 PM'
				},
				{
					'a_text' => 'different much longer string',
					'a_date' => '01/01/2010',
					'a_varchar' => 'another text string',
					'avt_ref_table.name' => 'Second Value',
					'a_datetime' => '2010-02-01 14:00:00',
					'avt_ref_table_id' => 2,
					'id' => 2,
					'a_time' => ' 5:00 PM'
				}
			],
			'NUM_MATCHES' => 3,
			'LIMIT' => [
				{
					'ID' => 'a_varchar',
					'ID.a_varchar' => 1,
					'NAME' => 'Varchar',
					'NAME.Varchar' => 1,
					'SELECTED' => 0
				},
				{
					'ID' => 'a_text',
					'ID.a_text' => 1,
					'NAME' => 'Text',
					'NAME.Text' => 1,
					'SELECTED' => 0
				}
			]
		},
		"($type) list results sorted"
	);
}

sub complex_view_list {
	my $type = shift;
	my $dbh  = shift;

	my $table = Apache::Voodoo::Table->new({
		table => 'avt_table',
		primary_key => 'id',
		columns => {
			id     => { type => 'unsigned_int', bytes => 4, required => 1 },
			a_date     => { type => 'date' },
			a_time     => { type => 'time' },
			a_datetime => { type => 'datetime' },
			a_varchar  => { type => 'varchar', length => 128},
			a_text     => { type => 'text'}
		},
		joins => [
			{
				table       => 'avt_ref_table',
				foreign_key => 'avt_ref_table_id',
				primary_key => 'id',
				columns     => ['name']
			},
			{
				table       => 'avt_ref_table',
				alias       => 'second_ref',
				context     => 'list',
				foreign_key => 'avt_ref_table_id',
				primary_key => 'id',
				columns     => ['name']
			},
		],
		'list_options' => {
			'default_sort' => 'varchar',
			'sort' => {
				'varchar' => 'a_varchar',
				'text' => 'a_text'
			}
		}
	});

	is_deeply(
		$table->view({dbh => $dbh,'params' => {'id' => 1}}),
		{
          'a_text' => 'a much larger text string',
          'a_date' => '01/01/2009',
          'a_varchar' => 'a text string',
          'a_time' => ' 1:00 PM',
          'id' => 1,
          'avt_ref_table.name' => 'First Value',
          'a_datetime' => '2000-02-01 12:00:00'
        },
		"($type) complex view with valid id"
	);

	my $v;
	eval {
		$v = $table->view({dbh => $dbh,'params' => {'id' => 100}});
	};
	$e = Exception::Class->caught();
	isa_ok($e,"Apache::Voodoo::Exception::Application::DisplayError");

	is_deeply(
		$table->list({ dbh => $dbh }),
		{
          'PATTERN' => '',
          'SORT_PARAMS' => 'desc=1&amp;last_sort=varchar&amp;showall=0',
          'DATA' => [
                      {
                        'a_text' => 'a much larger text string',
                        'a_date' => '01/01/2009',
                        'a_varchar' => 'a text string',
                        'second_ref.name' => 'First Value',
                        'avt_ref_table.name' => 'First Value',
                        'a_datetime' => '2000-02-01 12:00:00',
                        'id' => 1,
                        'a_time' => ' 1:00 PM'
                      },
                      {
                        'a_text' => 'different much longer string',
                        'a_date' => '01/01/2010',
                        'a_varchar' => 'another text string',
                        'second_ref.name' => 'Second Value',
                        'avt_ref_table.name' => 'Second Value',
                        'a_datetime' => '2010-02-01 14:00:00',
                        'id' => 2,
                        'a_time' => ' 5:00 PM'
                      },
                      {
                        'a_text' => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                        'a_date' => '03/15/2010',
                        'a_varchar' => 'loren ipsum solor sit amet',
                        'second_ref.name' => 'Fourth Value',
                        'avt_ref_table.name' => 'Fourth Value',
                        'a_datetime' => '2010-01-01 12:00:00',
                        'id' => 3,
                        'a_time' => ' 4:00 PM'
                      }
                    ],
          'NUM_MATCHES' => 3,
          'LIMIT' => []
        },
		"($type) complex list results");

	my @joins = $table->joins('second_ref');
	$joins[0]->enabled(0);

	is_deeply(
		$table->list({ dbh => $dbh }),
		{
          'PATTERN' => '',
          'SORT_PARAMS' => 'desc=1&amp;last_sort=varchar&amp;showall=0',
          'DATA' => [
                      {
                        'a_text' => 'a much larger text string',
                        'a_date' => '01/01/2009',
                        'a_varchar' => 'a text string',
                        'avt_ref_table.name' => 'First Value',
                        'a_datetime' => '2000-02-01 12:00:00',
                        'id' => 1,
                        'a_time' => ' 1:00 PM'
                      },
                      {
                        'a_text' => 'different much longer string',
                        'a_date' => '01/01/2010',
                        'a_varchar' => 'another text string',
                        'avt_ref_table.name' => 'Second Value',
                        'a_datetime' => '2010-02-01 14:00:00',
                        'id' => 2,
                        'a_time' => ' 5:00 PM'
                      },
                      {
                        'a_text' => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                        'a_date' => '03/15/2010',
                        'a_varchar' => 'loren ipsum solor sit amet',
                        'avt_ref_table.name' => 'Fourth Value',
                        'a_datetime' => '2010-01-01 12:00:00',
                        'id' => 3,
                        'a_time' => ' 4:00 PM'
                      }
                    ],
          'NUM_MATCHES' => 3,
          'LIMIT' => []
        },
		"($type) complex list results with disabled join");
}

sub nested_join_list {
	my $type = shift;
	my $dbh  = shift;

	my $result = {
		'PATTERN' => '',
		'SORT_PARAMS' => 'desc=1&amp;last_sort=varchar&amp;showall=0',
		'DATA' => [
			{
				'a_text' => 'a much larger text string',
				'a_date' => '01/01/2009',
				'a_varchar' => 'a text string',
				'sec_ref.name' => undef,
				'avt_ref_table.name' => 'First Value',
				'a_datetime' => '2000-02-01 12:00:00',
				'id' => 1,
				'a_time' => ' 1:00 PM'
			},
			{
				'a_text' => 'different much longer string',
				'a_date' => '01/01/2010',
				'a_varchar' => 'another text string',
				'sec_ref.name' => 'Second Value',
				'avt_ref_table.name' => 'First Value',
				'a_datetime' => '2010-02-01 14:00:00',
				'id' => 2,
				'a_time' => ' 5:00 PM'
			},
			{
				'a_text' => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
				'a_date' => '03/15/2010',
				'a_varchar' => 'loren ipsum solor sit amet',
				'sec_ref.name' => 'Second Value',
				'avt_ref_table.name' => 'First Value',
				'a_datetime' => '2010-01-01 12:00:00',
				'id' => 3,
				'a_time' => ' 4:00 PM'
			}
		],
		'NUM_MATCHES' => 3,
		'LIMIT' => []
	};

	my $table = Apache::Voodoo::Table->new({
		table => 'avt_table',
		primary_key => 'id',
		columns => {
			id     => { type => 'unsigned_int', bytes => 4, required => 1 },
			a_date     => { type => 'date' },
			a_time     => { type => 'time' },
			a_datetime => { type => 'datetime' },
			a_varchar  => { type => 'varchar', length => 128},
			a_text     => { type => 'text'}
		},
		joins => [
			{
				table => '(avt_xref_table,avt_ref_table)',
				extra => [
					'avt_xref_table.avt_table_id     = avt_table.id',
					'avt_xref_table.avt_ref_table_id = avt_ref_table.id',
					'avt_ref_table.name = "First Value"',
				],
				columns => ['avt_ref_table.name']
			},
			{
				table => '(avt_xref_table AS sec_xref,avt_ref_table AS sec_ref)',
				extra => [
					'sec_xref.avt_table_id     = avt_table.id',
					'sec_xref.avt_ref_table_id = sec_ref.id',
					'sec_ref.name = "Second Value"',
				],
				columns => ['sec_ref.name']
			},
		],
		'list_options' => {
			'default_sort' => 'varchar',
			'sort' => {
				'varchar' => 'a_varchar',
				'text' => 'a_text'
			}
		}
	});

	is_deeply($table->list({dbh => $dbh}),$result,'nest join style 1');

	$table = Apache::Voodoo::Table->new({
		table => 'avt_table',
		primary_key => 'id',
		columns => {
			id     => { type => 'unsigned_int', bytes => 4, required => 1 },
			a_date     => { type => 'date' },
			a_time     => { type => 'time' },
			a_datetime => { type => 'datetime' },
			a_varchar  => { type => 'varchar', length => 128},
			a_text     => { type => 'text'}
		},
		joins => [
			{
				table => '(avt_xref_table JOIN avt_ref_table ON 
					avt_xref_table.avt_ref_table_id = avt_ref_table.id AND
					avt_ref_table.name = "First Value")',
				foreign_key => 'avt_table.id',
				primary_key => 'avt_xref_table.avt_table_id',
				columns => ['avt_ref_table.name']
			},
			{
				table => '(avt_xref_table AS sec_xref JOIN avt_ref_table AS sec_ref ON
					sec_xref.avt_ref_table_id = sec_ref.id AND
					sec_ref.name = "Second Value")',
				foreign_key => 'avt_table.id',
				primary_key => 'sec_xref.avt_table_id',
				columns => ['sec_ref.name']
			},
		],
		'list_options' => {
			'default_sort' => 'varchar',
			'sort' => {
				'varchar' => 'a_varchar',
				'text' => 'a_text'
			}
		}
	});

	is_deeply($table->list({dbh => $dbh}),$result,'nest join style 2');
}

sub having_clause {
	my $type = shift;
	my $dbh  = shift;

	my $table = Apache::Voodoo::Table->new({
		table => 'avt_table',
		primary_key => 'id',
		columns => {
			id     => { type => 'unsigned_int', bytes => 4, required => 1 },
			a_date     => { type => 'date' },
			a_time     => { type => 'time' },
			a_datetime => { type => 'datetime' },
			a_varchar  => { type => 'varchar', length => 128},
			a_text     => { type => 'text'}
		},
		'list_options' => {
			'default_sort' => 'varchar',
			'sort' => {
				'varchar' => 'a_varchar',
				'text' => 'a_text'
			},
			group_by => 'id'	# SQLite requires a group by to use having
		}
	});

	is_deeply($table->list({dbh => $dbh},{'having' => 'a_datetime > "2010-01-01"'}),
	{
		DATA => [
			{
				a_date => '01/01/2010',
				a_datetime => '2010-02-01 14:00:00',
				a_text => 'different much longer string',
				a_time => ' 5:00 PM',
				a_varchar => 'another text string',
				id => 2,
			},
			{
				a_date => '03/15/2010',
				a_datetime => '2010-01-01 12:00:00',
				a_text => 'consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
				a_time => ' 4:00 PM',
				a_varchar => 'loren ipsum solor sit amet',
				id => 3,
			}
		],
		LIMIT => [],
		NUM_MATCHES => 2,
		PATTERN => '',
		SORT_PARAMS => 'desc=1&amp;last_sort=varchar&amp;showall=0'
	},
	"($type) having clause");
}

sub add_tests {
	my $type = shift;
	my $dbh  = shift;

	my $r = $simple_table->add({
		'dbh' => $dbh,
		'params' => {
			'cm' => 'add',
			#'id' => 5,
			'a_text' => 'a much larger text string',
			'a_date' => '01/01/2009',
			'a_varchar' => 'a text string',
			'avt_ref_table_id' => 1,
			'a_datetime' => '2000-02-01 12:00:00',
			'a_time' => '1:00 PM'
        }
	});

	#
	# Duplicate column checking.
	#
	my $table = Apache::Voodoo::Table->new({
		table => 'avt_table',
		primary_key => 'id',
		columns => {
			id        => { type => 'unsigned_int', bytes => 4,  required => 1 },
			a_unique  => { type => 'varchar',      bytes => 16, unique   => 1 },
			a_varchar => { type => 'varchar',      bytes => 16 },
		}
	});

	$r = $table->add({
		dbh => $dbh,
		params => {
			cm => 'add',
			a_varchar => "inserted",
            a_unique  => 'row 1',
		}
	});
	ok($r->{'DUP_a_unique'}, 'add catches duplicate column value');
}

sub edit_tests {
	my $type = shift;
	my $dbh  = shift;

	my $r = $simple_table->edit({
		'dbh' => $dbh,
		'params' => {
			'cm' => 'update',
			'id' => 1,
			'a_text' => 'a very much larger text string',
			'a_date' => '01/01/2010',
			'a_varchar' => 'a updated text string',
			'avt_ref_table_id' => 2,
			'a_datetime' => '2010-02-01 12:00:00',
			'a_time' => '2:00 PM'
        }
	});

	is_deeply(
		$simple_table->view({dbh=>$dbh,params=>{'id' => 1}}),
		{
          'a_text' => 'a very much larger text string',
          'a_date' => '01/01/2010',
          'a_varchar' => 'a updated text string',
          'avt_ref_table.name' => 'Second Value',
          'a_datetime' => '2010-02-01 12:00:00',
          'avt_ref_table_id' => 2,
          'id' => 1,
          'a_time' => ' 2:00 PM'
        },
		"($type) basic edit"
	);

	#
	# Duplicate column checking.
	#
	my $table = Apache::Voodoo::Table->new({
		table => 'avt_table',
		primary_key => 'id',
		columns => {
			id        => { type => 'unsigned_int', bytes => 4,  required => 1 },
			a_unique  => { type => 'varchar',      bytes => 16, unique   => 1 },
			a_varchar => { type => 'varchar',      bytes => 16 },
		}
	});

	$r = $table->edit({
		dbh => $dbh,
		params => {
			cm => 'update',
			id => 1,
			a_varchar => "updated",
            a_unique  => 'row 2',
		}
	});
	ok($r->{'DUP_a_unique'}, 'Catches duplicate column value');

	$r = $table->edit({
		dbh => $dbh,
		params => {
			cm => 'update',
			id => 1,
			a_varchar => "updated",
		}
	});
	is($r,1,"($type) edit ignoring unqiue column");

	$r = $table->edit({
		dbh => $dbh,
		params => {
			cm => 'update',
			id => 1,
			a_varchar => "updated",
		}
	});
	is($r,1,"($type) edit replacing unqiue column with same value");

	$table->add_update_callback(sub {
		my $dbh    = shift;
		my $params = shift;

		my $return = {};
		$return->{'BAD_VARCHAR'} = 1 unless $params->{'a_varchar'} eq "good";
		return $return;
	});

	$r = $table->edit({
		dbh => $dbh,
		params => {
			cm => 'update',
			id => 1,
			a_varchar => 'bad'
		}
	});
	ok(ref($r) && $r->{'BAD_VARCHAR'}, 'edit callback works (fail)');

	$r = $table->edit({
		dbh => $dbh,
		params => {
			cm => 'update',
			id => 1,
			a_varchar => 'good'
		}
	});
	is($r,1,'edit callback works (pass)');
}

sub probe_tests {
	my $type = shift;
	my $dbh  = shift;

	my $probe = Apache::Voodoo::Table::Probe->new($dbh);
	my $no_such;
	eval {
		$no_such = $probe->probe_table('no_such_table_as_this_in_the_db');
	};
	ok($@ =~ /doesn't exist/, "($type) no such table");

	my $config = $probe->probe_table('avt_all_types');
	my $table;
	eval {
		$table = Apache::Voodoo::Table->new($config);
	};
	my $e = Exception::Class->caught();
	ok(!$e,"($type) probe produces output that table accepts") || diag($e);
}
