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
package Apache::Voodoo::Config;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;

use Data::Dumper;

my %COLUMN_TYPES = (
	"varchar" => { 
		'length' => 1,   # required
		'valid'  => 0,   # optional
		'regexp' => 0
	},
	'unsigned_int' => {
		'max' => 1,     
	},
	'signed_int' => {
		'max' => 1,
		'min' => 1,
	},
	"signed_decimal" => {
		'left'  => 1,
		'right' => 1,
	},
	"unsigned_decimal" => {
		'left'  => 1,
		'right' => 1,
	},
	'date'      => {},
	'time'      => {},
	'datetime'  => {},
	'timestamp' => {},
	'text'      => {},
	'bit'       => {}
);

my %X_TYPES = (
	"email" => {
	},
	"address" => {
	},
	"password" => {
	},
	"url" => {
	},
	"monthyear" => {
	},
	"monthyear" => {
	}
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

	$self->{ui} = ($c->{'ui'})?$c->{'ui'}:'html';

	$self->{'table'} = $c->{'table'}       || push(@errors,"missing table name");
	$self->{'pkey'}  = $c->{'primary_key'} || push(@errors,"missing primary key");
	$self->{'pkey_regexp'} = ($c->{'primary_key_regexp'})?$c->{'primary_key_regexp'}:'^\d+$';
	$self->{'pkey_user_supplied'} = ($c->{'primary_key_user_supplied'})?1:0;

	my @columns;
	if (ref($c->{'columns'}) eq "ARRAY") {
		@columns = @{$c->{'columns'}};
	}
	else {
		@columns = map {
			$c->{columns}->{$_}->{'id'} = $_;
			$c->{columns}->{$_};
		}
		sort { 
			$c->{columns}->{$a}->{'seq'} <=> $c->{columns}->{$b}->{'seq'} || 
			$a cmp $b 
		} 
		keys %{$c->{'columns'}};
	}

	foreach my $conf (@columns) {
		my $name = $conf->{id};

		unless (defined($conf->{'type'})) {
			push(@errors,"missing 'type' for column $name");
			next;
		}

		unless (defined($COLUMN_TYPES{$conf->{'type'}})) {
			push(@errors,"don't know how to handle type $conf->{'type'} for column $name");
			next;
		}

		if (defined($conf->{'xtype'}) && !defined($X_TYPES{$conf->{'xtype'}})) {
			push(@errors,"don't know how to handle extended type $conf->{'xtype'} for column $name");
			next;
		}
		
		if ($name eq $self->{'pkey'}) {
			# I'm thinking there's some other stuff I have to do here...
			# but I don't quite remember what :)
			# primary key definately CAN'T be listed in the columns...it makes 'add' very unhappy
			#
			# oh yeah, now I remember, need the column definition to know type, regexp, etc, etc.
			# it has to be pulled out and used separately.
			next;
		}

		push(@{$self->{'columns'}},$conf);

		my %my_conf;
		$my_conf{'name'} = $name;
		while (my ($k,$v) = each %{$COLUMN_TYPES{$conf->{'type'}}}) {
			$my_conf{$k} = $conf->{$k};
			if ($v == 1 && !defined($my_conf{$k})) {
				push(@errors,"$k is a required param for column type $conf->{'type'}");
			}
		}

		# grab the switches
		foreach ("required","unique") {
			if ($conf->{$_}) {
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

		push(@{$self->{$conf->{'type'}."s"}},\%my_conf);
	}

	$self->{'default_sort'} = $c->{'list_options'}->{'default_sort'};
	while (my ($k,$v) = each %{$c->{'list_options'}->{'sort'}}) {
		$self->{'list_sort'}->{$k} = (ref($v) eq "ARRAY")? join(", ",@{$v}) : $v;
	}

	foreach (@{$c->{'list_options'}->{'search'}}) {
		push(@{$self->{'list_search_items'}},[$_->[1],$_->[0]]);
		$self->{'list_search'}->{$_->[1]} = 1;
	}

	if (ref($c->{'joins'}) eq "ARRAY") {
		foreach (@{$c->{'joins'}}) {
			push(@{$self->{'joins'}},
				{
					table   => $_->{table},
					pkey    => $_->{primary_key},
					fkey    => $_->{foreign_key},
					columns => $_->{columns} || []
				}
			);
		}
	}

	$self->{'errors'} = \@errors;
	if (@errors) {
		$self->{'config_invalid'} = 1;

		print STDERR "Errors in Apache::Voodoo::Table configuration in ".(caller(1))[1]."\n";
		print STDERR join("\n",@errors,"\n");
	}
}

sub has_error {
	my $self = shift;

	return scalar(@{$self->{errors}});
}

sub errors {
	my $self = shift;

	return $self->{errors};
}

sub ui {
	my $self = shift;

	if ($_[0]) {
		$self->{ui} = $_[0];
	}

	return $self->{ui};
}

sub table {
	my $self = shift;

	if ($_[0]) {
		$self->{table} = $_[0];
	}

	return $self->{table};
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
