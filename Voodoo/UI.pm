=pod ###########################################################################
Factory that creates the requested form ui driver type.
=cut ###########################################################################
package Apache::Voodoo::UI;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/UI.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class  = shift;
	my $config = shift;

	my $obj = "Apache::Voodoo::UI::".$config->ui();
	my $file = $obj;

	$file =~ s/::/\//g;
	$file .= ".pm";

	require $file;
	return $obj->new($config);
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
