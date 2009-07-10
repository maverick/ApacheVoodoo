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
			my ($v,@b) = $COLUMN_TYPES{$field->{type}}->($self,$field,$_);

			if (defined($b[0])) {
				# bad one, we're outta here.
				$bad = 1;
				foreach (@b) {
					$self->{'ef'}->($field->{'name'},$_,$errors);
				}
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
	my ($self,$def,$v) = @_;

	my $n = $def->{'name'};

	my $e;
	if ($def->{'length'} > 0 && length($v) > $def->{'length'}) {
		$e = 'BIG';
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
			$e = 'BAD';
		}
		elsif(!defined($addr)) {
			$e = 'BAD';
		}
	}
	elsif ($def->{'valid_url'}) {
		if (length($v) && Apache::Voodoo::Validate::URL::valid_url($v) == 0) {
			$e = 'BAD';
		}
	}
	elsif (defined($def->{'regexp'})) {
		my $re = $def->{'regexp'};
		unless ($v =~ /$re/) {
			$e = 'BAD';
		}
	}

	return $v,$e;
}

sub _valid_unsigned_decimal {
	my ($self,$def,$v) = @_;

	my $e;
	if ($v =~ /^(\d*)(?:\.(\d+))?$/) {
		my $l = $2 || 0;
		my $r = $3 || 0;
		$l *= 1;
		$r *= 1;

		if (length($l) > $def->{'left'} ||
			length($r) > $def->{'right'} ) {

			$e='BIG';
		}
	}
	else {
		$e='BAD';
	}

	return $v,$e;
}

sub _valid_signed_decimal {
	my ($self,$def,$v) = @_;

	my $e;
	if ($v =~ /^(\+|-)?(\d*)(?:\.(\d+))?$/) {
		my $l = $2 || 0;
		my $r = $3 || 0;
		$l *= 1;
		$r *= 1;

		if (length($l) > $def->{'left'} ||
			length($r) > $def->{'right'} ) {
			$e='BIG';
		}
	}
	else {
		$e='BAD';
	}
	return $v,$e;
}

sub _valid_unsigned_int {
	my ($self,$def,$v) = @_;

	return undef,'BAD' unless ($v =~ /^\d*$/ );
	return undef,'MAX' unless ($v <= $def->{'max'});

	return $v;
}

sub _valid_signed_int {
	my ($self,$def,$v) = @_;

	return undef,'BAD' unless ($v =~ /^(\+|-)?\d*$/);
	return undef,'MAX' unless ($v <= $def->{'max'});
	return undef,'MIN' unless ($v >= $def->{'min'});

	return $v;
}

sub _valid_date {
	my ($self,$def,$v) = @_;

	my $e;
	if ($self->validate_date($v)) {
		$v = $self->date_to_sql($v);

		if ($def->{valid_past} && $v gt $def->{now}->()) {
			$e = 'PAST';
		}
		elsif ($def->{valid_future} && $v le $def->{now}->()) {
			$e = 'FUTURE';
		}
	}
	else {
		$e = 'BAD';
	}

	return $v,$e;
}

sub _valid_time {
	my ($self,$def,$v) = @_;

    $v =~ s/\s*//go;
    $v =~ s/\.//go;

	unless ($v =~ /^\d?\d:[0-5]?\d(:[0-5]?\d)?(am|pm)?$/i) {
		return undef,'BAD';
    }

	my ($h,$m,$s);
    if ($v =~ s/([ap])m$//igo) {
        my $pm = (lc($1) eq "p")?1:0;

    	($h,$m,$s) = split(/:/,$v);

		# 12 am is midnight and 12 pm is noon...I've always hated that.
		if ($pm eq '1') {
			if ($h < 12) {
				$h += 12;
			}
			elsif ($h > 12) {
				return undef,'BAD';
			}
		}
		elsif ($pm eq '0' && $h == 12) {
			$h = 0;
		}
    }
	else {
    	($h,$m,$s) = split(/:/,$v);
	}

	# our regexp above validated the minutes and seconds, so
	# all we need to check that the hours are valid.
    if ($h < 0 || $h > 23) { 
		return undef,'BAD';
	}

	$s = 0 unless (defined($s));
   	$v =  sprintf("%02d:%02d:%02d",$h,$m,$s);

	if (defined($def->{min}) && $v lt $def->{min}) {
		return undef,'MIN';
	}

	if (defined($def->{max}) && $v gt $def->{max}) {
		return undef,'MAX';
	}

	return $v;
}

sub _valid_bit {
	my ($self,$def,$v) = @_;

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
