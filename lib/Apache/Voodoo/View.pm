=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Template

=head1 VERSION

$Id: View.pm 16110 2009-05-29 17:09:13Z medwards $

=head1 SYNOPSIS



=cut ################################################################################
package Apache::Voodoo::View;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/View.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo");

#
# Gets or sets the returned content type
#
sub content_type {
	my $self = shift;

	if (defined($_[0])) {
		$self->{content_type} = shift;
	}

	return $self->{content_type};
}

#
# Called at the begining of each request
#
sub begin { }

#
# Called multiple times as each handler / controller produces data.
#
sub params { } 

#
# Called whenver an exception is thrown by the handler / controller.
#
sub exception { }

#
# Whatever this method returns is passed to the browser.
#
sub output { }

#
# Called at the end of each request.  Here is where any cleanup happens.
#
sub finish { }

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file 
include in this package or L<Apache::Voodoo::license>.  The summary is it's a 
legalese version of the Artistic License :)

=cut ################################################################################
