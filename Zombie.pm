=pod ################################################################################

=head1 Voodoo::Zombie

$Id: Zombie.pm,v 1.3 2003/01/03 19:23:53 maverick Exp $

=head1 Initial Coding: Maverick

This module is used by the Server Config as a facimily replacement for a dead module
when halt_on_errors is 0 in the server configuration.  Any calls to this module
redirect to display error, with a message stating which module it's replacing and
the error in that module.  This is a development tool...you shouldn't have any
Zombies in your production server :)

=cut ################################################################################
package Voodoo::Zombie;

use strict;

use base("Voodoo::Base");

sub module { my $self = shift; $self->{'module'} = shift; }
sub error  { my $self = shift; $self->{'error'}  = shift; }

#
# Autoload is used to catch whatever method was supposed to be invoked
# in the dead module.
#
sub AUTOLOAD { 
	my $self = shift;
	my $p    = shift;

	our $AUTOLOAD;
	my $method = $AUTOLOAD;
	$method =~ s/.*:://;

	# ya, I know...it's embeded HTML...I don't feel too bad 
	# about it though...this is a development tool after all
	my $error = "<pre>\n";
	$error .= "There was an error loading the module for this page ($self->{'module'}):\n\n";
	$error .= "$self->{'error'}\n";
	$error .= "</pre>";

	my $link = $self->{'module'};
	
	$link =~ s/::/\//g;
	unless ($method eq "handle") {
		$link =~ s/([^\/]+)$/$method."_".$1/e;
	}

	$self->debug("ZOMBIE: $self->{'module'} $method");
	return $self->display_error($error,"/$link");
}

1;

=pod ################################################################################

=head1 CVS Log

 $Log: Zombie.pm,v $
 Revision 1.3  2003/01/03 19:23:53  maverick
 Now uses AUTOLOAD to trap any method call that would have been executed on the
 dead module...as opposed to just defining the standard set of 'typical' methods.

 Revision 1.2  2001/12/27 05:01:16  maverick
 Dynamic loading scheme reworked.  Seems to be working correctly now

 Addition of 'site_root' template var that will always point to the top level
 URL for a given application regardless if it's a virtual host or alias.

 changed <pre_include> to <includes> and added post_include to the template_conf section

 Changed database parameter layout

 Revision 1.1  2001/12/09 00:00:38  maverick
 Added a devel mode where modules are dynamically loaded on the fly if the are changed.
 Added the Zombie module that replaces a dead module (one with a compilation error).


=cut ################################################################################

