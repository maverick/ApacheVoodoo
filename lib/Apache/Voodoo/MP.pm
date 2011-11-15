################################################################################
#
# Factory that creates either a MP1 or MP2 object depending on whether or not
# we're running under mod_perl 1 or 2.  This saves us from having to write, and
# clutter up the code with, a load of conditionals in the Handler.
#
################################################################################
package Apache::Voodoo::MP;

$VERSION = "3.0206";

use strict;
use warnings;

sub new {
	my $class = shift;

	if (exists $ENV{MOD_PERL_API_VERSION}) {
		if ($ENV{MOD_PERL_API_VERSION} >= 2 ) {
			require Apache::Voodoo::MP::V2;
			return Apache::Voodoo::MP::V2->new();
		}
		else {
			require Apache::Voodoo::MP::V1;
			return Apache::Voodoo::MP::V1->new();
		}
	}
	elsif (eval { require nginx; } ) {
		warn("Voodoo appears to be running under NGINX\n");
		require Apache::Voodoo::MP::nginx;
		return Apache::Voodoo::MP::nginx->new();
	}
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
