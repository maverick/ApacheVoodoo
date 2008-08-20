=pod ###########################################################################
Factory that creates either a file based or mysql based session storage object.
=cut ###########################################################################
package Apache::Voodoo::Session;

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
