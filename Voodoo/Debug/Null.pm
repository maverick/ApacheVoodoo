=pod ################################################################################

=head1 NAME

Apache::Voodoo::Debug::Null

=head1 VERSION

$Id$

=head1 SYNOPSIS

Does nothing gracefully

=cut ###########################################################################
package Apache::Voodoo::Debug::Null;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class = shift;

	my $self = {};

	bless($self,$class);

	return $self;
}

sub init      { return; }
sub shutdown  { return; }
sub debug     { return; }
sub info      { return; }
sub warn      { return; }
sub error     { return; }
sub exception { return; }
sub trace     { return; }
sub table     { return; }

sub mark          { return; }
sub return_data   { return; }
sub session_id    { return; }
sub url           { return; }
sub result        { return; }
sub params        { return; }
sub template_conf { return; }
sub session       { return; }

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
