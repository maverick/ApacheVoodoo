=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Zombie - Internal module used by Voodoo when a end user module doesn't compile.

=head1 VERSION

$Id$

=head1 SYNOPSIS

This module is used by Apache::Voodoo::Application as a stand in for a module that didn't compile
when either devel_mode or debug is 1 in the application's voodoo.conf.  Any calls to this module simply
throw an exception describing the describing the compilation error.
This is a development tool...you shouldn't have any Zombies in your production environment :)

=cut ################################################################################
package Apache::Voodoo::Zombie;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Apache::Voodoo::Exception;

sub new {
	my $class  = shift;
	my $module = shift;
	my $error  = shift;

	my $self = {
		'module' => $module,
		'error'  => $error
	};

	bless ($self,$class);
	return $self;
}

#
# Autoload is used to catch whatever method was supposed to be invoked
# in the dead module.
#
sub AUTOLOAD { 
	next unless ref($_[0]);

	my $self = shift;
	my $p    = shift;

	our $AUTOLOAD;
	my $method = $AUTOLOAD;
	$method =~ s/.*:://;

	Apache::Voodoo::Exception::Compilation->throw(
		'module' => $self->{'module'},
		'error'  => $self->{'error'}
	);
}

# keeps autoloader from making one
sub DESTROY {}

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
