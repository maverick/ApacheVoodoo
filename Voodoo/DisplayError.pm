=pod #####################################################################################

=head1 NAME

Apache::Voodoo::DisplayError - error message displayer

=head1 VERSION

$Id$

=head1 SYNOPSIS

This module is internal to Voodoo. It's used to provide a generic error page.  End
user interaction is through L<Apache::Voodoo>::display_error()

=cut ################################################################################

package Apache::Voodoo::DisplayError;

$VERSION = '1.21';

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

		$errorurl ||= $self->history($session,3);

		# remove it from the session to keep it from growing
		delete $session->{"er_" . $error};
	
		return {
			"ERROR_STRING" => $errorstring,
		        "ERROR_URL"    => $errorurl
		       };
	}
	else {
		return {
			'ERROR_STRING' => "Can't find the requested error message.",
			'ERROR_URL'    => "/index"
		};
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
