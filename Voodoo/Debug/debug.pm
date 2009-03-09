=pod ###########################################################################

$Id: debug.pm 12906 2009-02-20 23:08:10Z medwards $

=cut ###########################################################################
package Apache::Voodoo::Debug::debug;

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
			level,
			stack,
			data
		FROM
			debug
		WHERE
			request_id = ?
		ORDER BY
			seq",undef,
		$id) || $self->db_error();

    return $self->json_data('vd_debug',$self->_process_debug($params->{app_id},$res));
}

sub _process_debug {
	my $self   = shift;
	my $app_id = shift;
	my $data   = shift;

	my $debug = '[';
	foreach my $row (@{$data}) {
		$debug .= '{"level":"'.$row->[0].'"';
		$debug .= ',"stack":' .$row->[1];
		$debug .= ',"data":';
		if ($row->[2] =~ /^[\[\{\"]/) {
			$debug .= $row->[2];
		}
		else {
			$debug .= '"'.$row->[2].'"';
		}
			
		$debug .= '},';
	}
	$debug =~ s/,$//;
	$debug .= ']';

	return $debug;
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
