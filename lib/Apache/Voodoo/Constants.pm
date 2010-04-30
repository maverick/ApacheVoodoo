################################################################################
#
# Apache::Voodoo::Constants 
#
# This package provide an OO interface to retrive the various paths and config 
# settings used by Apache Voodoo.
#
################################################################################
package Apache::Voodoo::Constants;

$VERSION = "3.0100";

use strict;
use warnings;

my $self;

sub new {
	my $class = shift;

	if (ref($self)) {
		return $self;
	}

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

sub apache_gid    { return $_[0]->{APACHE_GID};    }
sub apache_uid    { return $_[0]->{APACHE_UID};    }
sub code_path     { return $_[0]->{CODE_PATH};     }
sub conf_file     { return $_[0]->{CONF_FILE};     }
sub conf_path     { return $_[0]->{CONF_PATH};     }
sub install_path  { return $_[0]->{INSTALL_PATH};  }
sub prefix        { return $_[0]->{PREFIX};        }
sub session_path  { return $_[0]->{SESSION_PATH};  }
sub tmpl_path     { return $_[0]->{TMPL_PATH};     }
sub updates_path  { return $_[0]->{UPDATES_PATH};  }
sub socket_file   { return $_[0]->{SOCKET_FILE};   }
sub pid_file      { return $_[0]->{PID_FILE};      }
sub debug_dbd     { return $_[0]->{DEBUG_DBD};     }
sub debug_path    { return $_[0]->{DEBUG_PATH};    }
sub use_log4perl  { return $_[0]->{USE_LOG4PERL};  }
sub log4perl_conf { return $_[0]->{LOG4PERL_CONF}; }

1;

################################################################################
# Copyright (c) 2005-2010 Steven Edwards (maverick@smurfbane.org).  
# All rights reserved.
#
# You may use and distribute Apache::Voodoo under the terms described in the 
# LICENSE file include in this package. The summary is it's a legalese version
# of the Artistic License :)
#
################################################################################
