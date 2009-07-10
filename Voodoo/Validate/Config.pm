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
package Apache::Voodoo::Validate::Config;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Apache::Voodoo::Exception;
use Data::Dumper;

my %COLUMN_TYPES = (
	"varchar"          => \&_varchar,
	'unsigned_int'     => \&_unsigned_int,
	'signed_int'       => \&_signed_int,
	'signed_decimal'   => \&_signed_decimal,
	'unsigned_decimal' => \&_unsigned_decimal,
	'date'      => \&_date,
	'time'      => \&_time,
	'datetime'  => \&_null,
	'bit'       => \&_null,
	'text'      => sub { 
		$_[0]->{length} = 0; 
		return _varchar(@_);
	},
);

sub new {
	my $class = shift;

	my $self = {};
	bless $self, $class;

	$self->set_configuration(shift);

	return $self;
}

sub set_configuration {
	my $self = shift;

	my $c = shift;

	my @errors;

	my @fields;
	if (ref($c) eq "ARRAY") {
		@fields = @{$c};
	}
	else {
		no warnings "uninitialized";
		@fields = map {
			$c->{$_}->{'id'} = $_;
			$c->{$_};
		}
		sort { 
			$c->{$a}->{'seq'} ||= 0;
			$c->{$b}->{'seq'} ||= 0;

			$c->{$a}->{'seq'} cmp $c->{$b}->{'seq'} || 
			$a cmp $b;
		} 
		keys %{$c};
	}

	foreach (keys %COLUMN_TYPES) {
		$self->{$_.'s'} = [];
	}

	foreach my $conf (@fields) {
		my $name = $conf->{id};

		unless (defined($conf->{'type'})) {
			push(@errors,"missing 'type' for column $name");
			next;
		}

		unless (defined($COLUMN_TYPES{$conf->{'type'}})) {
			push(@errors,"don't know how to handle type $conf->{'type'} for column $name");
			next;
		}

		my ($c,$e) = $COLUMN_TYPES{$conf->{'type'}}->($conf);
		push(@errors,@{$e}) if scalar(@{$e});

		$c->{'name'} = $name;
		$c->{'type'} = $conf->{'type'};

		if (defined($c->{valid}) && ref($c->{valid}) ne "CODE") {
			push(@errors,"Field $conf->{id}: 'valid' is not a subroutine reference");
		}

		# grab the switches
		foreach ("required","unique",'multiple') {
			if ($conf->{$_}) {
				$c->{$_} = $conf->{$_};
				push(@{$self->{$_}},$name);
			}
		}

		if (defined($conf->{'references'})) {
			my %v;
			$v{'fkey'}     = $name;
			$v{'table'}    = $conf->{'references'}->{'table'};
			$v{'pkey'}     = $conf->{'references'}->{'primary_key'};
			$v{'columns'}  = $conf->{'references'}->{'columns'};
			$v{'slabel'}   = $conf->{'references'}->{'select_label'};
			$v{'sdefault'} = $conf->{'references'}->{'select_default'};
			$v{'sextra'}   = $conf->{'references'}->{'select_extra'};

			push(@errors,"no table in reference for $name")                 unless $v{'table'}  =~ /\w+/;
			push(@errors,"no primary key in reference for $name")           unless $v{'pkey'}   =~ /\w+/;
			push(@errors,"no label for select list in reference for $name") unless $v{'slabel'} =~ /\w+/;
			
			if (defined($v{'columns'})) {
				if (ref($v{'columns'})) {
					if (ref($v{'columns'}) ne "ARRAY") {
						push(@errors,"references => column must either be a scalar or arrayref for $name");
					}
				}
				else {
					$v{'columns'} = [ $v{'columns'} ];
				}
			}
			else {
				push(@errors,"references => columns must be defined for $name");
			}

			push(@{$self->{'references'}},\%v);
		}

		push(@{$self->{'fields'}},        $c);
		push(@{$self->{$c->{'type'}."s"}},$c);
	}

	$self->{'errors'} = \@errors;
	if (@errors) {
		$self->{'config_invalid'} = 1;

		Apache::Voodoo::Exception::RunTime->throw("message" => "Configuration Errors:\n\t".join("\n\t",@errors));
	}
}

sub has_error { return scalar(@{$_[0]->{errors}}); }

sub errors { return $_[0]->{errors}; }

sub table {
	my $self = shift;

	if ($_[0]) {
		$self->{table} = $_[0];
	}

	return $self->{table};
}


sub required { return @{$_[0]->{required}}; }

sub fields            { return @{$_[0]->{fields}};            }
sub varchars          { return @{$_[0]->{varchars}};          }
sub texts             { return @{$_[0]->{texts}};             }
sub unsigned_ints     { return @{$_[0]->{unsigned_ints}};     }
sub   signed_ints     { return @{$_[0]->{  signed_ints}};     }
sub unsigned_decimals { return @{$_[0]->{unsigned_decimals}}; }
sub   signed_decimals { return @{$_[0]->{  signed_decimals}}; }
sub dates             { return @{$_[0]->{dates}};             }
sub times             { return @{$_[0]->{times}};             }
sub datetimes         { return @{$_[0]->{datetimes}};         }
sub bits              { return @{$_[0]->{bits}};              }

sub _varchar {
	my $c = shift;
	my %h;
	my @e;
	if (defined($c->{length})) {
		if ($c->{length} =~ /^\d+$/) {
			$h{length} = $c->{length};
		}
		else {
			push(@e,"Field $c->{id}: 'length' must be positive integer");
		}
	}
	else {
		$h{length} = 0;
	}

	if (defined($c->{valid})) {
		if ($c->{valid} =~ /^(url|email)$/ ) {
			$h{'valid_'.$c->{valid}} = 1;
		}
		elsif (ref($c->{valid}) eq "CODE") {
			$h{valid} = $c->{valid};
		}
		else {
			push(@e,"Field $c->{id}: valid must be either 'email','url', or a subroutine reference");
		}
	}

	if (defined($c->{regexp})) {
		$h{regexp} = $c->{regexp};
	}

	return \%h,\@e;
}

sub _unsigned_int {
	my $c = shift;
	my %h;
	my @e;
	if (defined($c->{bytes})) {
		if ($c->{bytes} =~ /^\d+$/) {
			$h{max} = 2 ** ($c->{bytes} * 8) - 1;
		}
		else {
			push(@e,"Field $c->{id}: 'bytes' must be a positive integer");
		}
	}
	elsif (defined($c->{max})) {
		if ($c->{max} =~ /^\d+$/) {
			$h{max} = $c->{max};
		}
		else {
			push(@e,"Field $c->{id}: 'max' must be a positive integer");
		}
	}
	else {
		push(@e,"Field $c->{id}: either 'max' or 'bytes' is a required parameter");
	}

	$h{valid} = $c->{valid};

	return \%h,\@e;
}

sub _signed_int {
	my $c = shift;
	my %h;
	my @e;
	if (defined($c->{bytes})) {
		if ($c->{bytes} =~ /^\d+$/) {
			$h{'max'}  = (     2 ** ($c->{bytes} * 8))/2;
			$h{'min'}  = (0 - (2 ** ($c->{bytes} * 8))/2 - 1);
		}
		else {
			push(@e,"Field $c->{id}: 'bytes' must be a positive integer");
		}
	}
	elsif (defined($c->{max}) && defined($c->{min})) {
		if ($c->{max} =~ /^\d+$/) {
			$h{max} = $c->{max};
		}
		else {
			push(@e,"Field $c->{id}: 'max' must be zero or a positive integer");
		}

		if ($c->{min} =~ /^(0+|-\d+)$/) {
			$h{min} = $c->{min};
		}
		else {
			push(@e,"Field $c->{id}: 'min' must be zero or a negative integer");
		}
	}
	else {
		push(@e,"Field $c->{id}: either 'max' and 'min' or 'bytes' is a required parameter");
	}

	$h{valid} = $c->{valid};

	return \%h,\@e;
}

sub _signed_decimal {
	my $c = shift;
	my %h;
	my @e;
	if (defined($c->{left})) {
		if ($c->{left} =~ /^\d+$/) {
			$h{left} = $c->{left};
		}
		else {
			push(@e,"Field $c->{id}: 'left' must be positive integer");
		}
	}
	else {
		push(@e,"Field $c->{id}: 'left' must be positive integer");
	}

	if (defined($c->{right})) {
		if ($c->{right} =~ /^\d+$/) {
			$h{right} = $c->{right};
		}
		else {
			push(@e,"Field $c->{id}: 'right' must be positive integer");
		}
	}
	else {
		push(@e,"Field $c->{id}: 'right' must be positive integer");
	}

	$h{valid} = $c->{valid};

	return \%h,\@e;
}

sub _unsigned_decimal {
	my $c = shift;
	my %h;
	my @e;
	if (defined($c->{left})) {
		if ($c->{left} =~ /^\d+$/) {
			$h{left} = $c->{left};
		}
		else {
			push(@e,"Field $c->{id}: 'left' must be positive integer");
		}
	}
	else {
		push(@e,"Field $c->{id}: 'left' must be positive integer");
	}

	if (defined($c->{right})) {
		if ($c->{right} =~ /^\d+$/) {
			$h{right} = $c->{right};
		}
		else {
			push(@e,"Field $c->{id}: 'right' must be positive integer");
		}
	}
	else {
		push(@e,"Field $c->{id}: 'right' must be positive integer");
	}

	$h{valid} = $c->{valid};

	return \%h,\@e;
}

sub _date {
	my $c = shift;
	my %h;
	my @e;

	if (defined($c->{valid})) {
		if ($c->{valid} =~ /^(past|future)$/ ) {
			$h{'valid_'.$c->{valid}} = 1;
		}
		elsif (ref($c->{valid}) eq "CODE") {
			$h{valid} = $c->{valid};
		}
		else {
			push(@e,"Field $c->{id}: valid must be either 'past','future', or a subroutine reference");
		}
	}

	if (defined($c->{now})) {
		if (ref($c->{now}) eq "CODE") {
			$h{now} = $c->{now};
		}
		else {
			push(@e,"Field $c->{id}: now must be a subroutine reference");
		}
	}
	else {
		$h{now} = sub {
			my @tp = localtime();
			return sprintf("%04d-%02d-%02d",$tp[5]+1900,$tp[4]+1,$tp[3]);
		}
	}

	return \%h,\@e;
}

sub _time {
	my $c = shift;
	my %h;
	my @e;

	if (defined($c->{min})) {
		my $t = _valid_time($c->{min});
		if ($t) {
			$h{'min'} = $t;
		}
		else {
			push(@e,"Field $c->{id}: 'min' must be a valid time in either civillian or military form.");
		}
	}

	if (defined($c->{max})) {
		my $t = _valid_time($c->{max});
		if ($t) {
			$h{'max'} = $t;
		}
		else {
			push(@e,"Field $c->{id}: 'max' must be a valid time in either civillian or military form.");
		}
	}

	$h{valid} = $c->{valid};

	return \%h,\@e;
}

sub _valid_time {
	my $time = shift;

    $time =~ s/\s*//go;
    $time =~ s/\.//go;

	unless ($time =~ /^\d?\d:[0-5]?\d(:[0-5]?\d)?(am|pm)?$/i) {
		warn "regexp $time";
        return undef;
    }

	my ($h,$m,$s);
    if ($time =~ s/([ap])m$//igo) {
        my $pm = (lc($1) eq "p")?1:0;

    	($h,$m,$s) = split(/:/,$time);

		# 12 am is midnight and 12 pm is noon...I've always hated that.
		if ($pm eq '1') {
			if ($h < 12) {
				$h += 12;
			}
			elsif ($h > 12) {
				return undef;
			}
		}
		elsif ($pm eq '0' && $h == 12) {
			$h = 0;
		}
    }
	else {
    	($h,$m,$s) = split(/:/,$time);
	}

	# our regexp above validated the minutes and seconds, so
	# all we need to check that the hours are valid.
    if ($h < 0 || $h > 23) { return undef; }

	$s = 0 unless (defined($s));
   	return sprintf("%02d:%02d:%02d",$h,$m,$s);
}

sub _null {
	return {},[];
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
