=pod ################################################################################

=head1 Apache::Voodoo::Table::Probe::mysql

$Id: MySQL.pm 12906 2009-02-20 23:08:10Z medwards $

=head1 Initial Coding: Maverick

Probes a MySQL database to get information about various tables.

This is old and crufty and not for public use

=cut ################################################################################
package Apache::Voodoo::Table::Probe::MySQL;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use DBI;
use Data::Dumper;

use strict;

our $DEBUG = 0;

sub new {
	my $class = shift;
	my $self = {};

	$self->{'dbh'} = shift;
	print Dumper $self->{dbh}->get_info(17);

	bless $self, $class;
	return $self;
}

sub list_tables {
	my $self = shift;

	my $res = $self->{'dbh'}->selectall_arrayref("show tables") || die $DBI::errstr;

	return map { $_->[0] } @{$res};
}

sub probe_table {
	my $self = shift;

	my $table = shift;

	my $dbh = $self->{'dbh'};

	my $data = {};
	$data->{table} = $table;

	my @fields;

	my $table_info = $dbh->selectall_arrayref("explain $table") || return { 'ERRORS' => [ "explain of table $_ failed. $DBI::errstr" ] };

	foreach (@{$table_info}) {
		my $row = $_;
		my $name = $row->[0];
		my $column = {};

		debug("================================================================================");
		debug($row);
		debug("================================================================================");

		# is this param required for add / edit (does the column allow nulls)
		$column->{'required'} = 1 unless $row->[2] eq "YES";

		if ($row->[3] eq "PRI") {
			# primary key.  NOTE THAT CLUSTERED PRIMARY KEYS ARE NOT SUPPORTED
			$data->{'primary_key'} = $name;

			# is the primary key user supplied
			unless ($row->[5] eq "auto_increment") {
				$data->{'pkey_user_supplied'} = 1;
				push(@fields,$name);
			}
		}
		elsif ($row->[3] eq "UNI") {
			# unique index.
			$column->{'unique'} = 1;
			push(@fields,$name);
		}
		else {
			push(@fields,$name);
		}

		#
		# figure out the column type
		#
		my $type = $row->[1];
		my ($size) = ($type =~ /\(([\d,]+)\)/);

		$type =~ s/[,\d\(\) ]+/_/g;
		$type =~ s/_$//g;

		eval {
			debug("Examining data type: $type($size)...");
			$self->$type($column,$size);
			debug("OK");
		};
		if ($@) {
			debug("UNKNOWN");
			push(@{$data->{'ERRORS'}},"unsupported type $row->[1]");
		}
		#
		# figure out foreign keys
		#
		if ($name =~ /^(\w+)_id$/) {
			my $ref_table = $1;
			debug("referenced table is: $ref_table");

			my $ref_table_info = $dbh->selectall_arrayref("explain $ref_table");
			if (ref($ref_table_info)) {
				# figure out table structure

				my $ref_data;
				my $ref_fields;
				{ 
					local($DEBUG);
					$DEBUG = 0;
					($ref_data,$ref_fields) = $self->probe_table($ref_table);
				}

				my $ref_info = { 
					'table'          => $ref_table,
					'primary_key'    => $ref_data->{'primary_key'},
					'select_label'   => $ref_table,
					'select_default' => $row->[4]
				};

				$ref_info->{columns} = [ grep {$ref_data->{columns}->{$_}->{type} eq "varchar"} keys %{$ref_data->{columns}} ];

				debug($ref_info);
				$column->{references} = $ref_info;
			}
			else {
				debug("No such table $ref_table: $DBI::errstr");
			}
		}

		$data->{columns}->{$name} = $column;
	}

	if (defined($data->{'ERRORS'})) {
		print STDERR "URK!\n";
		print STDERR join("\n",@{$data->{'ERRORS'}});
		print "\n";
		exit;
	}

	return $data,\@fields;
}

sub tinyint_unsigned   { shift()->int_handler_unsigned(@_,1); }
sub smallint_unsigned  { shift()->int_handler_unsigned(@_,2); }
sub mediumint_unsigned { shift()->int_handler_unsigned(@_,3); }
sub int_unsigned       { shift()->int_handler_unsigned(@_,4); }
sub integer_unsigned   { shift()->int_handler_unsigned(@_,4); }
sub bigint_unsigned    { shift()->int_handler_unsigned(@_,8); }

sub int_handler_unsigned {
	my ($self,$column,$size,$bytes) = @_;

	$column->{'type'} = 'unsigned_int';
	$column->{'max'}  = 2 ** ($bytes * 8) - 1;
}

sub tinyint   { shift()->int_handler(@_,1); }
sub smallint  { shift()->int_handler(@_,2); }
sub mediumint { shift()->int_handler(@_,3); }
sub int       { shift()->int_handler(@_,4); }
sub integer   { shift()->int_handler(@_,4); }
sub bigint    { shift()->int_handler(@_,8); }

sub int_handler {
	my ($self,$column,$size,$bytes) = @_;

	$column->{'type'} = 'signed_int';
	$column->{'max'}  = (2 ** ($bytes * 8))/2;
	$column->{'min'}  = (0 - (2 ** ($bytes * 8))/2 - 1);
}

sub text {
	my ($self,$column,$size) = @_;
	$self->varchar($column,-1);
}

sub char {
	my $self = shift;
	$self->varchar(@_);
}

sub varchar {
	my ($self,$column,$size) = @_;

	$column->{'type'} = 'varchar';
	$column->{'length'} = $size;
}

sub decimal_unsigned {
	my ($self,$column,$size) = @_;

	my ($l,$r) = split(/,/,$size);

	$column->{'type'}   = 'unsigned_decimal';
	$column->{'left'}   = 'left'   => $l - $r;
	$column->{'right'}  = $r;
	$column->{'length'} = $r+$l+1;
}

sub decimal {
	my ($self,$column,$size) = @_;

	my ($l,$r) = split(/,/,$size);

	$column->{'type'}   = 'signed_decimal';
	$column->{'left'}   = $l - $r;
	$column->{'right'}  = $r;
	$column->{'length'} = $r+$l+2;
}

sub date {
	my ($self,$column,$size) = @_;

	$column->{'type'}   = 'date';
	$column->{'length'} = '10';
}

sub time {
	my ($self,$column,$size) = @_;

	$column->{'type'}   = 'time';
	$column->{'length'} = '10';
}

sub timestamp {
	# timestamp is a 'magically' updated column that we don't touch
}

sub debug {
	return unless $DEBUG;

	if (ref($_[0])) {
		print STDERR Dumper(@_);
	}
	else {
		print STDERR @_,"\n";
	}
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include in
this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version of 
the Artistic License :)

=cut ################################################################################
