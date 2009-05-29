=pod ###########################################################################

$Id$

=cut ###########################################################################
package Apache::Voodoo::Debug::profile;

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
			timestamp,
			data
		FROM
			profile
		WHERE
			request_id = ?
		ORDER BY
			timestamp",undef,
		$id) || $self->db_error();

	my $return;
	$return->{'key'} = 'vd_profile';

	my $last = $#{$res};
	if ($last > 0) {
		my $total_time = $res->[$last]->[0] - $res->[0]->[0];

		$return->{'value'} = [
			map {
				[
					sprintf("%.5f",    $res->[$_]->[0] - $res->[$_-1]->[0]),
					sprintf("%5.2f%%",($res->[$_]->[0] - $res->[$_-1]->[0])/$total_time*100),
					$res->[$_]->[1]
				]
			} (1 .. $last)
		];

		unshift(@{$return->{value}}, [
			sprintf("%.5f",$total_time),
			'percent', 
			'message'
		]);
	}

	return $self->json_return($return);
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
