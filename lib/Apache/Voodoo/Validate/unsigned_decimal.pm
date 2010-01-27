#####################################################################################
#
#  NAME
#
# Apache::Voodoo::Table - framework to handle common database operations
#
#  VERSION
# 
# $Id: unsigned_decimal.pm 17534 2009-07-13 20:22:03Z medwards $
#
####################################################################################
package Apache::Voodoo::Validate::unsigned_decimal;
$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Validate/unsigned_decimal.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo::Validate::Plugin");

sub config {
	my ($self,$c) = @_;
	my @e;
	if (defined($c->{left})) {
		if ($c->{left} =~ /^\d+$/) {
			$self->{left} = $c->{left};
		}
		else {
			push(@e,"'left' must be positive integer");
		}
	}
	else {
		push(@e,"'left' must be positive integer");
	}

	if (defined($c->{right})) {
		if ($c->{right} =~ /^\d+$/) {
			$self->{right} = $c->{right};
		}
		else {
			push(@e,"'right' must be positive integer");
		}
	}
	else {
		push(@e,"'right' must be positive integer");
	}

	return @e;
}

sub valid {
	my ($self,$v) = @_;

	my $e;
	if ($v =~ /^(\d*)(?:\.(\d+))?$/) {
		my $l = $2 || 0;
		my $r = $3 || 0;
		$l *= 1;
		$r *= 1;

		if (length($l) > $self->{'left'} ||
			length($r) > $self->{'right'} ) {

			$e='BIG';
		}
	}
	else {
		$e='BAD';
	}

	return $v,$e;
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
