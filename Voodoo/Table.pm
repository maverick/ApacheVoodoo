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
package Apache::Voodoo::Table;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo");
use Data::Dumper;

use Apache::Voodoo::Validate;
use Apache::Voodoo::Pager;

sub new {
	my $class = shift;
	my $self = {};

	bless $self, $class;


	$self->set_configuration(shift);

	return $self;
}

sub set_configuration {
	my $self = shift;
	my $conf = shift;

	my @errors;

	if (!defined($conf->{'table'})) {
		push(@errors,"missing table name");
	}
	elsif ($conf->{'table'} !~ /^[a-z_]\w*$/) {
		push(@errors,"bad table name");
	}
	else {
		$self->{'table'} = $conf->{'table'};
	}

	if (!defined($conf->{'primary_key'})) {
		push(@errors,"missing primary key");
	}
	elsif ($conf->{'primary_key'} !~ /^[a-z_]\w*$/) {
		push(@errors,"bad primary key");
	}
	else {
		$self->{'pkey'} = $conf->{'primary_key'};
	}

	$self->{'pkey_regexp'} = ($conf->{'primary_key_regexp'})?$conf->{'primary_key_regexp'}:'^\d+$';
	$self->{'pkey_user_supplied'} = ($conf->{'primary_key_user_supplied'})?1:0;
	eval {
		$self->{valid} = Apache::Voodoo::Validate->new($conf->{'columns'});
	};
	if (my $e = Apache::Voodoo::Exception::RunTime::BadConfig->caught()) {
		# FIXME hack!  need to figure out to store the list of errors as a data structure and override the stringification operation.
		my (undef,@e) = split(/\n\t/,"$e");
		push(@errors,@e);
	}
	elsif ($@) {
		ref($@)?
			$@->rethrow:
			Apache::Voodoo::Exception::RunTime->throw($@);
	}

	while (my ($name,$conf) = each %{$conf->{'columns'}}) {
		if (defined($conf->{'multiple'})) {
			push(@errors,"Column $name allows multiple values but Apache::Voodoo::Table can't handle that currently.");
		}

		if (defined($conf->{'unique'})) {
			push(@{$self->{'unique'}},$name);
		}

		# keep a local list of column names for query construction.
		if (defined($self->{'pkey'}) && $name ne $self->{'pkey'}) {
			push(@{$self->{'columns'}},$name);
		}

		if ($conf->{'type'} eq "date") { push(@{$self->{dates}},$name); }
		if ($conf->{'type'} eq "time") { push(@{$self->{times}},$name); }

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
	}

	$self->{'default_sort'} = $conf->{'list_options'}->{'default_sort'};
	while (my ($k,$v) = each %{$conf->{'list_options'}->{'sort'}}) {
		$self->{'list_sort'}->{$k} = (ref($v) eq "ARRAY")? join(", ",@{$v}) : $v;
	}

	foreach (@{$conf->{'list_options'}->{'search'}}) {
		push(@{$self->{'list_search_items'}},[$_->[1],$_->[0]]);
		$self->{'list_search'}->{$_->[1]} = 1;
	}

	if (ref($conf->{'joins'}) eq "ARRAY") {
		foreach (@{$conf->{'joins'}}) {
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

	$self->{'pager'} = Apache::Voodoo::Pager->new();
	# setup the pagination options
	$self->{'pager'}->set_configuration(
		'count'   => 40,
		'window'  => 10,
		'persist' => [ 
			'pattern',
			'limit',
			'sort',
			'last_sort',
			'desc',
			@{$conf->{'list_options'}->{'persist'} || []}
		]
	);

	if (@errors) {
		Apache::Voodoo::Exception::RunTime::BadConfig->throw("Configuration Errors:\n\t".join("\n\t",@errors));
	}
}

sub success {
	my $self = shift;

	return $self->{'success'};
}

sub edit_details {
	my $self = shift;

	# if there wasn't a successful edit, then there's no details :)
	return unless $self->{'success'};

	return $self->{'edit_details'} || [];
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

sub add {
	my $self = shift;
	my $p = shift;

	my $dbh    = $p->{'dbh'};
	my $params = $p->{'params'};

	my $errors = {};

	$self->{'success'} = 0;

	if ($params->{'cm'} eq "add") {
		# we're going to attempt the addition
		my $values;

		# call each of the insert_callbacks
		foreach (@{$self->{'insert_callbacks'}}) {
			my $callback_errors = $_->($dbh,$params);
			@{$errors}{keys %{$callback_errors}} = values %{$callback_errors};
		}

		my $e;

		# do all the normal parameter checking
		($values,$e) = $self->{valid}->validate($params);

		if (defined($e)) {
			# copy the errors from the process_params
			$errors = { %{$errors}, %{$e} };
		}

		# check to see if the user supplied primary key (optional) is unique
		if ($self->{'pkey_user_supplied'}) {
			if ($params->{$self->{'pkey'}} =~ /$self->{'pkey_regexp'}/) {
				my $res = $dbh->selectall_arrayref("
					SELECT 
						1 
					FROM 
						$self->{'table'} 
					WHERE 
						$self->{'pkey'} = ?",
					undef,
					$params->{$self->{'pkey'}} ) || $self->db_error();

				if ($res->[0]->[0] == 1) {
					$errors->{'DUP_'.$self->{'pkey'}} = 1;
				}
			}
			else {
				$errors->{'BAD_'.$self->{'pkey'}} = 1;
			}
		}

		# check each unique column constraint
		foreach (@{$self->{'unique'}}) {
			my $res = $dbh->selectall_arrayref("
				SELECT 
					1 
				FROM 
					$self->{'table'}
				WHERE 
					$_ = ?",
				undef,
				$values->{$_}) || $self->db_error();
			if ($res->[0]->[0] == 1) {
				$errors->{"DUP_$_"} = 1;
			}
		}

		if (scalar keys %{$errors}) {
			$errors->{'HAS_ERRORS'} = 1;

			# copy values back into form
			foreach (keys(%{$values})) { 
				$errors->{$_} = $values->{$_};
			}
		}
		else {
			# copy clean dates,times into params for insertion
			foreach (@{$self->{'dates'}},@{$self->{'times'}}) {
				$values->{$_->{'name'}} = $values->{$_->{'name'}."_CLEAN"};
			}

			my $c = join(",",          @{$self->{'columns'}});		# the column names
			my $q = join(",",map {"?"} @{$self->{'columns'}});		# the ? mark placeholders

			my @v = map { $values->{$_} } @{$self->{'columns'}};	# and the values

			if ($self->{'pkey_user_supplied'}) {
				$c .= ",".$self->{'pkey'};
				$q .= ",?";

				push(@v,$params->{$self->{'pkey'}});
			}


			my $insert_statement = "INSERT INTO $self->{'table'} ($c) VALUES ($q)";

			$dbh->do($insert_statement,
			          undef,
					 @v
			         ) || $self->db_error();

			$self->{'success'} = 1;
			return 1;
		}
	}

	# populate drop downs (also maintaining previous state).
	foreach (@{$self->{'references'}}) {
		my $query = "SELECT
		                 $_->{'pkey'},
		                 $_->{'slabel'}
		             FROM 
		                $_->{'table'}
		                $_->{'sextra'}";

		my $res = $dbh->selectall_arrayref($query) || $self->db_error();

		$errors->{$_->{'fkey'}} = $self->prep_select($res,$errors->{$_->{'fkey'}} || $_->{'sdefault'});
	}

	# If we get here the user is just loading the page 
	# for the first time or had errors.
	return $errors;
}

sub edit {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift;

	$self->{'success'} = 0;
	$self->{'edit_details'} = [];

	my $dbh       = $p->{'dbh'};
	my $session   = $p->{'session'};
	my $params    = $p->{'params'};

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	unless ($params->{$self->{'pkey'}} =~ /$self->{'pkey_regexp'}/) {
		return $self->display_error("Invalid ID");
	}

	# find the record to be updated
	my $res = $dbh->selectall_arrayref("
		SELECT ".
			join(",",@{$self->{'columns'}}). "
		FROM 
			$self->{'table'} 
		WHERE 
			$self->{'pkey'} = ? 
			$additional_constraint",
		undef,
		$params->{$self->{'pkey'}}) || $self->db_error();

	unless (defined($res->[0])) {
		return $self->display_error("No record with that ID found");
	}

	my %original_values;
	for (my $i=0; $i <= $#{$self->{'columns'}}; $i++) {
		$original_values{$self->{'columns'}->[$i]} = $res->[0]->[$i];
	}

	my $errors = {};
	if ($params->{'cm'} eq "update") {
		my $values;

		# call each of the insert_callbacks
		foreach (@{$self->{'update_callbacks'}}) {
			# call back should return a list of error strings
			my $callback_errors = $_->($dbh,$params);
			@{$errors}{keys %{$callback_errors}} = values %{$callback_errors};
		}

		my $e;
		# run the standard error checks
		($values,$e) = $self->{valid}->validate($params);

		# copy the errors from the process_params
		$errors = { %{$errors}, %{$e} };

		# check all the unique columns
		foreach (@{$self->{'unique'}}) {
			my $res = $dbh->selectall_arrayref("
				SELECT 
					1
				FROM 
					$self->{'table'}
				WHERE 
					$_ = ? AND 
					$self->{'pkey'} != ?",
				undef,
				$values->{$_},
				$params->{$self->{'pkey'}}) || $self->db_error();
			if ($res->[0]->[0] == 1) {
				$errors->{"DUP_$_"} = 1;
			}
		}

		if (scalar keys %{$errors}) {
			$errors->{'has_errors'} = 1;

			# copy values into template
			$errors->{$self->{'pkey'}} = $params->{$self->{'pkey'}};
			foreach (keys(%{$values})) { 
				$errors->{$_} = $values->{$_};
			}
		}
		else {
			# copy clean dates,times into params for insertion
			foreach (@{$self->{'dates'}},@{$self->{'times'}}) {
				$values->{$_->{'name'}} = $values->{$_->{'name'}."_CLEAN"};
			}

			# let's figure out what they changed so caller can do something with that info if they want
			foreach (@{$self->{'columns'}}) {
				if ($values->{$_} ne $original_values{$_}) {
					push(@{$self->{'edit_details'}},[$_,$original_values{$_},$values->{$_}]);
				}
			}
			my $update_statement = "
				UPDATE 
					$self->{'table'} 
				SET ".
					join("=?,",@{$self->{'columns'}})."=?
				WHERE 
					$self->{'pkey'} = ?
				$additional_constraint";

			# $self->debug($update_statement);
			# $self->debug((map {$values->{$_}} @{$self->{'columns'}}),$params->{$self->{'pkey'}});

			$dbh->do($update_statement,
			          undef,
			          (map { $values->{$_} } @{$self->{'columns'}}),
			          $params->{$self->{'pkey'}}) || $self->db_error();

			$self->{'success'} = 1;
			return 1;
		}
	}
	else {
		foreach (@{$self->{'columns'}}) {
			$errors->{$_} = $original_values{$_};
		}

		$errors->{$self->{'pkey'}} = $params->{$self->{'pkey'}};
			
		# pretty up dates
		foreach (@{$self->{'dates'}}) {
			$errors->{$_->{'name'}} = $self->sql_to_date($errors->{$_->{'name'}});
		}

		# pretty up times
		foreach (@{$self->{'times'}}) {
			$errors->{$_->{'name'}} = $self->sql_to_time($errors->{$_->{'name'}});
		}
	}

	# populate drop downs (also maintaining previous state).
	foreach (@{$self->{'references'}}) {
		my $query = "SELECT
						$_->{'pkey'},
						$_->{'slabel'}
		             FROM 
						$_->{'table'}
						$_->{'sextra'}";

		my $res = $dbh->selectall_arrayref($query) || $self->db_error();

		$errors->{$_->{'fkey'}} = $self->prep_select($res,$errors->{$_->{'fkey'}} || $_->{'sdefault'});
	}

	# If we get here the user is just loading the page 
	# for the first time or had errors.
	return $errors;
}

sub delete {
	my $self = shift;
	my $p    = shift;

	$self->{'success'} = 0;

	# additional constraint to the where clause.
	my $additional_constraint = shift;

	my $dbh      = $p->{'dbh'};
	my $params    = $p->{'params'};

	unless ($params->{$self->{'pkey'}} =~ /$self->{'pkey_regexp'}/) {
		return $self->display_error("Invalid ID");
	}

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	# record exists?
	my $res = $dbh->selectall_arrayref("
		SELECT
			1 
		FROM
			$self->{'table'}
		WHERE
			$self->{'pkey'} = ?
		$additional_constraint",
		undef,
		$params->{$self->{'pkey'}}) || $self->db_error();

	unless ($res->[0]->[0] == 1) {
		return $self->display_error("No Record found with that ID");
	}
		
	if ($params->{'confirm'} eq "Yes") {
		# fry it
		$dbh->do("
			DELETE FROM 
				$self->{'table'}
			WHERE 
				$self->{'pkey'} = ?
			$additional_constraint",
			undef,
			$params->{$self->{'pkey'}}) || $self->db_error();

		$self->{'success'} = 2;

		return 1;
	}
	elsif ($params->{'confirm'} eq "No") {
		# don't fry it

		$self->{'success'} = 1;

		return 1;
	}
	else {
		# ask if they want to fry it.
		return { $self->{'pkey'} => $params->{$self->{'pkey'}} };
	}
}

sub list {
	my $self                  = shift;
	my $p                     = shift;
	my $additional_constraint = shift;

	$self->{'success'} = 0;

	my $dbh    = $p->{'dbh'};
	my $params = $p->{'params'};

	$params->{'sort'}      =~ s/[^\w-]//g;
	$params->{'last_sort'} =~ s/[^\w-]//g;

	$params->{'count'}   =~ s/\D//g;
	$params->{'page'}    =~ s/\D//g;
	$params->{'desc'}    =~ s/\D//g;
	$params->{'showall'} =~ s/\D//g;

	my $pattern = $params->{'pattern'};
	my $limit   = $params->{'limit'};

	my $sort      = $params->{'sort'}      || $self->{'default_sort'};
	my $last_sort = $params->{'last_sort'} || $self->{'default_sort'};
	my $desc      = $params->{'desc'};
	
	my $count   = $params->{'count'}   || $self->{'pager'}->{'count'};
	my $page    = $params->{'page'}    || 1;
	my $showall = $params->{'showall'} || 0;

	# figure out tables to join against
	my @list;
	foreach ($self->{'pkey'}, @{$self->{'columns'}}) {
		if ($_ =~ /\./) {
			push(@list,$_);
		}
		else {
			push(@list,"$self->{'table'}.$_");
		}
	}

	if (ref($additional_constraint)) {
		if (defined($additional_constraint->{'additional_column'})) {
			push(@list, $additional_constraint->{'additional_column'});
		}
	}

	# figure out tables to join against
	my @joins;
	if ($self->{references}) {
		foreach my $join ( sort { ($a->{fkey} =~ /\./) <=> ($b->{fkey} =~ /\./) } @{$self->{'references'}}) {
			if ($join->{fkey} =~ /\./) {
				push(@joins,"LEFT JOIN $join->{'table'} ON $join->{'fkey'} = $join->{'table'}.$join->{'pkey'}");
			}
			else {
				push(@joins,"LEFT JOIN $join->{'table'} ON $self->{'table'}.$join->{'fkey'} = $join->{'table'}.$join->{'pkey'}");
			}

			foreach (@{$join->{'columns'}}) {
				push(@list,"$join->{'table'}.$_");
			}
		}
	}

	if ($self->{joins}) {
		foreach my $join (@{$self->{joins}}) {
			my $fkey;
			if ($join->{fkey} =~ /\./) {
				$fkey = $join->{fkey};
			}
			else {
				$fkey = $self->{table}.'.'.$join->{fkey};
			}

			push(@joins,"LEFT JOIN $join->{'table'} ON $fkey = $join->{'table'}.$join->{'pkey'}");

			foreach (@{$join->{columns}}) {
				if ($_ =~ /\./) {
					push(@list,$_);
				}
				else {
					push(@list,$join->{'table'}.".$_");
				}
			}
		}
	}

	my $select_stmt = "
		SELECT SQL_CALC_FOUND_ROWS " .
			join(",\n",@list). "
		FROM 
			$self->{'table'} ".
		join("\n",@joins);

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (defined($self->{'list_search'}->{$limit}) && $self->safe_text($pattern)) {
		# we need to narrow the set
		# 7-18-2001 added lower to make case insensitive for Postgres
		$select_stmt .= " WHERE $limit LIKE LOWER(\"$pattern%\") ";

		# FIXME!!!
		if (ref($additional_constraint)) {
			if(defined($additional_constraint->{'additional_constraint'})) {
				$select_stmt .= "AND ".$additional_constraint->{'additional_constraint'};
			}
		} elsif (length($additional_constraint)) {
			$select_stmt .= "AND $additional_constraint";
		}
	} elsif(ref($additional_constraint)) {
		if(defined($additional_constraint->{'additional_constraint'})) {
			$select_stmt .= " WHERE ".$additional_constraint->{'additional_constraint'};
		}

		# these aren't valid, fry em
		$pattern = undef;
		$limit   = undef;

	} elsif (length($additional_constraint)) {
		$select_stmt .= " WHERE $additional_constraint";

		# these aren't valid, fry em
		$pattern = undef;
		$limit   = undef;
	}

	my $n_desc = $desc;
	if (defined($self->{'list_sort'}->{$sort}) && defined($self->{'list_sort'}->{$last_sort})) {
		my $q = $self->{'list_sort'}->{$sort};

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
	else {
		# bogus, fry it.
		$sort      = undef;
		$last_sort = undef;
	}

	$select_stmt .= " LIMIT $count OFFSET ". $count * ($page -1) unless $showall;

	my $page_set = $dbh->selectall_arrayref($select_stmt) || $self->db_error();

	my %return;

	$return{'SORT_PARAMS'} = $self->mkurlparams(
		{
			'limit'     => $limit,
			'pattern'   => $pattern,
			'showall'   => $showall,
			'desc'      => $n_desc,
			'last_sort' => $sort
		}
	);

	$return{'LIMIT'}   = $self->prep_select($self->{'list_search_items'},$limit);
	$return{'PATTERN'} = $pattern;

	my $rc = $dbh->selectall_arrayref("SELECT FOUND_ROWS()");
	my $res_count = $rc->[0]->[0];

	$return{'NUM_MATCHES'} = $res_count;

	################################################################################
	# prep data for the template
	################################################################################
	my %dates;
	foreach (@{$self->{'dates'}}) {
		$dates{$_->{'name'}} = 1;
	}

	my %times;
	foreach (@{$self->{'times'}}) {
		$times{$_->{'name'}} = 1;
	}

	foreach (@{$page_set}) {
		my %v;
		for (my $i=0; $i <= @list; $i++) {
			my $key = $list[$i];

			$key =~ s/$self->{'table'}\.//; # take of the table name in front
			# we either end up with the column name from the primay table,
			# or the joined table name + column
			$key =~ s/^.* AS //i;

			$v{$key} = $_->[$i];

			if (defined($dates{$key})) {
				$v{$key} = $self->sql_to_date($v{$key});
			}
			elsif (defined($times{$key})) {
				$v{$key} = $self->sql_to_time($v{$key});
			}
		}

		push(@{$return{'DATA'}},\%v);
	}

	$self->{'success'} = 1;
	return { %return, $self->{'pager'}->paginate($params,$res_count) };
}

sub view {
	my $self = shift;
	my $p    = shift;
	my $additional_constraint = shift || "";

	$self->{'success'} = 0;

	my $dbh    = $p->{'dbh'};
	my $params = $p->{'params'};

	unless ($params->{$self->{'pkey'}} =~ /$self->{'pkey_regexp'}/) {
		return $self->display_error("Invalid ID");
	}

	# make sure our additional constraint won't break the sql
	$additional_constraint =~ s/^\s*(where|and|or)\s+//go;
	if (length($additional_constraint)) {
		$additional_constraint = "AND $additional_constraint";
	}

	my @list;
	foreach ($self->{'pkey'}, @{$self->{'columns'}}) {
		push(@list,"$self->{'table'}.$_");
	}

	# figure out tables to join against
	my @joins;
	foreach my $join (@{$self->{'references'}}) {
		push(@joins,"LEFT JOIN $join->{'table'} ON $self->{'table'}.$join->{'fkey'} = $join->{'table'}.$join->{'pkey'}");
		foreach (@{$join->{'columns'}}) {
			push(@list,"$join->{'table'}.$_");
		}
	}

	if ($self->{joins}) {
		foreach my $join (@{$self->{joins}}) {
			my $fkey;
			if ($join->{fkey} =~ /\./) {
				$fkey = $join->{fkey};
			}
			else {
				$fkey = $self->{table}.'.'.$join->{fkey};
			}

			push(@joins,"LEFT JOIN $join->{'table'} ON $fkey = $join->{'table'}.$join->{'pkey'}");

			foreach (@{$join->{columns}}) {
				if ($_ =~ /\./) {
					push(@list,$_);
				}
				else {
					push(@list,$join->{'table'}.".$_");
				}
			}
		}
	}

	my $select_statement = "
		SELECT " .
			join(",\n",@list). "
		FROM 
			$self->{'table'} ".
		join("\n",@joins). "
		WHERE 
			$self->{'table'}.$self->{'pkey'} = ?
			$additional_constraint";

	my $res = $dbh->selectall_arrayref($select_statement,undef,$params->{$self->{'pkey'}}) || $self->db_error();

	my %v;
	if (defined($res) && defined($res->[0])) {
		# copy values into template
		$v{$self->{'pkey'}} = $params->{$self->{'pkey'}};
		
		for (my $i=0; $i <= $#list; $i++) {
			my $key = $list[$i];

			$key =~ s/$self->{'table'}\.//;    # take of the table name in front

			$v{$key} = $res->[0]->[$i];
		}
	}
	else {
		return $self->display_error("Record not found");
	}

	# pretty up dates
	foreach (@{$self->{'dates'}}) {
		$v{$_} = $self->sql_to_date($v{$_});
	}

	# pretty up times
	foreach (@{$self->{'times'}}) {
		$v{$_} = $self->sql_to_time($v{$_});
	}

	$self->{'success'} = 1;
	return \%v;
}

sub toggle {
	my $self = shift;
	my $p    = shift;
	my $column = shift;

	$self->{'success'} = 0;

	my $dbh    = $p->{'dbh'};
	my $params = $p->{'params'};

	unless ($params->{$self->{'pkey'}} =~ /$self->{'pkey_regexp'}/) {
		return $self->display_error("Invalid ID");
	}

	unless ($column =~ /^\w+$/) {
		return $self->display_error("Invalid toggle column");
	}

	$dbh->do("
		UPDATE
			$self->{'table'}
		SET 
			$column = ($column+1)%2
		WHERE 
			$self->{'pkey'} = ?",
		undef,
		$params->{$self->{'pkey'}}) || $self->db_error();

	$self->{'success'} = 1;
	return 1;
}

sub get_insert_id {
	my $self = shift;
	my $p    = shift;

	my $dbh = $p->{'dbh'};
	
	return $p->{dbh}->last_insert_id(undef,undef,$self->{'table'},$self->{'pkey'});
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
