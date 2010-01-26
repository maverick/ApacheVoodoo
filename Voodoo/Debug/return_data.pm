=pod ###########################################################################

$Id: return_data.pm 16110 2009-05-29 17:09:13Z medwards $

=cut ###########################################################################
package Apache::Voodoo::Debug::return_data;

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
			handler,
			method,
			data
		FROM
			return_data
		WHERE
			request_id = ?
		ORDER BY
			seq",undef,
		$id) || $self->db_error();

	my $d = '[';
	foreach (@{$res}) {
		$d .= '["'.$_->[0].'-&gt;'.$_->[1].'",'.$_->[2].'],';
	}
	$d =~ s/,$//;
	$d .= ']';

    return $self->json_data('vd_return_data',$d);
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
