=pod ################################################################################

=head1 Voodoo::Loader

$Id: Loader.pm,v 1.2 2002/01/18 03:39:20 maverick Exp $

=head1 Initial Coding: Maverick

Base class for each of the module loading mechanisms.  Look at Loader::Static
and Loader::Dynamic

=cut ################################################################################

package Voodoo::Loader;

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

		require "Voodoo/Zombie.pm";
		$obj = Voodoo::Zombie->new();

		$obj->module($module);
		$obj->error($error);
	}

	return $obj;
}

1;

=pod ################################################################################

=head1 CVS Log

 $Log: Loader.pm,v $
 Revision 1.2  2002/01/18 03:39:20  maverick
 bugs go squish


=cut ################################################################################
