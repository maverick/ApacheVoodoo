#####################################################################################
#
#  NAME
#
# Apache::Voodoo::Table - framework to handle common database operations
#
#  VERSION
# 
# $Id: bit.pm 17534 2009-07-13 20:22:03Z medwards $
#
####################################################################################
package Apache::Voodoo::Validate::bit;
$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Validate/bit.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo::Validate::Plugin");

sub config {
	my ($self,$conf) = @_;
	return ();
}

sub valid {
	my ($self,$v) = @_;

	if ($v =~ /^(0*[1-9]\d*|y(es)?|t(rue)?)$/i) {
		return 1;
	}
	elsif ($v =~ /^(0+|n(o)?|f(alse)?)$/i) {
		return 0;
	}
	else {
		return undef,'BAD';
	}
}

1;
#####################################################################################
#
# AUTHOR
#
# Maverick, /\/\averick@smurfbaneDOTorg
#
# COPYRIGHT
#
# Copyright (c) 2009 Steven Edwards.  All rights reserved.
# 
# You may use and distribute Voodoo under the terms described in the LICENSE file include
# in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
# of the Artistic License :)
# 
#####################################################################################
