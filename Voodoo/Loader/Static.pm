# $Id$
package Apache::Voodoo::Loader::Static;
use strict;
use base("Apache::Voodoo::Loader");

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;

	# bingo...this is a factory
	return $self->load_module(shift);
}

1;
