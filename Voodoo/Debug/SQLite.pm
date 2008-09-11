package Apache::Voodoo::Debug::SQLite;

$VERSION = sprintf("%0.4f",('$HeadURL: svn://localhost/Voodoo/core/Voodoo/Driver.pm $' =~ m!(\d+\.\d+)!)[0]||0);

use strict;
use warnings;

use base("Apache::Voodoo::Debug::common");

sub new {
	my $class = shift;
	my $self = {};

	bless $self,$class;

	return $self;
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
