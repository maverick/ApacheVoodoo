package Apache::Voodoo::Debug::SQLite;

$VERSION = sprintf("%0.4f",('$HeadURL: svn://localhost/Voodoo/core/Voodoo/Driver.pm $' =~ m!(\d+\.\d+)!)[0]||0);

use strict;
use warnings;

use DBI;

use base("Apache::Voodoo::Debug::common");

sub new {
	my $class = shift;
	my $self = {};

	bless $self,$class;

	$self->{version} = '1';

	return $self;
}

sub init_db {
	my $self = shift;

	my $dbh  = shift;
	$self->{dbh} = $dbh;

	my $tables = $dbh->selectcol_arrayref("
		SELECT
			name
		FROM
			sqlite_master
		WHERE
			type='table' AND
			name NOT LIKE 'sqlite%'
		") || $self->db_error();

	$self->debug($tables);
	if (grep {$_ eq 'version'} @{$tables}) {
		my $res = $dbh->selectall_arrayref("SELECT version FROM version") || $self->db_error();
		if (0 && $res->[0]->[0] eq $self->{version}) {
			return;
		}
	}

	foreach my $table (@{$tables}) {
		$dbh->do("DROP TABLE $table") || $self->db_error();
	}

	$self->create_schema();
}

sub last_insert_id {
	my $self = shift;

	my $res = $self->{dbh}->selectall_arrayref("SELECT last_insert_rowid()") || $self->db_error();
	return $res->[0]->[0];
}

sub _pkey_syntax {
	return "integer not null primary key autoincrement";
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include in
this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version of
the Artistic License :)

=cut ################################################################################
