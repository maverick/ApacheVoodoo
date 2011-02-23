package Apache::Voodoo::Validate::set;

$VERSION = "3.0206";

use strict;
use warnings;

use base("Apache::Voodoo::Validate::Plugin");

sub config {
	my ($self,$c) = @_;

	unless (defined($c->{values}) && ref($c->{values}) eq "ARRAY") {
		return "'values' must be an array of the valid members of the set";
	}

	$self->{values} = { map { $_ => 1 } @{$c->{values}} };

	return;
}

sub valid {
	my ($self,$v) = @_;

	return ($v,defined($self->{values}->{$v})?undef:'BAD');
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
