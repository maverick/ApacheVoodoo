#####################################################################################

=head1 NAME

Apache::Voodoo::DisplayError

=head1 VERSION

$Id$

=head1 SYNOPSIS

This module is internal to Voodoo. It's used to provide a generic error page.  End
user interaction is through L<Apache::Voodoo>::display_error()

=cut ################################################################################

package Apache::Voodoo::DisplayError;

use strict;
use base ("Apache::Voodoo");

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
