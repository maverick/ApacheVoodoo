=pod ###########################################################################

$Id: template_conf.pm 12906 2009-02-20 23:08:10Z medwards $

=cut ###########################################################################
package Apache::Voodoo::Debug::template_conf;

use strict;
use warnings;

use base ("Apache::Voodoo::Debug::base");

sub handle {
	my $self = shift;
	my $p    = shift;

	my $params  = $p->{'params'};
	my $dbh     = $p->{'dbh'};

	my $id = $self->get_request_id($dbh,$params);
	unless ($id =~ /^\d+$/) {
		return $self->json_error($id);
	}

	my $res = $dbh->selectall_arrayref("
		SELECT
			data
		FROM
			template_conf
		WHERE
			request_id = ?",undef,
		$id) || $self->db_error();

    return $self->json_return(
		{ 
			'key' => 'vd_template_conf',
			'value' => $res->[0]->[0]
		}
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
