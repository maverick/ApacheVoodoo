package Apache::Voodoo::Debug::common;

$VERSION = sprintf("%0.4f",('$HeadURL: svn://localhost/Voodoo/core/Voodoo/Driver.pm $' =~ m!(\d+\.\d+)!)[0]||0);

use strict;
use warnings;

use DBI;
use Data::Dumper;

use base("Apache::Voodoo");

sub create_schema {
	my $self = shift;

	$self->_create_request();
	$self->_create_profile();
}

sub _create_version {
	my $self = shift;
	$self->{dbh}->do("CREATE TABLE version (version varchar(64) not null)")            || $self->db_error();
	$self->{dbh}->do("INSERT INTO version (version) VALUES(?)",undef,$self->{version}) || $self->db_error();
}

sub _create_request {
	my $self = shift;

	$self->{dbh}->do("CREATE TABLE request (
		id ".$self->_pkey_syntax.",
		request_timestamp varchar(64) not null,
		application varchar(64) not null,
		session_id varchar(64),
		url varchar(255)
	)") || $self->db_error();

	$self->{dbh}->do("CREATE INDEX request_timestamp ON request(request_timestamp)") || $self->db_error();
	$self->{dbh}->do("CREATE INDEX session_id        ON request(session_id)")        || $self->db_error();
	$self->{dbh}->do("CREATE INDEX application       ON request(application)")       || $self->db_error();
	$self->{dbh}->do("CREATE INDEX url               ON request(url)")               || $self->db_error();
}

sub _get_request_id {
	my $self = shift;
	my $id   = shift;

	my $res = $self->{dbh}->selectcol_arrayref("
		SELECT
			id
		FROM
			request
		WHERE 
			request_timestamp = ? AND
			application       = ?",undef,
		$id->{request_id},
		$id->{app_id}) || $self->db_error();

	return $res->[0];
}

sub handle_request {
	my $self = shift;
	my $data = shift;

	$self->{dbh}->do("
		INSERT INTO request (
			request_timestamp,
			application
		)
		VALUES (
			?,
			?
		)",undef,
		$data->{id}->{request_id},
		$data->{id}->{app_id}) || $self->db_error();
}

sub _create_profile {
	my $self = shift;

	$self->{dbh}->do("CREATE TABLE profile (
		request_id integer not null,
		timestamp varchar(64) not null,
		data varchar(255) not null
	)") || $self->db_error();

	$self->{dbh}->do("CREATE INDEX request_id ON profile(request_id)") || $self->db_error();
	$self->{dbh}->do("CREATE INDEX timestamp  ON profile(timestamp)")  || $self->db_error();
}

sub handle_mark {
	my $self = shift;
	my $data = shift;

	my $request_id = $self->_get_request_id($data->{id});
	unless ($request_id) {
		warn "no such request\n";
		return;
	}

	$self->{dbh}->do("
		INSERT INTO profile (
			request_id,
			timestamp,
			data
		)
		VALUES (
			?,
			?,
			?
		)",undef,
		$request_id,
		$data->{timestamp},
		$data->{data}) || $self->db_error();
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
