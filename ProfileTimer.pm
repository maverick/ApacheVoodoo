=pod ################################################################################

=head1 Voodoo::ProfileTimer

$Id: ProfileTimer.pm,v 1.2 2002/01/18 03:39:20 maverick Exp $

=head1 Initial Coding: Maverick

Utility object to provide a timer to profile the time it takes to process certain
steps of a request

=cut ################################################################################
package Voodoo::ProfileTimer;

use strict;
use Time::HiRes;

sub new {
	my $class = shift;
	my $self = [];
	
	bless($self,$class);
	
	$self->mark("Start");

	return $self;
}

sub mark {
	my $self = shift;
	push(@{$self},[Time::HiRes::time,shift]);
}

sub report {
	my $self = shift;

	my $last = $#{$self};
	my $total_time = $self->[$last]->[0] - $self->[0]->[0];

	my $report = "Total Time: $total_time\n";
	$report .= "-"x40 ."\n";
	foreach (my $i=1; $i <= $last; $i++) {
		my $t = $self->[$i]->[0] - $self->[$i-1]->[0];
		my $l = $self->[$i]->[1];
		$report .= sprintf("%.5f %5.2f%% ",  $t, $t/$total_time*100) . "$l\n";
	}

	return $report;
}

1;

=pod ################################################################################

=head1 CVS Log

 $Log: ProfileTimer.pm,v $
 Revision 1.2  2002/01/18 03:39:20  maverick
 bugs go squish

 Revision 1.1  2002/01/13 06:18:43  maverick
 Timer object used to profile execution times of running code.


=cut ################################################################################

