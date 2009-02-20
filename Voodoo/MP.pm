=pod ###########################################################################
Factory that creates either a MP1 or MP2 object depending on whether or not
we're running under mod_perl 1 or 2.  This saves us from having to write, and
clutter up the code with, a load of conditionals in the Handler.
=cut ###########################################################################
package Apache::Voodoo::MP;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class = shift;

	if (exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 ) {
		require Apache::Voodoo::MP::V2;
		return Apache::Voodoo::MP::V2->new();
	}
	else {
		require Apache::Voodoo::MP::V1;
		return Apache::Voodoo::MP::V1->new();
	}
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include in
this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version of
the Artistic License :)

=cut ################################################################################
