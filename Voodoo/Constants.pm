=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Constants

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

	use Data::Dumper;
	my $self;
	eval {
		use Apache::Voodoo::MyConfig;
		$self = $Apache::Voodoo::MyConfig::CONFIG;
	};
	if ($@) {
		print $@,"\n\n";
		print "Can't find Apache::Voodoo::MyConfig.  This probably means that Apache Voodoo hasn't been configured yet.\n";
		print "Please do so by running \"voodoo-control setconfig\"\n";
		exit 1;
	}

	unless (ref($self) eq "HASH") {
		print "There was an error loading Apache::Voodoo::MyConfig.  Please run \"voodoo-control setconfig\"\n";
		exit 1;
	}

	bless($self,$class);

	return $self;
}

sub prefix       { return $_[0]->{PREFIX};       }
sub install_path { return $_[0]->{INSTALL_PATH}; }
sub session_path { return $_[0]->{SESSION_PATH}; }
sub conf_path    { return $_[0]->{CONF_PATH};    }
sub updates_path { return $_[0]->{UPDATES_PATH}; }
sub conf_file    { return $_[0]->{CONF_FILE};    }
sub tmpl_path    { return $_[0]->{TMPL_PATH};    }
sub code_path    { return $_[0]->{CODE_PATH};    }
sub apache_uid   { return $_[0]->{APACHE_UID};   }
sub apache_gid   { return $_[0]->{APACHE_GID};   }

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
