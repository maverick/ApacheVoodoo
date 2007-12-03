=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Constants - interface to Apache::Voodoo configuration settings.

=head1 VERSION

$Id$

=head1 SYNOPSIS

This package provide an OO interface to retrive the various paths and config settings used by Apache Voodoo.

=cut ###########################################################################
package Apache::Voodoo::Constants;

use strict;
use warnings;

sub new {
	my $class = shift;

	my $self;
	eval "
		use Apache::Voodoo::MyConfig;
	";

	# copy the config.
	$self = { %{$Apache::Voodoo::MyConfig::CONFIG} };

	if ($@) {
		die "$@\n".
		    "Can't find Apache::Voodoo::MyConfig.  This probably means that Apache Voodoo hasn't been configured yet.\n".
		    "Please do so by running \"voodoo-control setconfig\"\n";
	}

	unless (ref($self) eq "HASH") {
		die "There was an error loading Apache::Voodoo::MyConfig.  Please run \"voodoo-control setconfig\"\n";
	}

	bless($self,$class);

	return $self;
}

sub apache_gid   { return $_[0]->{APACHE_GID};   }
sub apache_uid   { return $_[0]->{APACHE_UID};   }
sub code_path    { return $_[0]->{CODE_PATH};    }
sub conf_file    { return $_[0]->{CONF_FILE};    }
sub conf_path    { return $_[0]->{CONF_PATH};    }
sub install_path { return $_[0]->{INSTALL_PATH}; }
sub prefix       { return $_[0]->{PREFIX};       }
sub session_path { return $_[0]->{SESSION_PATH}; }
sub tmpl_path    { return $_[0]->{TMPL_PATH};    }
sub updates_path { return $_[0]->{UPDATES_PATH}; }

1;

=pod ###########################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE 
file include in this package or L<Apache::Voodoo::license>.  The summary is
it's a legalese version of the Artistic License :)

=cut ###########################################################################
