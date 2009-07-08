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

use Apache::Voodoo::Validate::Config;
use Apache::Voodoo::Validate::URL;

use Data::Dumper;
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

sub add_insert_callback {
	my $self    = shift;
	my $sub_ref = shift;

	push(@{$self->{'insert_callbacks'}},$sub_ref);
}

sub add_update_callback {
	my $self    = shift;
	my $sub_ref = shift;

	push(@{$self->{'update_callbacks'}},$sub_ref);
}

sub add_error_callback {
	my $self    = shift;
	my $sub_ref = shift;

	if (ref($sub_ref) eq "CODE") {
		$self->{'ef'} = $sub_ref;
	}
}

sub validate {
	my $self   = shift;
	my $params = shift;

	my $c = $self->{'config'};

	my %values = ();
	my $errors = {};

	##############
	# check required
	##############
	foreach ($c->required) {
		if (!defined($params->{$_}) ||  $params->{$_} =~ /^\s*$/) {
			$self->{'ef'}->($_,'MISSING',$errors);
		}
	}

	##############
	# varchar
	##############
	foreach my $varchar ($c->varchars) {
		my $v = $self->trim($params->{$varchar->{'name'}});
		next unless defined($v);

		my $n = $varchar->{'name'};

		if ($varchar->{'length'} > 0 && length($v) > $varchar->{'length'}) {
			$self->{'ef'}->($n,'BIG',$errors);
		}
		elsif (defined($varchar->{'valid'})) {
			if ($varchar->{'valid'} eq "email" && length($v) > 0) {
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
					$values{$n} = $addr;
				}
			}
			elsif ($varchar->{'valid'} eq "url") {
				if (length($v) && Apache::Voodoo::Validate::URL::valid_url($v) == 0) {
					$self->{'ef'}->($n,'BAD',$errors);
				}
				else {
					$values{$n} = $v;
				}
			}
			elsif (ref($varchar->{'valid'}) eq "CODE") {
				my $r = $varchar->{'valid'}->($v);
				if (defined($r) && $r == 1) {
					$values{$n} = $v;
				}
				else {
					if (!defined($r) || $r == 0) {
						$r = 'BAD';
					}
					$self->{'ef'}->($n,$r,$errors);
				}
			}
			else {
				$self->warn("No such validation type: ".$varchar->{'valid'});
			}
		}
		elsif (defined($varchar->{'regexp'})) {
			my $re = $varchar->{'regexp'};
			if ($v =~ /$re/) {
				$values{$n} = $v;
			}
			else {
				$self->{'ef'}->($n,'BAD',$errors);
			}
		}
		elsif ($varchar->{length} > 0) {
			# If there was a length restriction, then this data
			# isn't in a text area and needs to have it's " HTML entitified
			$v =~ s/"/\&quot;/g;
			$values{$n} = $v;
		}
		else {
			$values{$n} = $v;
		}
	}

	##############
	# + decimal
	##############
	foreach ($c->unsigned_decimals) {
		my $v = $self->trim($params->{$_->{'name'}});
		next unless defined($v);

		if ($v =~ /^(\d*)(?:\.(\d+))?$/) {
			my $l = $2 || 0;
			my $r = $3 || 0;
			$l *= 1;
			$r *= 1;

			if (length($l) > $_->{'left'} ||
				length($r) > $_->{'right'} ) {

				$self->{ef}->($_->{'name'},'BIG',$errors);
			}
			else {
				$values{$_->{'name'}} = $v;
			}
		}
		else {
			$self->{ef}->($_->{'name'},'BAD',$errors);
		}
	}

	##############
	# +/- decimal
	##############
	foreach ($c->signed_decimals) {
		my $v = $self->trim($params->{$_->{'name'}});
		next unless defined($v);

		if ($v =~ /^(\+|-)?(\d*)(?:\.(\d+))?$/) {
			my $l = $2 || 0;
			my $r = $3 || 0;
			$l *= 1;
			$r *= 1;

			if (length($l) > $_->{'left'} ||
				length($r) > $_->{'right'} ) {
				$self->{ef}->($_->{'name'},'BIG',$errors);
			}
			else {
				$values{$_->{'name'}} = $v;
			}
		}
		else {
			$self->{ef}->($_->{'name'},'BAD',$errors);
		}
	}

	##############
	# + int
	##############
	foreach ($c->unsigned_ints) {
		my $v = $self->trim($params->{$_->{'name'}});
		next unless defined($v);

		if (   defined($v) && $v !~ /^\d*$/ )   { $self->{ef}->($_->{'name'},'BAD',$errors); }
		elsif (defined($v) && $v > $_->{'max'}) { $self->{ef}->($_->{'name'},'MAX',$errors); }
		else {
			$values{$_->{'name'}} = $v;
		}
	}

	##############
	# +/- int
	##############
	foreach ($c->signed_ints) {
		my $v = $self->trim($params->{$_->{'name'}});
		next unless defined($v);

		if ($v !~ /^(\+|-)?\d*$/)                { $self->{ef}->($_->{'name'},'BAD',$errors); }
		elsif (defined($v) && $v > $_->{'max'})  { $self->{ef}->($_->{'name'},'MAX',$errors); }
		elsif (defined($v) && $v < $_->{'min'})  { $self->{ef}->($_->{'name'},'MIN',$errors); }
		else {
			$values{$_->{'name'}} = $v;
		}
	}

	##############
	# Dates
	##############
	foreach ($c->dates) {
		my $v = $self->trim($params->{$_->{'name'}});
		next unless defined($v);

		if ($v ne "") {
			if ($self->validate_date($v)) {
				$values{$_->{'name'}} = $self->date_to_sql($v);
			}
			else {
				$self->{ef}->($_->{'name'},'BAD',$errors);
			}
		}
	}

	##############
	# Times
	##############
	foreach ($c->times) {
		my $v = $self->trim($params->{$_->{'name'}});
		next unless defined($v);

		if ($v ne "") {
			my $temp = $self->time_to_sql($v);
			if ($temp) {
				$values{$_->{'name'}} = $temp;
			}
			else {
				$self->{ef}->($_->{'name'},'BAD',$errors);
			}
		}
	}

	if (scalar keys %{$errors}) {
		return (\%values,$errors);
	}
	else {
		return \%values;
	}
}

sub trim {
	my $self = shift;
	my $v    = shift;

	return undef unless defined($v);

	$v =~ s/^\s*//;
	$v =~ s/\s*$//;

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
