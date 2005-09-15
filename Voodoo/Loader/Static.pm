# $Id$
package Apache::Voodoo::Loader::Static;

$VERSION = '1.13';

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

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include
in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
of the Artistic License :)

=cut ################################################################################
