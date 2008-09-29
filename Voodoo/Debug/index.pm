=pod ###########################################################################

$Id$

=cut ###########################################################################
package Apache::Voodoo::Debug::index;

use strict;
use warnings;

use base ("Apache::Voodoo::Debug::base");

use Data::Dumper;

sub handle {
	my $self = shift;
	my $p    = shift;

	my $params  = $p->{'params'};
	my $dbh     = $p->{'dbh'};

	my $ids = $self->get_requests($dbh,$params);
	unless (ref($ids) eq 'ARRAY') {
		return {};
	}

	my @data;
	foreach my $row (@{$ids}) {
		if ($row->{result} == 0) {
			# supress the 0 returns, they represent content generation.
			# what we're really interested in is when we didn't do that.
			$row->{result} = undef;
		}
		else {
			# lookup what happened.
			my $res = $dbh->selectall_arrayref("
				SELECT
					data
				FROM
					return_data
				WHERE
					request_id = ?
				ORDER BY seq DESC
				LIMIT 1",undef,
				$row->{id}) || $self->db_error();

			$row->{result} .= " ".$res->[0]->[0];
		}

		push(@data,{
			'id'     => $row->{id},
			'time'   => $self->pretty_time($row->{request_timestamp}),
			'url'    => $row->{url},
			'result' => $row->{result}
		});
	}

	return { 
		'app_id'     => $params->{'app_id'},
		'session_id' => $params->{'session_id'},
		'request_id' => $params->{'request_id'},
		'requests'   => \@data
	};
}

sub get_requests {
    my $self   = shift;
    my $dbh    = shift;
    my $params = shift;

	unless ($params->{request_id} =~ /^\d+(\.\d*)?$/) {
		return "invalid request id";
	}

	unless ($params->{app_id} =~ /^[a-z]\w*$/i) {
		return "invalid application id";
	}

	unless ($params->{session_id} =~ /^[0-9a-z]+$/i) {
		return "invalid session id";
	}

	unless ($params->{page} =~ /^\d+$/) {
		$params->{page} = 0;
	}

	unless ($params->{count} =~ /^\d+$/ && $params->{count} <= 100) {
		$params->{count} = 20;
	}

    my $res = $dbh->selectall_arrayref("
        SELECT
            id,
			request_timestamp,
			url,
			result
        FROM
            request
        WHERE
            application = ? AND
			session_id  = ?
		ORDER BY
			request_timestamp DESC
		LIMIT ?
		OFFSET ?",{Slice => {}},
        $params->{app_id},
		$params->{session_id},
		$params->{count},
		$params->{page}) || $self->db_error();

	unless ($res->[0] > 0) {
		return "no such id";
	}

    return $res;
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
