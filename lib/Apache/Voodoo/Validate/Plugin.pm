#####################################################################################
#
# Apache::Voodoo::Validate::Plugin
#
# Base class which all the data type plugins must inherit from in order to work
# correctly with A::V::Validate.
#
####################################################################################
package Apache::Voodoo::Validate::Plugin;

$VERSION = "3.0206";

use strict;
use warnings;

sub new {
	my $class  = shift;
	my $config = shift;

	my $self = {};
	bless $self,$class;

	$self->{'name'} = $config->{'id'};
	$self->{'type'} = $config->{'type'};

	# grab the switches
	foreach ("required","unique",'multiple') {
		if ($config->{$_}) {
			$self->{$_} = ($config->{$_})?1:0;
		}
	}

	my @e = $self->config($config);
	if (!defined($self->{valid}) && defined($config->{valid})) {
		if (ref($config->{valid}) ne "CODE") {
			push(@e,"'valid' is not a subroutine reference");
		}
		else {
			$self->{valid_sub} = $config->{valid};
		}
	}

	$self->{'errors'} = \@e if (scalar(@e) && defined($e[0]));

	return $self;
}

sub type   { return $_[0]->{type};   }
sub name   { return $_[0]->{name};   }
sub errors { return $_[0]->{errors}; }

sub valid_sub { $_[0]->{valid_sub} = $_[1] if scalar(@_) > 1; return $_[0]->{valid_sub} }
sub required  { $_[0]->{required}  = $_[1] if scalar(@_) > 1; return $_[0]->{required}; }
sub unique    { $_[0]->{unique}    = $_[1] if scalar(@_) > 1; return $_[0]->{unique};   }
sub multiple  { $_[0]->{multiple}  = $_[1] if scalar(@_) > 1; return $_[0]->{multiple}; }

sub config {
	my $self = shift;
	my $e = ref($self)." didn't override the config function as it should have";
	warn $e;
	return {},$e;
}

sub valid {
	my $self = shift;
	warn ref($self)." didn't override the valid function as it should have";
	return undef;
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
