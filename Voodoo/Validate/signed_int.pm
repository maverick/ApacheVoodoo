#####################################################################################
#
#  NAME
#
# Apache::Voodoo::Table - framework to handle common database operations
#
#  VERSION
# 
# $Id$
#
####################################################################################
package Apache::Voodoo::Validate::signed_int;
$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo::Validate::Plugin");

sub config {
	my ($self,$c) = @_;
	my @e;
	if (defined($c->{bytes})) {
		if ($c->{bytes} =~ /^\d+$/) {
			$self->{'max'}  = (     2 ** ($c->{bytes} * 8))/2;
			$self->{'min'}  = (0 - (2 ** ($c->{bytes} * 8))/2 - 1);
		}
		else {
			push(@e,"'bytes' must be a positive integer");
		}
	}
	elsif (defined($c->{max}) && defined($c->{min})) {
		if ($c->{max} =~ /^\d+$/) {
			$self->{max} = $c->{max};
		}
		else {
			push(@e,"'max' must be zero or a positive integer");
		}

		if ($c->{min} =~ /^(0+|-\d+)$/) {
			$self->{min} = $c->{min};
		}
		else {
			push(@e,"'min' must be zero or a negative integer");
		}
	}
	else {
		push(@e,"either 'max' and 'min' or 'bytes' is a required parameter");
	}

	return @e;
}

sub valid {
	my ($self,$v) = @_;

	return undef,'BAD' unless ($v =~ /^(\+|-)?\d*$/);
	return undef,'MAX' unless ($v <= $self->{'max'});
	return undef,'MIN' unless ($v >= $self->{'min'});

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
