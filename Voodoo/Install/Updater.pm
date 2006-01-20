=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Install::Updater

=head1 SYNOPSIS

This package provides the methods that do pre/post/upgrade commands as specified
by the various .xml files in an application.

=cut ###########################################################################
package Apache::Voodoo::Install::Updater;

use strict;
use warnings;

use base("Apache::Voodoo::Installer");

use CPAN::Config;
use CPAN;
use DBI;
use Digest::MD5;
use XML::Checker::Parser;

# make CPAN download dependancies
$CPAN::Config->{'prerequisites_policy'} = 'follow';

sub new {
	my $class = shift;
	my %params = @_;

	my $self = {};

	bless $self, $class;
}

1;
