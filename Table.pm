#####################################################################################

=head1 Voodoo::Table

$Id$

=head1 Initial Coding: Maverick

FIXME
FIXME  Add the TONS of necessary documentation
FIXME

=cut ################################################################################

package Voodoo::Table;

use strict;

use base("Voodoo::Base");

use Voodoo::Valid_URL;
use Email::Valid;

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	my $self = {};

	my $c = shift;

	# here's the config parameters that this object takes
	my %params = (
		'TABLE'              => 1,
		'PKEY'               => 1,
		'PKEY_TYPE'          => 1,
		'PKEY_USER_SUPPLIED' => 1,
		'PKEY_REGEXP'        => 1,
		'PARAM_LIST'         => 1,
		'LIST_COLS'          => 1,
		'SORT_COLS'          => 1,
		'SEARCH_COLS'        => 1,
		'REQUIRED_LIST'      => 1,
		'UNIQUE'             => 1,
		'VARCHARS'           => 1,
		'SELECTIONS'         => 1,
		'LEFT_JOINS'         => 1,
		'SIGNED_DECIMALS'    => 1,
		'UNSIGNED_DECIMALS'  => 1,
		'SIGNED_INTEGERS'    => 1,
		'UNSIGNED_INTEGERS'  => 1,
		'DATES'              => 1,
		'TIMES'              => 1,
	);

	my @bad_keys;
	foreach (keys %{$c} ) {
		my $key  = $_;
		my $ukey = uc($_);

		if (defined($params{$ukey})) {
			$self->{$ukey} = $c->{$key};
		}
		else{
			push(@bad_keys,$key);
		}
	}

	# make sure we weren't passed any invalid keys
	foreach (@bad_keys) {
		print STDERR "UNKNOWN CONFIG DIRECTIVE TO Voodoo::Table: $_\n";
	}

	unless (defined($self->{'PKEY_REGEXP'})) {
		if ($self->{'PKEY_TYPE'} eq "varchar") {
			$self->{'PKEY_REGEXP'} = '^[\w\s-]+$';
		}
		else {
			$self->{'PKEY_REGEXP'} = '^\d+$';
		}
	}

	bless $self, $class;
	return $self;
}

#
# adds a data validation routine to the add function
#
sub add_insert_callback {
	my $self    = shift;
	my $sub_ref = shift;

	push(@{$self->{'insert_callbacks'}},$sub_ref);
}

#
# adds a data validation routine to the edit function
#
sub add_update_callback {
	my $self    = shift;
	my $sub_ref = shift;

	push(@{$self->{'update_callbacks'}},$sub_ref);
}

#
# performs a database insertion
#
sub add {
	my $self = shift;
	my $p = shift;

	my $conn      = $p->{'dbconn'};
	my $params    = $p->{'parameters'};

	my $errors = {};
	if ($params->{'cm'} eq "add") {
		# we're going to attempt the addition
		my $values;

		# call each of the insert_callbacks
		foreach (@{$self->{'insert_callbacks'}}) {
			# call back should return a list of error strings
			foreach (&{$_}($conn,$params)) {
				if (length($_)) {
					$errors->{$_} = 1;
				}
			}
		}

		my $e;

		# do all the normal parameter checking
		($values,$e) = $self->_process_params($params);

		if (defined($e)) {
			# copy the errors from the process_params
			$errors = { %{$errors}, %{$e} };
		}

		# check to see if the user supplied primary key (optional) is unique
		if ($self->{'PKEY_USER_SUPPLIED'}) {
			my $sth = $conn->prepare("select 1 from $self->{'TABLE'} WHERE $self->{'PKEY'} = ?") || $self->db_error();
			$sth->execute($values->{$self->{'PKEY'}}) || $self->db_error();
			my $res = $sth->fetchrow_arrayref;
			if ($res->[0] == 1) {
				$errors->{'DUP_'.$self->{'PKEY'}} = 1;
			}
			$sth->finish;
		}

		# check each unique column constraint
		foreach (@{$self->{'UNIQUE'}}) {
			my $sth = $conn->prepare("select 1 from $self->{'TABLE'} WHERE $_ = ?") || $self->db_error();
			$sth->execute($values->{$_}) || $self->db_error();
			my $res = $sth->fetchrow_arrayref;
			if ($res->[0] == 1) {
				$errors->{"DUP_$_"} = 1;
			}
			$sth->finish;
		}

		if (scalar keys %{$errors}) {
			$errors->{'HAS_ERRORS'} = 1;

			# copy values back into form
			foreach (keys(%{$values})) { 
				$errors->{$_} = $values->{$_};
			}
		}
		else {
			# copy clean dates,times into parameters for insertion
			foreach (@{$self->{'DATES'}},@{$self->{'TIMES'}}) {
				$values->{$_->{'name'}} = $values->{$_->{'name'}."_CLEAN"};
			}

			my $insert_statement = "INSERT INTO $self->{'TABLE'} (".join(",",@{$self->{'PARAM_LIST'}}).") VALUES (".join(",",map {"?"} @{$self->{'PARAM_LIST'}}).")";

			$self->debug($insert_statement);

			my $sth =  $conn->prepare($insert_statement) || $self->db_error();

			$sth->execute(map { $values->{$_} } @{$self->{'PARAM_LIST'}}) || $self->db_error();

			$sth->finish();

			return 1;
		}
	}

	# populate drop downs (also maintaining previous state).
	foreach (@{$self->{'SELECTIONS'}}) {
		my $query = "SELECT
		                 $_->{'key'},
		                 $_->{'label'}
		             FROM 
		                $_->{'refs'}
		                $_->{'extra'}";

		my $res = $conn->selectall_arrayref($query) || $self->db_error();

		$errors->{$_->{'name'}} = $self->select_prep(['id','name'],
		                                             $res,
		                                             ["id",$errors->{$_->{'name'}} || $_->{'default'}]);
	}

	# If we get here the user is just loading the page 
	# for the first time or had errors.
	return $errors;
}

#
# performs a delete from a table
#
sub delete {
	my $self = shift;
	my $p    = shift;

	# additional constraint to the where clause.
	my $additional_constraint = shift;

	my $conn      = $p->{'dbconn'};
	my $params    = $p->{'parameters'};

	unless ($params->{$self->{'PKEY'}} =~ /$self->{'PKEY_REGEXP'}/) {
		return $self->display_error("Invalid ID", "/index");
	}

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	# record exists?
	my $res = $conn->selectall_arrayref("SELECT 1 
	                                     FROM
	                                            $self->{'TABLE'}
	                                     WHERE
	                                            $self->{'PKEY'} = '$params->{$self->{'PKEY'}}'
												$additional_constraint
	                                     ") || $self->db_error();

	unless (defined($res->[0]->[0])) {
		return $self->display_error("No Record found with that ID", "index");
	}
		
	if ($params->{'confirm'} eq "Yes") {
		# fry it
		$conn->do("delete from $self->{'TABLE'} where $self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint") || $self->db_error();
		return 1;
	}
	elsif ($params->{'confirm'} eq "No") {
		# don't fry it
		return 1;
	}
	else {
		# ask if they want to fry it.
		return { $self->{'PKEY'} => $params->{$self->{'PKEY'}} };
	}
}

#
# sets the 'active' field to 0
#
sub disable {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift;

	my $params = $p->{'parameters'};
	my $conn   = $p->{'dbconn'};

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	unless ($params->{$self->{'PKEY'}} =~ /$self->{'PKEY_REGEXP'}/) {
		return $self->display_error("Invalid ID", "index");
	}

	$conn->do("update $self->{'TABLE'} set active=0 where $self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint") || $self->db_error();

	return 1;
}

#
# sets the 'active' field to 1
#
sub enable {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift;

	my $params = $p->{'parameters'};
	my $conn   = $p->{'dbconn'};

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	unless ($params->{$self->{'PKEY'}} =~ /$self->{'PKEY_REGEXP'}/) {
		return $self->display_error("Invalid ID", "index");
	}

	$conn->do("update $self->{'TABLE'} set active=1 where $self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint") || $self->db_error();

	return 1;
}

#
# performs a database update
#
sub edit {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift;

	my $conn      = $p->{'dbconn'};
	my $session   = $p->{'session'};
	my $params    = $p->{'parameters'};

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	unless ($params->{$self->{'PKEY'}} =~ /$self->{'PKEY_REGEXP'}/) {
		return $self->display_error("Invalid ID", "index");
	}

	# insure that the record exists
	my $res = $conn->selectall_arrayref("SELECT 1 from $self->{'TABLE'} WHERE $self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint") || $self->db_error();
	unless ($res->[0]->[0] == 1) {
		return $self->display_error("No record with that ID found", "index");
	}

	my $errors = {};
	if ($params->{'cm'} eq "update") {
		my $values;

		# call each of the insert_callbacks
		foreach (@{$self->{'update_callbacks'}}) {
			# call back should return a list of error strings
			foreach (&{$_}($conn,$params)) {
				if (length($_)) {
					$errors->{$_} = 1;
				}
			}
		}

		my $e;
		# run the standard error checks
		($values,$e) = $self->_process_params($params);

		# copy the errors from the process_params
		$errors = { %{$errors}, %{$e} };

		# check all the unique columns
		foreach (@{$self->{'UNIQUE'}}) {
			my $sth = $conn->prepare("select 1 from $self->{'TABLE'} WHERE $_ = ? AND $self->{'PKEY'} != '$params->{$self->{'PKEY'}}'") || $self->db_error();
			$sth->execute($values->{$_}) || $self->db_error();
			my $res = $sth->fetchrow_arrayref;
			if ($res->[0] == 1) {
				$errors->{"DUP_$_"} = 1;
			}
			$sth->finish;
		}

		if (scalar keys %{$errors}) {
			$errors->{'HAS_ERRORS'} = 1;

			# copy values into template
			$errors->{$self->{'PKEY'}} = $params->{$self->{'PKEY'}};
			foreach (keys(%{$values})) { 
				$errors->{$_} = $values->{$_};
			}
		}
		else {
			# copy clean dates,times into parameters for insertion
			foreach (@{$self->{'DATES'}},@{$self->{'TIMES'}}) {
				$values->{$_->{'name'}} = $values->{$_->{'name'}."_CLEAN"};
			}

			my $update_statement = "UPDATE $self->{'TABLE'} SET ".
			                        join("=?,",@{$self->{'PARAM_LIST'}}).
									"=? WHERE $self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint";

			$self->debug($update_statement);

			my $sth =  $conn->prepare($update_statement) || $self->db_error();

			$sth->execute(map { $values->{$_} } @{$self->{'PARAM_LIST'}}) || $self->db_error();

			$sth->finish();

			return 1;
		}
	}
	else {
		# find the record to be updated
		my $select_statement = "SELECT ".
		                       join(",",@{$self->{'PARAM_LIST'}}).
							   " FROM $self->{'TABLE'} 
							   WHERE $self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint";

		$self->debug($select_statement);

		my $res = $conn->selectall_arrayref($select_statement) || $self->db_error();

		if (defined($res) && defined($res->[0]->[0])) {
			# copy values into template
			$errors->{$self->{'PKEY'}} = $params->{$self->{'PKEY'}};
			
			for (my $i=0; $i <= $#{$self->{'PARAM_LIST'}}; $i++) {
				$errors->{$self->{'PARAM_LIST'}->[$i]} = $res->[0]->[$i];
			}
		}

		# pretty up dates
		foreach (@{$self->{'DATES'}}) {
			$errors->{$_->{'name'}} = $self->sql_to_date($errors->{$_->{'name'}});
		}

		# pretty up times
		foreach (@{$self->{'TIMES'}}) {
			$errors->{$_->{'name'}} = $self->sql_to_time($errors->{$_->{'name'}});
		}
	}

	# populate drop downs (also maintaining previous state).
	foreach (@{$self->{'SELECTIONS'}}) {
		my $query = "SELECT
						$_->{'key'},
						$_->{'label'}
					FROM 
						$_->{'refs'}
						$_->{'extra'}";

		my $res = $conn->selectall_arrayref($query) || $self->db_error();

		$errors->{$_->{'name'}} = $self->select_prep(['id','name'],
		                                             $res,
		                                             ["id",$errors->{$_->{'name'}} || $_->{'default'}]);
	}

	# If we get here the user is just loading the page 
	# for the first time or had errors.
	return $errors;
}

#
# performs a database select
#
sub view {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift;

	my $conn      = $p->{'dbconn'};
	my $params    = $p->{'parameters'};

	unless ($params->{$self->{'PKEY'}} =~ /$self->{'PKEY_REGEXP'}/) {
		return $self->display_error("Invalid ID", "index");
	}

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	# figure out tables to join against
	my @list;
	my @joins;
	foreach(@{$self->{'PARAM_LIST'}}) {
		my $column = $_;
		my $is_join = 0;
		foreach (@{$self->{'SELECTIONS'}}) {
			if ($_->{'name'} eq $column) {
				push(@joins,"LEFT JOIN $_->{'refs'} ON $self->{'TABLE'}.$column = $_->{'refs'}.$_->{'key'}");
				push(@list,"$_->{'refs'}.$_->{'label'}");
				$is_join = 1;
				last;
			}
		}
		unless($is_join) {
			push(@list,"$self->{'TABLE'}.$column");
		}
	}

	my $select_statement = "SELECT " .
	                        join(",\n",@list).
							" FROM $self->{'TABLE'} ".
	                        join("\n",@joins).
							" WHERE $self->{'TABLE'}.$self->{'PKEY'} = '$params->{$self->{'PKEY'}}' $additional_constraint";

	$self->debug($select_statement);
	my $res = $conn->selectall_arrayref($select_statement) || $self->db_error();

	my %v;
	if (defined($res) && defined($res->[0]->[0])) {
		# copy values into template
		$v{$self->{'PKEY'}} = $params->{$self->{'PKEY'}};
		
		for (my $i=0; $i <= @list; $i++) {
			my $key = $list[$i];

			$key =~ s/$self->{'TABLE'}\.//;    # take of the table name in front
			$key =~ s/\..*//;               # remove everything after the dot
			# we either end up with the column name from the primay table, or the name of the joined table

			$v{$key} = $res->[0]->[$i];
		}
	}
	else {
		return $self->display_error("Record not found", "/index");
	}

	# pretty up dates
	foreach (@{$self->{'DATES'}}) {
		$v{$_->{'name'}} = $self->sql_to_date($v{$_->{'name'}});
	}

	# pretty up times
	foreach (@{$self->{'TIMES'}}) {
		$v{$_->{'name'}} = $self->sql_to_time($v{$_->{'name'}});
	}

	return \%v;
}

#
# standard data checks for add and edit
#
sub _process_params {
	my $self   = shift;
	my $params = shift;

	my %v;
	my %errors;

	##############
	# copy params out
	##############
	foreach (@{$self->{'PARAM_LIST'}}) {
		$params->{$_} =~ s/^\s*//go;
		$params->{$_} =~ s/\s*$//go;

		$v{$_} = $params->{$_};
	}

	##############
	# check required
	##############
	foreach (@{$self->{'REQUIRED_LIST'}}) {
		if ($v{$_} eq "") {
			$errors{'MISSING_'.$_} = 1;
		}
	}

	##############
	# varchar
	##############
	foreach(@{$self->{'VARCHARS'}}) {
		if ($_->{'length'} > 0 && length($v{$_->{'name'}}) > $_->{'length'}) {
			$errors{'BIG_'.$_->{'name'}} = 1;
		}
		elsif (defined($_->{'valid'})) {
			if ($_->{'valid'} eq "email" && length($v{$_->{'name'}}) > 0) {
				my $c = $_;
				my $addr;

				eval {
					$addr = Email::Valid->address('-address' => $v{$c->{'name'}},
					                              '-mxcheck' => 1, 
											      '-fqdn'    => 1 );
				};
				if ($@) {
					warn "Email::Valid produced and exception: $@";
					$errors{'BAD_'.$c->{'name'}} = 1;
				}
				elsif(!defined($addr)) {
					$errors{'BAD_'.$c->{'name'}} = 1;
				}
				else {
					$v{$c->{'name'}} = $addr;
				}
			}
			elsif($_->{'valid'} eq "url") {
				if (length($v{$_->{'name'}}) && Voodoo::Valid_URL::valid_url($v{$_->{'name'}}) == 0) {
					$errors{'BAD_'.$_->{'name'}} = 1;
				}
			}
		}
		elsif(defined($_->{'regexp'})) {
			 my $re = $_->{'regexp'};
			 unless ($v{$_->{'name'}} =~ /$re/) {
				 $errors{'BAD_'.$_->{'name'}} = 1;
			 }
		}
	}

	##############
	# + decimal
	##############
	foreach (@{$self->{'UNSIGNED_DECIMALS'}}) {
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
	foreach (@{$self->{'SIGNED_DECIMALS'}}) {
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
	foreach (@{$self->{'UNSIGNED_INTEGERS'}}) {
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
	foreach (@{$self->{'SIGNED_INTEGERS'}}) {
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
	foreach (@{$self->{'DATES'}}) {
		if ($v{$_->{'name'}} eq "") {
			$v{$_->{'name'}."_CLEAN"} = undef;
		}
		else {
			my $temp = $self->date_to_sql($v{$_->{'name'}});
			if ($temp) {
				$v{$_->{'name'}."_CLEAN"} = $temp;
			}
			else {
				$errors{"BAD_".$_->{'name'}} = 1;
			}
		}
	}

	##############
	# Times
	##############
	foreach (@{$self->{'TIMES'}}) {
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

sub list {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift;

	my $conn      = $p->{'dbconn'};
	my $params    = $p->{'parameters'};

	my $pattern = $params->{'pattern'};
	my $limit   = $params->{'limit'};

	# if the sort order wasn't given, and we have a limit column use it. otherwise default to the first param:
	my $sort      = $params->{'sort'}       || $limit || $self->{'LIST_COLS'}->[0];
	my $last_sort = $params->{'last_sort'}  || $limit || $self->{'LIST_COLS'}->[0];
	my $desc      = $params->{'desc'};
	
	my $count   = $params->{'count'}   || "20";
	my $page    = $params->{'page'}    || 1;
	my $showall = $params->{'showall'} || 0;

	# figure out tables to join against
	my @list = $self->{'TABLE'}.".".$self->{'PKEY'};
	my @joins;
	foreach(@{$self->{'LIST_COLS'}}) {
		my $column = $_;
		my $is_join = 0;
		foreach (@{$self->{'SELECTIONS'}},@{$self->{'LEFT_JOINS'}}) {
			if ($_->{'name'} eq $column) {
				push(@joins,"LEFT JOIN $_->{'refs'} ON $self->{'TABLE'}.$column = $_->{'refs'}.$_->{'key'}");
				push(@list,"$_->{'refs'}.$_->{'label'}");
				$is_join = 1;
				last;
			}
		}
		unless($is_join) {
			push(@list,"$self->{'TABLE'}.$column");
		}
	}

	my $select_stmt = "SELECT " .
	                   join(",\n",@list).
	                   " FROM $self->{'TABLE'} ".
	                   join("\n",@joins) ;

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (defined($self->{'SEARCH_COLS'}->{$limit}) && $pattern =~ /^[\w -]+$/) {
		# we need to narrow the set
		# 7-18-2001 added lower to make case insensitive for Postgres
		$select_stmt .= " WHERE lower(". $self->{'SEARCH_COLS'}->{$limit} .") like lower('$pattern%') ";

		if (length($additional_constraint)) {
			$select_stmt .= "AND $additional_constraint";
		}
	}
	elsif (length($additional_constraint)) {
		$select_stmt .= " WHERE $additional_constraint";
	}

	my $n_desc = $desc;
	if (defined($self->{'SORT_COLS'}->{$sort})) {
		my $q = $self->{'SORT_COLS'}->{$sort};

		# if we're sorting on the same key as before, then we have the chance to go descending
		if ($sort eq $last_sort) { 
			if ($desc == 1) {
				$q =~ s/,/ DESC, /g;
				$q .= " DESC";
				$n_desc = 0; # say that we are ascending the next time.
			}
			else {
				$n_desc = 1; # say that we are descending the next time.
			}
		}
		else {
			$n_desc = 1; # we just sorted ascending, so now we need to say to sort descending
			$desc = 0;
		}

		$select_stmt .= " ORDER BY $q";
	}

	$self->debug($select_stmt);
	my $res = $conn->selectall_arrayref($select_stmt) || $self->db_error();
	$self->debug($#{$res});

	my %output;
	################################################################################
	# prep all the template vars to go back on the form (pagination, sorting, searching)
	################################################################################
	$output{'MODE_PARAMS'} = $self->mkurlparams({'limit' => $limit,
	                                      'pattern' => $pattern,
	                                      'sort' => $sort,
	                                      'desc' => $desc,
	                                      'last_sort' => $sort});

	$output{'SORT_PARAMS'} = $self->mkurlparams({'limit' => $limit,
	                                      'pattern' => $pattern,
	                                      'showall' => $showall,
	                                      'desc' => $n_desc,
	                                      'last_sort' => $sort});


	my $search_xref = [ map { my $n = $_ ;
	                          $n =~ s/_/ /g;
	                          $n =~ s/\b(.)/\U$1\E/g;
							  [$_, $n]
	                        } sort keys %{$self->{'SEARCH_COLS'}} ];

	$output{'LIMIT'}   = $self->select_prep(['id','name'],$search_xref,['id',$limit]),
	$output{'PATTERN'} = $pattern;

	my $res_count = $#{$res} + 1;

	$output{'NUM_MATCHES'} = $res_count;

	my @page_set;
	if ($res_count > $count) {
		$output{'HAS_MORE'} = 1;

		if ($showall) {
			@page_set = @{$res};

			$output{'SHOW_MODE'} = 1;
			$output{'MODE_PARAMS'} .= "&showall=0";
		}
		else {
			$output{'MODE_PARAMS'} .= "&showall=1";

			# if there are more results than this page will fit cut the results
			if (($res_count - (($page - 1) * $count)) > $count) {
				@page_set = @{$res}[(($page - 1) * $count) ... (($page * $count) - 1)];
			}
			else {
				@page_set= @{$res}[(($page - 1) * $count) ... ($res_count-1)];
			}

			# setup the page list
			my $numpages = ($res_count / $count);

			if ($numpages > 1) {
				# setup sliding window of page numbers
				my $start = 0;
				my $window = 10;
				my $end   = $window;
				if ($page >= $window) {
					$start = $page - ($window / 2) - 1;
					$end   = $page + ($window / 2);
				}

				if ($end > $numpages) {
					$end = $numpages;
				}

				$output{'PAGES'} = [];
				for (my $x = $start; $x < $end; $x++) {
					# Put the page info into the array
					push(@{$output{'PAGES'}}, {'NOT_ME'     => (($x + 1) == $page)?0:1,
	                                           'PAGE'       => ($x + 1),
					                           'NOT_LAST'   => 1,
					                           'URL_PARAMS' => $self->mkurlparams({'limit' => $limit,
					                                                        'pattern' => $pattern,
					                                                        'count' => $count,
					                                                        'sort' => $sort,
					                                                        'last_sort' => $sort,
					                                                        'desc' => $desc,
					                                                        'page' => ($x + 1)
					                                                       })
					                          });
				}

				# prevent access of index -1 if the page number requested is beyond the range.
				if ($#{$output{'PAGES'}} >= 0) {
					# set the last page to last
					$output{'PAGES'}->[$#{$output{'PAGES'}}]->{'NOT_LAST'} = 0;
				}

				# setup the 'more link'
				if ($end != $numpages) {
					$output{'MORE_URL_PARAMS'} = $self->mkurlparams({'limit' => $limit,
					                                          'pattern' => $pattern,
					                                          'count' => $count,
					                                          'sort' => $sort,
					                                          'last_sort' => $sort,
					                                          'desc' => $desc,
					                                          'page' => ($end + 1)
					                                          });
				}

				# setup the preivous link
				if ($page > 1) {
					$output{'HAS_PREVIOUS'} = 1;
					$output{'PREVIOUS_URL_PARAMS'} = $self->mkurlparams({'limit' => $limit,
					                                              'pattern' => $pattern,
															      'count' => $count,
															      'sort' => $sort,
					                                              'last_sort' => $sort,
															      'desc' => $desc,
															      'page' => ($page - 1)
															     });
			}

				# setup the next link
				if ($page * $count < $res_count) {
					$output{'HAS_NEXT'} = 1;
					$output{'NEXT_URL_PARAMS'} = $self->mkurlparams({'limit' => $limit,
					                                          'pattern' => $pattern,
															  'count' => $count,
															  'sort' => $sort,
					                                          'last_sort' => $sort,
															  'desc' => $desc,
															  'page' => ($page + 1)
															  });
				}
			}
		}
	}
	else {
		@page_set = @{$res};
	}


	################################################################################
	# prep data for the template
	################################################################################
	my %dates;
	foreach (@{$self->{'DATES'}}) {
		$dates{$_->{'name'}} = 1;
	}

	my %times;
	foreach (@{$self->{'TIMES'}}) {
		$times{$_->{'name'}} = 1;
	}

	foreach (@page_set) {
		my %v;
		for (my $i=0; $i <= @list; $i++) {
			my $key = $list[$i];

			$key =~ s/$self->{'TABLE'}\.//; # take of the table name in front
			$key =~ s/\..*//;               # remove everything after the dot
			# we either end up with the column name from the primay table, or the name of the joined table

			$v{$key} = $_->[$i];

			if (defined($dates{$key})) {
				$v{$key} = $self->sql_to_date($v{$key});
			}
			elsif (defined($times{$key})) {
				$v{$key} = $self->sql_to_time($v{$key});
			}
		}

		$v{'ALL_URL_PARAMS'} = $self->mkurlparams({'limit' => $limit,
		                                    'pattern' => $pattern,
		                                    'count' => $count,
		                                    'sort' => $sort,
		                                    'showall' => $showall,
		                                    'last_sort' => $sort,
		                                    'desc' => $desc,
		                                    'page' => $page
		                                   });

		push(@{$output{'DATA'}},\%v);
	}

	return \%output;
}

1;
