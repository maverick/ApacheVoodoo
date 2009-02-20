=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Zombie - Internal module used by Voodoo when a end user module dies on load.

=head1 VERSION

$Id$

=head1 SYNOPSIS

This module is used by Apache::Voodoo::Application as a facimily replacement for a dead module
when either devel_mode or debug is 1 in the application's voodoo.conf.  Any calls to this module
displays an error message via L<Apache::Voodoo::DisplayError> describing what blew up and
where.  This is a development tool...you shouldn't have any Zombies in your production server :)

=cut ################################################################################
package Apache::Voodoo::Zombie;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/Zombie.pm $' =~ m!(\d+\.\d+)!)[0]||10);

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

	return $self->display_error($error,"/$link");
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include
in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
of the Artistic License :)

=cut ################################################################################
