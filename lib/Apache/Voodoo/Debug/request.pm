=pod ###########################################################################

$Id: request.pm 16110 2009-05-29 17:09:13Z medwards $

=cut ###########################################################################
package Apache::Voodoo::Debug::request;

use strict;
use warnings;

use base ("Apache::Voodoo::Debug::base");

sub handle {
	my $self = shift;
	my $p    = shift;

	my $params  = $p->{'params'};
	my $dbh     = $p->{'dbh'};

	my $app_id     = $params->{'app_id'};
	my $session_id = $params->{'session_id'};
	my $request_id = $params->{'request_id'};

	my $return = [];
	if ($app_id     =~ /^[a-z]\w+/i   && 
		$session_id =~ /^[a-f0-9]+$/i &&
		$request_id =~ /^\d+\.\d+$/) {

		$return = $dbh->selectall_arrayref("
			SELECT
				request_timestamp AS request_id,
				url
			FROM
				request
			WHERE
				application = ? AND
				session_id  = ? AND
				request_timestamp >= ?
			ORDER BY
				id",{Slice => {}},
				$app_id,
				$session_id,
				$request_id) || $self->db_error();
	}

    return $self->json_data('vd_request',$return);
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
