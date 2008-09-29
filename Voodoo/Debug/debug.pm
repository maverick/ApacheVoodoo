=pod ###########################################################################

$Id: index.pm 8214 2008-09-23 14:30:36Z medwards $

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
			stack,
			data
		FROM
			debug
		WHERE
			request_id = ?
		ORDER BY
			seq",undef,
		$id) || $self->db_error();

    return $self->json_return(
		{ 
			'key' => 'vd_debug',
			'value' => $res
		}
	);
}

sub _process_debug {
	my $self = shift;

	my @debug = ();
	my @last  = ();
	foreach (@{$self->{'debug'}}) {
		my ($stack,$mesg) = @{$_};

		my $i=0;
		my $match = 1;
		my ($x,$y,@stack) = split(/~/,$stack);
		foreach (@stack) {
			unless ($match && $_ eq $last[$i]) {
				$match=1;
				push(@debug,{
					'depth' => $i,
					'name'  => $_
				});
			}
			$i++;
		}

		@last = @stack;

		push(@debug, {
				'depth' => ($#stack+1),
				'name'  => $mesg
		});
	}
	return \@debug;
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
