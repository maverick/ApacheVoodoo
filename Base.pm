=pod ################################################################################

=head1 Voodoo::Base

$Id: Base.pm,v 1.7 2003/01/03 22:15:19 maverick Exp $

=head1 Initial Coding: Maverick

=cut ################################################################################

package Voodoo::Base;

use strict;

sub new {
	my $class = shift;
	my $self = {};

	bless $self, $class;

	$self->init();

	return $self;
}

=pod ################################################################################

=head2 init

This method may be overridden in child classes to perfom perl child initilization

=cut ################################################################################
sub init { }


=pod ################################################################################

=head2 redirect

Redirects the user to the given URI.

 usage:
	return $self->redirect($some_uri);

=cut ################################################################################
sub redirect {
	shift;
   	return [ "REDIRECTED" , shift ];
}


=pod ################################################################################

=head2 display_error

Redirects the user to a generic error message display page.

 usage:
	return $self->display_error($error_message,$click_here_to_continue_uri);

=cut ################################################################################
sub display_error {
	shift;
   	return [ "DISPLAY_ERROR", shift, shift ];
}

=pod ################################################################################

=head2 access_denied

 usage:
    return $self->access_denied;
        or
    return $self->access_denied($url_for_access_denied_message);

This method is used to indicate to the Handler that the user is not allowed
to access the URI requested.  If the optional parameter is not supplied the standard 
Apache 403 (Forbidden) is returned to the user.

=cut ################################################################################

sub access_denied {
	shift;
	return [ 'ACCESS_DENIED' , shift ];
}

=head2 raw_mode

 usage:
    return $self->raw_mode('content-type','contents',\%headers_out);

This method is used to bypass the normal templating subsystem and allow the 'contents'
to be streamed directly to the browser.  Useful for generating CSVs and binary data 
from within Voodoo

=cut ################################################################################

sub raw_mode {
	shift;
	return [ 'RAW_MODE' , @_];
}


=pod ################################################################################

=head2 debug

Optionally prints user debugging messages to the error_log file and DEBUG template block. 
Messages can be turn on or off globally using the DEBUG option of the configuration.

If the first paramater to debug is a reference, then the structure is printed using Data::Dumper.

 usage:
	return $self->debug($one_message,$two_message, ...);

=cut ################################################################################
sub debug { 
	my $self = shift;

	$Voodoo::Handler::debug->debug(@_) if $Voodoo::Handler::debug;
}

sub mark {
	my $self = shift;

	$Voodoo::Handler::debug->mark(@_) if $Voodoo::Handler::debug;
}

=pod ################################################################################

=head2 db_error

Used to report catasrtophic database errors to the error_log file.
THIS METHOD DOES NOT RETURN

 usage:
	$dbh->selectall_arrayref($query) || $self->db_error();

=cut ################################################################################
sub db_error {
	my @caller = caller(1);

	my $query = $DBI::lasth->{'Statement'};
	$query = join("\n", map { $_ =~ s/^\s*//; $_} split(/\n/,$query));

	my $errstr = "\n";
	$errstr .= "==================== DB ERROR ====================\n";
	$errstr .= "TIME:       ". scalar(localtime) . "\n";
	$errstr .= "PACKAGE:    $caller[0]\n";
	$errstr .= "FILE:       $caller[1]\n";
	$errstr .= "SUBROUTINE: $caller[3]\n";
	$errstr .= "LINE:       $caller[2]\n\n";
	$errstr .= "$DBI::errstr\n";
	$errstr .= "===================== QUERY ======================\n";
	$errstr .= "$query\n";
	$errstr .= "==================================================\n";

	# don't really care for this, but there doesn't seem to be any way to 
	# terminate this request.
	die $errstr;
}

### old and busted (flexible, but clunky interface)
sub select_prep {
	my $self    = shift;
	my $columns = shift;
	my $result  = shift;
	my $select  = shift;

	$select->[0] = lc($select->[0]);
	$select->[1] = lc($select->[1]);

	my $a_ref = [];
	foreach my $row (@{$result}) {
		my $h_ref = {};
		for (my $i=0; $i < @{$columns}; $i++) {
			$h_ref->{$columns->[$i]} = $row->[$i];
			if ($columns->[$i] eq $select->[0] && $row->[$i] eq $select->[1]) {
				$h_ref->{'selected'} = "selected";
			}
		}
		push(@{$a_ref},$h_ref);
	}
	return $a_ref;
}

# new hotness (slighly inflexible, but streamlined interface)
#
# 95% of the time, select boxes are IDENTICAL. The other 5% you can code yerself
#
sub prep_select {
	my $self   = shift;
	my $list   = shift;
	my $select = shift;

	return [ 
		map {
			{
				"ID"       => $_->[0],
				"NAME"     => $_->[1],
				"SELECTED" => ($_->[0] eq $select)?1:0
			}
		} @{$list}
	];
}

sub select_multi_prep {
	my ($self,$result,$selected) = @_;
	
	my %selected = map { $_ => 1 } @$selected;
	my $a_ref    = [
		map {{
			id       => $_->[0],
			name     => $_->[1],
			selected => defined $selected{$_->[0]}
		}} @$result 
	];

	return $a_ref;
}

sub trim {
	my $self  = shift;
	my $param = shift;

	$param =~ s/^\s*//o;
	$param =~ s/\s*$//o;

	return $param;
}

# Function:  dates_in_order
# Purpose:  Make sure end date comes after start date
sub dates_in_order {
	my $self      = shift;
	my $startdate = shift;
	my $enddate   = shift;

	#split off the parts of the date
	my ($sm,$sd,$sy) = split("/",$startdate, 3);
	my ($em,$ed,$ey) = split("/",$enddate, 3);

	#make sure the end date is past the start date
	if ($ey < $sy) {
		return 0;
	}
	elsif ($ey == $sy) {
		if ($em < $sm) {
			return 0;
		}
		elsif ($em == $sm) {
			if ($ed < $sd) {
				return 0;
			}
		}
	}

	# If we got here we were sucessful
	return 1;
}

# Function: validate_date
# Purpose:  Check to make sure a date follows the MM/DD/YYYY format and checks the sanity of the numbers passed in
sub validate_date {
	my $self = shift;
	my $date = shift;
	my $check_future = shift;

	#Number of days in each month
	my %md = (1  => 31,
	          2  => 29,
	          3  => 31,
	          4  => 30,
	          5  => 31,
	          6  => 30,
	          7  => 31,
	          8  => 31,
	          9  => 30,
	          10 => 31,
	          11 => 30,
	          12 => 31);


	#Split the date up into month day year
	my ($m,$d,$y) = split("/",$date, 3);

	#Strip off any leading 0s 
	$m *= 1;
	$d *= 1;
	$y *= 1;

	#If the month isn't within a valid range return
	if ($m !~ /^\d+$/ || $m < 1 || $m > 12) {
		return 0;
	}

	#Check to see if the day is valid on leap years
 	if ($m == 2 && $d == 29) {
		unless (($y%4 == 0 && $y%100 != 0) || $y%400 == 0){
			return 0;
		}
	}

	#If the day isn't within a valid range return
	if ($d !~ /^\d+$/ || $d < 1 || $d > $md{$m}) {
		return 0;
	}

	# make sure the year is four digits
	if ($y !~ /^\d+$/ || $y < 1000 || $y > 9999) {
		return 0;
	}

	if ($check_future == 1) {
		#Get the local system time
		my ($M,$D,$Y) = (localtime(time))[4,3,5];
		$M++;
		$Y+=1900;

		#Make sure the date is in the future
		if ($y < $Y) {
			return undef;
		}
		elsif ($y == $Y) {
			if ($m < $M) {
				return undef;
			}
			elsif ($m == $M) {
				if ($d <= $D) {
					return undef;
				}
			}
		}
	}

	# if we make it this far the date should be ok return sucess
	return 1;
}

sub date_to_sql {
	my $self = shift;
	my $date = shift;

	# Get rid of all spaces in the date
	$date =~ s/\s//go;

	# Split the date up into month day year
	my ($m,$d,$y) = split(/[\/-]/,$date,3);

	# assume two digit years belong in 2000
	if ($y < 1000) { $y += 2000; }

	return sprintf("%04d-%02d-%02d",$y,$m,$d);
}

sub sql_to_date {
	my $self = shift;
	my $date = shift;

	if ($date eq "NULL" || $date eq "") {
		return "";
	}

	$date =~ s/ .*//go;

	my ($y,$m,$d) = split(/[\/-]/,$date,3);

	return sprintf("%02d/%02d/%04d",$m,$d,$y);
}

sub sql_to_time {
	my $self = shift;
	my $time = shift;

	if ($time eq "NULL" || $time eq "") {
		return "";
	}

	$time =~ s/.* //o;

	my ($h,$m,$s) = split(/:/,$time);

	if ($h == 12) {	# noon
		return sprintf("%2d:%02d PM",$h,$m);
	}
	if ($h == 0) {	# midnight
		return sprintf("%2d:%02d AM",12,$m);
	}
	elsif ($h > 12) {
		return sprintf("%2d:%02d PM",$h-12,$m);
	}
	else {
		return sprintf("%2d:%02d AM",$h,$m);
	}
}

sub time_to_sql {
	my $self = shift;
	my $time = shift;

	$time =~ s/\s*//go;
	$time =~ s/\.//go;

	unless ($time =~ /^\d?\d:\d\d(am|pm)?$/io) {
		return undef;
	}

	my $pm = 'NA';
	if ($time =~ s/([ap])m$//igo) {
		$pm = (lc($1) eq "p")?1:0;
	}

	my ($h,$m) = split(/:/,$time,2);

	if ($m < 0 || $m > 60) { return undef; }

	if ($h < 0 || $h > 23) { return undef; }

	# 12 am is midnight and 12 pm is noon...I've always hated that.
	if ($pm eq '1' && $h < 12) {
		$h += 12;
	}
	elsif ($pm eq '0' && $h == 12) {
		$h = 0;
	}

	return sprintf("%02d:%02d:00",$h,$m);
}

sub pretty_time {
	my $self = shift;
	my $time = shift;

	my @p = localtime($time || time);

	$time =~ /^\d+\.(\d+)$/;
	return sprintf("%02d/%02d/%04d %02d:%02d:%02d ",$p[4]+1, $p[3], $p[5]+1900, $p[3], $p[2], $p[1]) . $1;
}

sub mysql_timestamp { 
        my $self = shift; 
        my $time = shift; 
 
        my @p = localtime($time || time); 
 
        $time =~ /^\d+\.(\d+)$/; 
        return sprintf("%04d%02d%02d%02d%02d%02d",$p[5]+1900,$p[4]+1, $p[3],$p[3], $p[2], $p[1]);
}

sub pretty_mysql_timestamp {
	my $self = shift;
	my $time = shift;

	# make an array out containing every two digits
	my @p = ($time =~ /(\d\d)/go);

	return $self->sql_to_date("$p[0]$p[1]-$p[2]-$p[3]")." ".$self->sql_to_time("$p[4]:$p[5]:$p[6]");
}

# this sub is for use with the callback structure of Voodoo::Table.
# $params is injected with a arrayref of column to translate
#
# since $params is a reference, the actual columns as seen by the db
# are added to $params and they get back out that way.
# all return values are just error messages (if any)
sub month_year_to_sql {
	my $self = shift;
	my $conn = shift;
	my $params = shift;

	my @errors;

	foreach my $column (@{$params->{'MONTH_YEAR_COLUMNS'}}) {

		# see if the present button was nailed
		if (defined($params->{$column."_present"})) {
			$params->{$column} = '1/1/1000';
		}
		else {
			my $ok = 1;
			if (!defined($params->{$column."_month"})) {
				push(@errors,"MISSING_${column}_month");
				$ok = 0;
			}
			elsif ($params->{$column."_month"} < 1 || $params->{$column."_month"} > 12) {
				push(@errors,"BAD_${column}_month");
				$ok = 0;
			}

			if (!defined($params->{$column."_year"})) {
				push(@errors,"MISSING_${column}_year");
				$ok = 0;
			}
			elsif ($params->{$column."_year"} < 1000 || $params->{$column."_year"} > 9999) {
				push(@errors,"BAD_${column}_year");
				$ok = 0;
			}

			if ($ok == 1) {
				$params->{$column} = $params->{$column."_month"} . "/01/" . $params->{$column."_year"};
			}
		}
	}
	return @errors;
}

sub mkurlparams {
	my $self = shift;
	my $h    = shift;
	my $o    = shift || {};

	my @return;
	foreach my $key (keys %{$h}) {
		next if exists($o->{$key});

		if (ref($h->{$key})) {
			push(@return, map { "$key=$_" } @{$h->{$key}} );
		}
		else {
			push(@return,"$key=$h->{$key}") if length($h->{$key});
		}
	}

	foreach my $key (keys %{$o}) {
		if (ref($o->{$key})) {
			push(@return, map { "$key=$_" } @{$o->{$key}} );
		}
		else {
			push(@return,"$key=$o->{$key}") if length($o->{$key});
		}
	}

	return join("&",@return);
}

sub safe_text {
	return $_[1] =~ /^[\w\s\.\,\/\[\]\{\}\+\=\-\(\)\:\;\&\?\*]*$/;
}

sub history {
	my $self = shift;
	my $session = shift;
	my $index = shift || 1;

	return $session->{'history'}->[$index]->{'uri'}.'?'.$session->{'history'}->[$index]->{'params'};
}

sub tardis {
	my $self = shift;
	my $p = shift;
	my $uri = $p->{'uri'};
	my $history = $p->{'session'}->{'history'};

	my $i;
	my $find_uri=1;
	for ($i=0; $i <= $#{$history}; $i++) {
		if ($find_uri && $p->{'uri'} eq $history->[$i]->{'uri'}) {
			$find_uri = 0;
		}
		else {
			foreach (@_) {
				if ($_ eq $history->[$i]->{'uri'}) {
					return $self->redirect($self->history($p->{'session'},$i));
				}
			}
		}
	}

	return $self->redirect($self->history($p->{'session'},1));
}

sub last_insert_id {
	my $self = shift;
	my $p    = shift;

	my $dbh = $p->{'dbh'};

	my $res = $dbh->selectall_arrayref("SELECT LAST_INSERT_ID()") || $self->db_error();
	
	return $res->[0]->[0];
}

1;

=pod ################################################################################

=head1 CVS Log

$Log: Base.pm,v $
Revision 1.7  2003/01/03 22:15:19  maverick
minor bug fixes & enhancements

Revision 1.6  2002/01/13 06:17:10  maverick
-- included the functionality of authz_base

Revision 1.5  2001/12/27 05:01:16  maverick
Dynamic loading scheme reworked.  Seems to be working correctly now

Addition of 'site_root' template var that will always point to the top level
URL for a given application regardless if it's a virtual host or alias.

changed <pre_include> to <includes> and added post_include to the template_conf section

Changed database parameter layout

Revision 1.4  2001/12/10 04:20:18  maverick
Added new debug block section that displays a trace of all the output produced
by $self->debug each module

Revision 1.3  2001/11/21 03:28:53  maverick
*** empty log message ***


=cut ################################################################################
