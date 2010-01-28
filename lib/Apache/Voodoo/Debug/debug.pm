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

	my @levels;
	foreach (qw(debug info warn error exception table trace)) {
		if ($params->{$_} eq "1") {
			push(@levels,$_);
		}
	}

	my $query = "
		SELECT
			level,
			stack,
			data
		FROM
			debug
		WHERE
			request_id = ?";

	if (scalar(@levels)) {
		$query .= ' AND level IN (' . join(',',map { '?'} @levels) . ') ';
	}

	$query .= "
		ORDER BY
			seq";

	my $res = $dbh->selectall_arrayref($query,undef,$id,@levels) || $self->db_error();

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

################################################################################
# Copyright (c) 2005-2010 Steven Edwards (maverick@smurfbane.org).  
# All rights reserved.
#
# You may use and distribute Apache::Voodoo under the terms described in the 
# LICENSE file include in this package. The summary is it's a legalese version
# of the Artistic License :)
#
################################################################################
