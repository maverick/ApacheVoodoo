package Apache::Voodoo::Validate::text;

use strict;
use warnings;

use base("Apache::Voodoo::Validate::varchar");

sub config {
	my ($self,$c) = @_;

	$c->{length} = 0;

	return $self->SUPER::config($c);
}

1;
