=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Install::Post - handles common post site setup tasks

=head1 VERSION

$Id$

=head1 SYNOPSIS

This object is used by Voodoo internally.

=head1 OUTPUT

=cut ###########################################################################
package Apache::Voodoo::Install::Post;

$VERSION = '1.21';

use strict;
use warnings;

use base("Apache::Voodoo::Install");

use Apache::Voodoo::Constants;

use Config::General;

sub new {
	my $class = shift;
	my %params = @_;

	my $self = {%params};

	my $ac = Apache::Voodoo::Constants->new();
	$self->{'_md5_'} = Digest::MD5->new;

	$self->{'prefix'}       = $ac->prefix();
	$self->{'install_path'} = $ac->install_path()."/".$self->{'app_name'};

	$self->{'conf_file'}    = $self->{'install_path'}."/".$ac->conf_file();
	$self->{'apache_uid'}   = $ac->apache_uid();
	$self->{'apache_gid'}   = $ac->apache_gid();

	unless (-e $self->{'conf_file'}) {
		die "Can't open configuration file: $self->{'conf_file'}\n";
	}

	$self->{'conf_data'} = { ParseConfig($self->{'conf_file'}) };

	bless $self, $class;
	return $self;
}

sub do_setup_checks {
	my $self = shift;

	my $install_path = $self->{'install_path'};
	my $prefix       = $self->{'prefix'};
	my $app_name     = $self->{'app_name'};

	$self->make_symlink("$install_path/code","$prefix/lib/perl/$app_name");

	$self->info("- Checking session directory:");
	$self->make_writeable_dirs($self->{'conf_data'}->{'session_dir'});
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include
in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
of the Artistic License :)

=cut ################################################################################
