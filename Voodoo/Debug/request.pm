=pod ###########################################################################

$Id$

=cut ###########################################################################
package Apache::Voodoo::Debug::request;

use strict;
use warnings;

use base ("Apache::Voodoo");

use JSON;

sub list {
	my $self = shift;
	my $p    = shift;

	my $params  = $p->{'params'};
	my $dbh     = $p->{'dbh'};

	my $res = $dbh->selectall_arrayref("
		SELECT
			id,
			request_timestamp,
			application,
			session_id,
			url
		FROM
			request
		ORDER BY
			id") || $self->db_error();

	return $self->raw_mode(
		'text/plain',
		to_json({
			'params' => $params,
			'requests' => $res
		})
	);
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include
in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
of the Artistic License :)

=cut ################################################################################
