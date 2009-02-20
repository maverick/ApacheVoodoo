=pod ###########################################################################
Factory that creates either a file based or mysql based session storage object.
=cut ###########################################################################
package Apache::Voodoo::Session;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/Session.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class = shift;
	my $conf  = shift;

	if (defined($conf->{'session_table'})) {
		unless (defined($conf->{'database'})) {
			die "You have sessions configured to be stored in the database but no database configuration.";
		}

		require Apache::Voodoo::Session::MySQL;
		return Apache::Voodoo::Session::MySQL->new($conf);
	}
	elsif (defined($conf->{'session_dir'})) {
		require Apache::Voodoo::Session::File;
		return Apache::Voodoo::Session::File->new($conf);
	}
	else {
		die "You do not have a session storage mechanism defined.";
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
