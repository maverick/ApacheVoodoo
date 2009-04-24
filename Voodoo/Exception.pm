=pod ###########################################################################
Exception class definitions for Apache Voodoo.
=cut ###########################################################################
package Apache::Voodoo::Exception;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/MP.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Exception::Class (
	'Apache::Voodoo::Exception',
	
	'Apache::Voodoo::Exception::RunTime' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Run time exception from perl'
	},
);

Apache::Voodoo::Exception::RunTime->Trace(1);
Apache::Voodoo::Exception::RunTime->NoRefs(0);

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
