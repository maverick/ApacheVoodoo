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
package Apache::Voodoo::Validate;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo");

use Email::Valid;

use Apache::Voodoo::Exception;
use Apache::Voodoo::Validate::Config;
use Apache::Voodoo::Validate::URL;

my %COLUMN_TYPES = (
	"varchar"          => \&_valid_varchar,
	"text"             => \&_valid_varchar,
	'unsigned_int'     => \&_valid_unsigned_int,
	'signed_int'       => \&_valid_signed_int,
	'signed_decimal'   => \&_valid_signed_decimal,
	'unsigned_decimal' => \&_valid_unsigned_decimal,
	'date'             => \&_valid_date,
	'time'             => \&_valid_time,
	'datetime'         => \&_valid_datetime,
	'bit'              => \&_valid_bit
);

sub new {
	my $class = shift;

	my $self = {};
	bless $self, $class;

	my $config = shift;
	if (ref($config) eq "Apache::Voodoo::Validate::Config") {
		$self->{'config'} = $config;
	}
	else {
		$self->{'config'} = Apache::Voodoo::Validate::Config->new($config);
	}

	$self->{'ef'} = sub {
		my ($f,$t,$e) = @_;
		$e->{$t.'_'.$f} = 1;
	};

	return $self;
}

sub add_callback {
	my $self    = shift;
	my $context = shift;
	my $sub_ref = shift;

	unless (defined($context)) {
		Apache::Vodooo::Exception::RunTime->throw("add_callback requires a context name as the first parameter");
	}

	unless (ref($sub_ref) eq "CODE") {
		Apache::Vodooo::Exception::RunTime->throw("add_callback requires a subroutine reference as the second paramter");
	}

	push(@{$self->{'callbacks'}->{$context}},$sub_ref);
}

sub set_error_formatter {
	my $self    = shift;
	my $sub_ref = shift;

	if (ref($sub_ref) eq "CODE") {
		$self->{'ef'} = $sub_ref;
	}
}

sub validate {
	my $self = shift;
	my $p    = shift;

	my $c = $self->{'config'};

	my $values = {};
	my $errors = {};

	foreach my $field ($c->fields) {
		unless (defined($COLUMN_TYPES{$field->{'type'}})) {
			Apache::Voodoo::Exception::RunTime->throw("Don't know how to validate field type $field->{type}");
		}

		my $good;
		my $missing = 1;
		my $bad     = 0;
		foreach ($self->_param($p,$field)) {
			next unless defined ($_);

			# call the validation routine for each value
			my ($v,$b) = $COLUMN_TYPES{$field->{type}}->($self,$_,$field,$errors);

			if ($b) {
				# bad one, we're outta here.
				$bad = 1;
				last;
			}
			elsif (defined($field->{'valid'})) {
				# there's a validation subroutine, call it
				my $r = $field->{'valid'}->($v);

				if (defined($r) && $r == 1) {
					push(@{$good},$v);
					$missing = 0;
				}
				else {
					$bad = 1;
					if (!defined($r) || $r == 0) {
						$r = 'BAD';
					}
					$self->{'ef'}->($field->{'name'},$r,$errors);
				}
			}
			elsif (defined($v)) {
				push(@{$good},$v);
				$missing = 0;
			}
		}

		# check requiredness
		if ($missing && $field->{'required'}) {
			$bad = 1;
			$self->{'ef'}->($field->{'name'},'MISSING',$errors);
		}

		$self->_pack($good,$field,$values) unless ($bad);
	}

	if (scalar keys %{$errors}) {
		return ($values,$errors);
	}
	else {
		return $values;
	}
}

sub _valid_varchar {
	my ($self,$v,$def,$errors) = @_;

	my $n = $def->{'name'};

	if ($def->{'length'} > 0 && length($v) > $def->{'length'}) {
		$self->{'ef'}->($n,'BIG',$errors);
	}
	elsif ($def->{'valid_email'}) {
		# Net::DNS pollutes the value of $_ with the IP of the DNS server that responsed to the lookup 
		# request.  It's localized to keep Net::DNS out of my pool.
		local $_;

		my $addr;
		eval {
			$addr = Email::Valid->address('-address' => $v,
			                              '-mxcheck' => 1, 
			                              '-fqdn'    => 1 );
		};
		if ($@) {
			$self->warn("Email::Valid produced an exception: $@");
			warn "Email::Valid produced an exception: $@";
			$self->{'ef'}->($n,'BAD',$errors);
		}
		elsif(!defined($addr)) {
			$self->{'ef'}->($n,'BAD',$errors);
		}
		else {
			return $v;
		}
	}
	elsif ($def->{'valid_url'}) {
		if (length($v) && Apache::Voodoo::Validate::URL::valid_url($v) == 0) {
			$self->{'ef'}->($n,'BAD',$errors);
		}
		else {
			return $v;
		}
	}
	elsif (defined($def->{'regexp'})) {
		my $re = $def->{'regexp'};
		if ($v =~ /$re/) {
			return $v;
		}
		else {
			$self->{'ef'}->($n,'BAD',$errors);
		}
	}
	else {
		return $v;
	}

	return undef,1;
}

sub _valid_unsigned_decimal {
	my ($self,$v,$def,$errors) = @_;

	if ($v =~ /^(\d*)(?:\.(\d+))?$/) {
		my $l = $2 || 0;
		my $r = $3 || 0;
		$l *= 1;
		$r *= 1;

		if (length($l) > $def->{'left'} ||
			length($r) > $def->{'right'} ) {

			$self->{ef}->($def->{'name'},'BIG',$errors);
		}
		else {
			return $v;
		}
	}
	else {
		$self->{ef}->($_->{'name'},'BAD',$errors);
	}
	return undef,1;
}

sub _valid_signed_decimal {
	my ($self,$v,$def,$errors) = @_;

	if ($v =~ /^(\+|-)?(\d*)(?:\.(\d+))?$/) {
		my $l = $2 || 0;
		my $r = $3 || 0;
		$l *= 1;
		$r *= 1;

		if (length($l) > $def->{'left'} ||
			length($r) > $def->{'right'} ) {
			$self->{ef}->($def->{'name'},'BIG',$errors);
		}
		else {
			return $v;
		}
	}
	else {
		$self->{ef}->($def->{'name'},'BAD',$errors);
	}

	return undef,1;
}

sub _valid_unsigned_int {
	my ($self,$v,$def,$errors) = @_;

	if ($v !~ /^\d*$/ )        { $self->{'ef'}->($def->{'name'},'BAD',$errors); }
	elsif ($v > $def->{'max'}) { $self->{'ef'}->($def->{'name'},'MAX',$errors); }
	else {
		return $v;
	}

	return undef,1;
}

sub _valid_signed_int {
	my ($self,$v,$def,$errors) = @_;

	if ($v !~ /^(\+|-)?\d*$/)                  { $self->{'ef'}->($def->{'name'},'BAD',$errors); }
	elsif (defined($v) && $v > $def->{'max'})  { $self->{'ef'}->($def->{'name'},'MAX',$errors); }
	elsif (defined($v) && $v < $def->{'min'})  { $self->{'ef'}->($def->{'name'},'MIN',$errors); }
	else {
		return $v;
	}

	return undef,1;
}

sub _valid_date {
	my ($self,$v,$def,$errors) = @_;

	if ($self->validate_date($v)) {
		my $d = $self->date_to_sql($v);

		if ($def->{valid_past} && $d gt $def->{now}->()) {
			$self->{ef}->($def->{'name'},'PAST',$errors);
		}
		elsif ($def->{valid_future} && $d le $def->{now}->()) {
			$self->{ef}->($def->{'name'},'FUTURE',$errors);
		}
		else {
			return $d;
		}
	}
	else {
		$self->{ef}->($def->{'name'},'BAD',$errors);
	}
	return undef,1;
}

sub _valid_time {
	my ($self,$v,$def,$errors) = @_;

	my $temp = $self->time_to_sql($v);
	if ($temp) {
		return $temp;
	}
	else {
		$self->{'ef'}->($def->{'name'},'BAD',$errors);
	}
	return undef,1;
}

sub _param {
	my $self   = shift;
	my $params = shift;
	my $def    = shift;

	my $p = $params->{$def->{'name'}};
	if (ref($p) eq "ARRAY") {
		if ($def->{'multiple'}) {
			return map {
				$self->_trim($_)
			} @{$p};
		}
		else {
			return $self->_trim($p->[0]);
		}
	}
	else {
		return $self->_trim($p);
	}
}

sub _pack {
	my $self = shift;
	my $v    = shift;
	my $def  = shift;
	my $vals = shift;

	return unless defined($v);

	$vals->{$def->{'name'}} = ($def->{'multiple'})?$v:$v->[0];
}

sub _trim {
	my $self = shift;
	my $v    = shift;

	return undef unless defined($v);

	$v =~ s/^\s*//;
	$v =~ s/\s*$//;

	return (length($v))?$v:undef;
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
