=pod ################################################################################

=head1 Apache::Voodoo::Table::Probe::mysql

$Id: mysql.pm,v 1.4 2001/12/27 05:01:16 maverick Exp $

=head1 Initial Coding: Maverick

Probes a MySQL database to get information about various tables.

=cut ################################################################################
package Apache::Voodoo::Table::Probe::mysql;

use DBI;

use strict;

use Data::Dumper;

our $DEBUG = 0;

sub new {
	my $class = shift;
	my $self = {};

	my $db_info = shift;

	$self->{'dbh'} = DBI->connect("dbi:mysql:database=$db_info->{'db'};host=$db_info->{'host'};", $db_info->{'user'},$db_info->{'pass'}) || die "Can't Connect: $DBI::errstr";

	$DEBUG = $db_info->{'debug'};

	bless $self, $class;
	return $self;
}

sub DESTROY {
	my $self = shift;
	$self->{'dbh'}->disconnect;
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
	$data->{'param_list'} = [];
	$data->{'required_list'} = [];

	$data->{'unsigned_integers'} = [];
	$data->{'signed_integers'}   = [];

	$data->{'unsigned_decimals'} = [];
	$data->{'signed_decimals'}   = [];

	$data->{'varchars'} = [];
	$data->{'dates'} = [];
	$data->{'times'} = [];

	# $data{'selections'} = []; ## not supported by mysql..have to do 'em yerself

	# $data{'in_list'} = {};	## must be added by hand
	# $data{'searchable'} = {};	## must be added by hand
	# $data{'sortable'} = {};	## must be added by hand

	my $table_info = $dbh->selectall_arrayref("explain $table") || return { 'ERRORS' => [ "explain of table $_ failed. $DBI::errstr" ] };

	foreach (@{$table_info}) {
		my $row = $_;
		my $name = $row->[0];

		debug("================================================================================");
		debug($row);
		debug("================================================================================");

		# add this to the parameter list
		push(@{$data->{'param_list'}},$name);

		# is this param required for add / edit (does the column allow nulls)
		push(@{$data->{'required_list'}},$name) unless $row->[2] eq "YES";

		if ($row->[3] eq "PRI") {
			# primary key.  NOTE THAT CLUSTERED PRIMARY KEYS ARE NOT SUPPORTED
			$data->{'pkey'} = $name;

			# is the primary key user supplied
			unless ($row->[5] eq "auto_increment") {
				$data->{'pkey_user_supplied'} = 1;
			}
		}
		elsif ($row->[3] eq "UNI") {
			# unique index.
			push(@{$data->{'unique'}},$name);
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
			$self->$type($data,$name,$size);
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
				{ 
					local($DEBUG);
					$DEBUG = 0;
					$ref_data = $self->probe_table($ref_table);
				}

				my $ref_info = { 'name'    => $name,
				                 'refs'    => $ref_table,
				                 'key'     => $ref_data->{'pkey'},
				                 'label'   => $ref_data->{'varchars'}->[0]->{'name'},
				                 'default' => $row->[4]
				               };
				debug($ref_info);
				push(@{$data->{'selections'}},$ref_info);
			}
			else {
				debug("No such table $ref_table: $DBI::errstr");
			}
		}
	}

	if (defined($data->{'ERRORS'})) {
		print STDERR "URK!\n";
		print STDERR join("\n",@{$data->{'ERRORS'}});
		print "\n";
		exit;
	}

	return $data;
}

sub tinyint_unsigned   { shift()->int_handler_unsigned(@_,1); }
sub smallint_unsigned  { shift()->int_handler_unsigned(@_,2); }
sub mediumint_unsigned { shift()->int_handler_unsigned(@_,3); }
sub int_unsigned       { shift()->int_handler_unsigned(@_,4); }
sub integer_unsigned   { shift()->int_handler_unsigned(@_,4); }
sub bigint_unsigned    { shift()->int_handler_unsigned(@_,8); }

sub int_handler_unsigned {
	my ($self,$data,$name,$size,$bytes) = @_;

	push(@{$data->{'unsigned_integers'}},{'name'   => $name, 
	                                      'max'    => 2 ** ($bytes * 8) - 1,
										  'length' => $size });
}

sub tinyint   { shift()->int_handler(@_,1); }
sub smallint  { shift()->int_handler(@_,2); }
sub mediumint { shift()->int_handler(@_,3); }
sub int       { shift()->int_handler(@_,4); }
sub integer   { shift()->int_handler(@_,4); }
sub bigint    { shift()->int_handler(@_,8); }

sub int_handler {
	my ($self,$data,$name,$size,$bytes) = @_;

	push(@{$data->{'signed_integers'}},{'name'   => $name, 
	                                    'max'    =>      (2 ** ($bytes * 8))/2,
	                                    'min'    => (0 - (2 ** ($bytes * 8))/2 - 1),
	                                    'length' => $size });

}

sub text {
	my ($self,$data,$name,$size) = @_;
	$self->varchar($data,$name,-1);
}

sub char {
	my $self = shift;
	$self->varchar(@_);
}

sub varchar {
	my ($self,$data,$name,$size) = @_;

	push(@{$data->{'varchars'}},{ 'name'   => $name,
	                              'length' => $size });
}

sub decimal_unsigned {
	my ($self,$data,$name,$size) = @_;

	my ($l,$r) = split(/,/,$size);

	push(@{$data->{'unsigned_decimals'}},{'name'   => $name,
	                                      'left'   => $l - $r,
							              'right'  => $r,
										  'length' => $r+$l+1});
}

sub decimal {
	my ($self,$data,$name,$size) = @_;

	my ($l,$r) = split(/,/,$size);

	push(@{$data->{'signed_decimals'}},{'name'   => $name,
	                                    'left'   => $l - $r,
	                                    'right'  => $r,
									    'length' => $r+$l+2});
}

sub date {
	my ($self,$data,$name,$size) = @_;

	push(@{$data->{'dates'}},{'name'   => $name,
	                          'length' => '10',
	                         });

}

sub time {
	my ($self,$data,$name,$size) = @_;

	push(@{$data->{'times'}},{'name' => $name,
	                          'length' => '10',
	                         });

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
