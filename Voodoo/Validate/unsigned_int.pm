#####################################################################################
#
#  NAME
#
# Apache::Voodoo::Table - framework to handle common database operations
#
#  VERSION
# 
# $Id: unsigned_int.pm 17534 2009-07-13 20:22:03Z medwards $
#
####################################################################################
package Apache::Voodoo::Validate::unsigned_int;
$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Validate/unsigned_int.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo::Validate::Plugin");

sub config {
	my ($self,$c) = @_;

	my @e;
	if (defined($c->{bytes})) {
		if ($c->{bytes} =~ /^\d+$/) {
			$self->{max} = 2 ** ($c->{bytes} * 8) - 1;
		}
		else {
			push(@e,"'bytes' must be a positive integer");
		}
	}
	elsif (defined($c->{max})) {
		if ($c->{max} =~ /^\d+$/) {
			$self->{max} = $c->{max};
		}
		else {
			push(@e,"'max' must be a positive integer");
		}
	}
	else {
		push(@e,"either 'max' or 'bytes' is a required parameter");
	}

	return @e;
}

sub valid {
	my ($self,$v) = @_;

	return undef,'BAD' unless ($v =~ /^\d*$/ );
	return undef,'MAX' unless ($v <= $self->{'max'});

	return $v;
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
