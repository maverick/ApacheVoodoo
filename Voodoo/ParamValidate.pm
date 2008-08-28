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
package Apache::Voodoo::ParamValidate;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use strict;

use base("Apache::Voodoo");
use Data::Dumper;

use Email::Valid;

use Apache::Voodoo::ValidURL;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

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

sub _process_params {
	my $self   = shift;
	my $params = shift;

	my %v;
	my %errors;

	##############
	# copy params out
	##############
	foreach (@{$self->{'columns'}}) {
		$params->{$_} =~ s/^\s*//go;
		$params->{$_} =~ s/\s*$//go;

		$v{$_} = $params->{$_};
	}

	##############
	# check required
	##############
	foreach (@{$self->{'required'}}) {
		if ($v{$_} eq "") {
			$errors{'MISSING_'.$_} = 1;
		}
	}

	##############
	# varchar
	##############
	foreach my $varchar (@{$self->{'varchars'}}) {
		if ($varchar->{'length'} > 0 && length($v{$varchar->{'name'}}) > $varchar->{'length'}) {
			$errors{'BIG_'.$varchar->{'name'}} = 1;
		}
		elsif (defined($varchar->{'valid'})) {
			if ($varchar->{'valid'} eq "email" && length($v{$varchar->{'name'}}) > 0) {
				# Net::DNS does something *REMARKABLY STUPID* with $_.  No matter what you do it *ALWAYS* overwrites
				# the value of $_ with the IP of the DNS server that responsed to the lookup request.  This localization
				# of $_ keeps Net::DNS for pissing in everybody else's pool.
				local $_;

				my $addr;

				eval {
					$addr = Email::Valid->address('-address' => $v{$varchar->{'name'}},
					                              '-mxcheck' => 1, 
											      '-fqdn'    => 1 );
				};
				if ($@) {
					$self->debug("Email::Valid produced an exception: $@");
					warn "Email::Valid produced an exception: $@";
					$errors{'BAD_'.$varchar->{'name'}} = 1;
				}
				elsif(!defined($addr)) {
					$errors{'BAD_'.$varchar->{'name'}} = 1;
				}
				else {
					$v{$varchar->{'name'}} = $addr;
				}
			}
			elsif($varchar->{'valid'} eq "url") {
				if (length($v{$varchar->{'name'}}) && Apache::Voodoo::ValidURL::valid_url($v{$varchar->{'name'}}) == 0) {
					$errors{'BAD_'.$varchar->{'name'}} = 1;
				}
			}
		}
		elsif (defined($varchar->{'regexp'})) {
			 my $re = $varchar->{'regexp'};
			 unless ($v{$varchar->{'name'}} =~ /$re/) {
				 $errors{'BAD_'.$varchar->{'name'}} = 1;
			 }
		}
		elsif ($varchar->{length} > 0) {
			# If there was a length restriction, than this data
			# isn't in a text area and needs to have it's " HTML entitified
			$v{$varchar->{'name'}} =~ s/"/\&quot;/g;
		}
	}

	##############
	# + decimal
	##############
	foreach (@{$self->{'unsigned_decimals'}}) {
		if ($v{$_->{'name'}} =~ /^(\d*)(?:\.(\d+))?$/) {
			my $l = $2 || 0;
			my $r = $3 || 0;
			$l *= 1;
			$r *= 1;

			if (length($l) > $_->{'left'} ||
				length($r) > $_->{'right'} ) {
				$errors{'BIG_'.$_->{'name'}} = 1;
			}
		}
		else {
			$errors{'BAD_'.$_->{'name'}} = 1;	
		}
	}

	##############
	# +/- decimal
	##############
	foreach (@{$self->{'signed_decimals'}}) {
		if ($v{$_->{'name'}} =~ /^(\+|-)?(\d*)(?:\.(\d+))?$/) {
			my $l = $2 || 0;
			my $r = $3 || 0;
			$l *= 1;
			$r *= 1;

			if (length($l) > $_->{'left'} ||
				length($r) > $_->{'right'} ) {
				$errors{'BIG_'.$_->{'name'}} = 1;
			}
		}
		else {
			$errors{'BAD_'.$_->{'name'}} = 1;	
		}
	}

	##############
	# + int
	##############
	foreach (@{$self->{'unsigned_ints'}}) {
		if ($v{$_->{'name'}} eq "") {
			$v{$_->{'name'}} = undef;
		}
		elsif ($v{$_->{'name'}} !~ /^\d*$/){
			$errors{'BAD_'.$_->{'name'}} = 1;	
		}
		elsif ($v{$_->{'name'}} > $_->{'max'}) {
			$errors{'MAX_'.$_->{'name'}} = 1;	
		}
	}

	##############
	# +/- int
	##############
	foreach (@{$self->{'signed_ints'}}) {
		if ($v{$_->{'name'}} eq "") {
			$v{$_->{'name'}} = undef;
		}
		elsif ($v{$_->{'name'}} !~ /^(\+|-)?\d*$/){
			$errors{'BAD_'.$_->{'name'}} = 1;	
		}
		elsif ($v{$_->{'name'}} > $_->{'max'}) {
			$errors{'MAX_'.$_->{'name'}} = 1;	
		}
		elsif ($v{$_->{'name'}} < $_->{'min'}) {
			$errors{'MIN_'.$_->{'name'}} = 1;	
		}
	}

	##############
	# Dates
	##############
	foreach (@{$self->{'dates'}}) {
		if ($v{$_->{'name'}} eq "") {
			$v{$_->{'name'}."_CLEAN"} = undef;
		}
		else {
			if ($self->validate_date($v{$_->{'name'}})) {
				$v{$_->{'name'}."_CLEAN"} = $self->date_to_sql($v{$_->{'name'}});
			}
			else {
				$errors{"BAD_".$_->{'name'}} = 1;
			}
		}
	}

	##############
	# Times
	##############
	foreach (@{$self->{'times'}}) {
		if ($v{$_->{'name'}} eq "") {
			$v{$_->{'name'}."_CLEAN"} = undef;
		}
		else {
			my $temp = $self->time_to_sql($v{$_->{'name'}});
			if ($temp) {
				$v{$_->{'name'}."_CLEAN"} = $temp;
			}
			else {
				$errors{"BAD_".$_->{'name'}} = 1;
			}
		}
	}

	return (\%v,\%errors);
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
# Copyright (c) 2005 Steven Edwards.  All rights reserved.
# 
# You may use and distribute Voodoo under the terms described in the LICENSE file include
# in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
# of the Artistic License :)
# 
#####################################################################################
