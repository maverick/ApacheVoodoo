#####################################################################################

=head1 NAME

Apache::Voodoo::Zombie - Internal module used by Voodoo when a end user module dies on load.

=head1 VERSION

$Id$

=head1 SYNOPSIS

This module is used by Apache::Voodoo::ServerConfig as a facimily replacement for a dead module
when halt_on_errors is 0 in the server configuration.  Any calls to this module
displays and error message via L<Apache::Voodoo::DisplayError> describing what blew up and
where.  This is a development tool...you shouldn't have any Zombies in your 
production server :)

=cut ################################################################################
package Apache::Voodoo::Zombie;

use strict;

use base("Apache::Voodoo");

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
