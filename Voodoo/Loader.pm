#####################################################################################

=head1 Apache::Voodoo::Loader

$Id$

=head1 Initial Coding: Maverick

Base class for each of the module loading mechanisms.  Look at Loader::Static
and Loader::Dynamic

=cut ################################################################################

package Apache::Voodoo::Loader;

use strict;

sub load_module {
	my $self = shift;
	my $module = shift || $self->{'module'};
	
	my $file = $module;
	$file =~ s/::/\//go;
	$file .= ".pm";

	# HERE BE THE BLACK MAGIC
	# perl stores the names of the loaded modules in here.
	# so, if you require the same module twice (or you change it on disk later)
	# perl consults this hash and doesn't reload it.
	# delete the entry, and perl will re-require the module from scratch
	delete $INC{$file};

	my $obj;
	eval {
		require $file;
		$obj = $module->new;
	};
	if ($@) {
		print STDERR "Failed to load $module: $@\n";
		my $error = $@;

		$module =~ s/^[^:]+:://;

		require "Apache/Voodoo/Zombie.pm";
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
