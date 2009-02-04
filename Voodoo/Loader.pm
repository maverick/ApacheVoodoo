=pod #####################################################################################

=head1 Apache::Voodoo::Loader

$Id$

=head1 Initial Coding: Maverick

Base class for each of the module loading mechanisms.  Look at Loader::Static
and Loader::Dynamic

=cut ################################################################################
package Apache::Voodoo::Loader;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub load_module {
	my $self    = shift;
	my $module  = shift || $self->{'module'};
	
	my $file = $module;
	$file =~ s/::/\//go;
	$file .= ".pm";

	# HERE BE THE BLACK MAGIC
	# perl stores the names of the loaded modules in here.
	# so, if you require the same module twice (or you change it on disk later)
	# perl consults this hash and doesn't reload it.
	# delete the entry, and perl will re-require the module from scratch
	#
	# We don't want to do this when the server is starting for the first time.  If
	# we're running multiple instances of the same application, then we're just wasting time
	# recompiling the same modules over and over, and "warnings" will sometimes (uselessly) yell about
	# modules being redefined.
	unless ($self->{'bootstrapping'}) {
		delete $INC{$file};
	}

	my $obj;
	eval {
		require $file;
		$obj = $module->new;
	};
	if ($@) {
		print STDERR "Failed to load $module: $@";
		my $error = $@;

		$module =~ s/^[^:]+:://;

		require "Apache/Voodoo/Zombie.pm";
		import Apache::Voodoo::Zombie;
		$obj = Apache::Voodoo::Zombie->new();

		$obj->module($module);
		$obj->error($error);
	}

	return $obj;
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
