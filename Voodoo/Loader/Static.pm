# $Id$
package Voodoo::Loader::Static;
use strict;
use base("Voodoo::Loader");

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;

	# bingo...this is a factory
	return $self->load_module(shift);
}

1;
