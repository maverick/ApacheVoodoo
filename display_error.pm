=pod ################################################################################

=head1 NAME

Voodoo::display_error

=head1 VERSION

$Id$

=head1 SYNOPSIS

This module is internal to Voodoo. It's used to provide a generic error page.  End
user interaction is through L<Voodoo::Base>::display_error()

=cut ################################################################################
package Voodoo::display_error;

use strict;
use base ("Voodoo::Base");

sub handle {
	my $self = shift;
	my $p    = shift;

	my $session = $p->{'session'};
	my $error   = $p->{'params'}->{'error'};

	if (defined($session->{"er_" . $error})) {
		# pull the info out of the session
		my $errorstring = $session->{"er_" . $error}->{'error'};
		my $errorurl    = $session->{"er_" . $error}->{'return'};

		$self->debug($self->history($session,2));
		$errorurl ||= $self->history($session,2);

		# remove it from the session to keep it from growing
		delete $session->{"er_" . $error};
	
		return {"ERROR_STRING" => $errorstring,
		        "ERROR_URL"    => $errorurl
		       };
	}
	else {
		return {'ERROR_STRING' => "Eeek! Error message not found\n"};
	}
}

1;

=pod ################################################################################

=head1 CVS Log

$Log: display_error.pm,v $
Revision 1.4  2003/01/03 22:15:19  maverick
minor bug fixes & enhancements

Revision 1.3  2001/11/21 03:28:53  maverick
*** empty log message ***

Revision 1.2  2001/09/08 17:23:18  maverick
*** empty log message ***

Revision 1.1  2001/08/15 15:02:12  maverick
First big checking after making this it's own project

Revision 1.4  2001/07/17 18:15:59  maverick
added proper inheritance

Revision 1.3  2001/07/14 14:07:42  maverick
*** empty log message ***

Revision 1.2  2001/06/19 18:22:30  maverick
big checking after completely separating the presentation from the logic layer.

=cut ################################################################################
