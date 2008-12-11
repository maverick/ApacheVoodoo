=pod ###########################################################################
Factory that creates either a file based or mysql based session storage object.
=cut ###########################################################################
package Apache::Voodoo::Session;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class = shift;
	my $type  = shift;
	my $conf  = shift;

	if ($type eq "File") {
		require Apache::Voodoo::Session::File;
		return Apache::Voodoo::Session::File->new($conf);
	}
	elsif ($type eq "MySQL") {
		require Apache::Voodoo::Session::MySQL;
		return Apache::Voodoo::Session::MySQL->new($conf);
	}
	else {
		die "$type is not supported session type.\n";
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
