=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Constants - Convience object that stores the various constants
used by Voodoo

=head1 VERSION

$Id$

=head1 SYNOPSIS

This object is used by Voodoo internally.

=head1 OUTPUT

=cut ###########################################################################
package Apache::Voodoo::Constants;

$VERSION = '1.20';

use strict;
use Apache::MyConfig;

# Different install methods yield different configurations.  I know of two so far.
# 1) call APXS to find out where the apache prefix is.  (gentoo, rpms?)
# 2) apache prefix is listed directly in A::MC (apachetoolbox, source?)
#
# If eithers yields the wrong path on your system, you can provide the correct value here.
my $PREFIX = undef;

#
# Here are the variables which control where Apache::Voodoo looks for things.
# It should not be necessary to change these unless you *REALLY* just want the
# layout to be different.
#

# $PREFIX relative unless they being with a /
my $AV_INSTALL_PATH = "sites";
my $AV_SESSION_PATH = "session";

# relative to the site installation path
my $AV_CONF_PATH    = "etc";
my $AV_UPDATES_PATH = "etc/updates";
my $AV_CONF_FILE    = "etc/voodoo.conf";
my $AV_TMPL_PATH    = "html";
my $AV_CODE_PATH    = "code";

# yep.  It's a singleton
my $self = undef;

sub new {
	my $class = shift;

	if (defined($self)) {
		return $self;
	}

	$self = {};
	bless($self,$class);

	#FIXME determine apache username automatically
	my $APACHE = 'apache';
	my (undef,undef,$uid,$gid) = getpwnam($APACHE) or die "Can't find password entry for $APACHE";

	$self->{'apache_uid'} = $uid;
	$self->{'apache_gid'} = $gid;

	unless ($PREFIX) {
		# User hasn't supplied/overridden them so we'll figure out where apache is installed.
		# Originally I had the Makefile hard code this, but later realized that this made distributed 
		# development kind of tricky and meant than any alterations to the apache setup paths post
		# install would break things.

		if ($Apache::MyConfig::Setup{'USE_APXS'} == 1) {
			$PREFIX = _ask_apxs('PREFIX');	
		}
		elsif (length($Apache::MyConfig::Setup{'APACHE_PREFIX'}) > 0) {
			$PREFIX = $Apache::MyConfig::Setup{'APACHE_PREFIX'};
		}
		else {
			die "Can't determine where Apache is installed. Please define it in Apache::Voodoo::Constants\n";
		}
	}

	$AV_INSTALL_PATH = $PREFIX."/".$AV_INSTALL_PATH unless $AV_INSTALL_PATH =~ /^\//;
	$AV_SESSION_PATH = $PREFIX."/".$AV_SESSION_PATH unless $AV_SESSION_PATH =~ /^\//;

	return $self;
}

sub prefix     { return $PREFIX;     }

sub install_path { return $AV_INSTALL_PATH; }
sub session_path { return $AV_SESSION_PATH; }
sub conf_path    { return $AV_CONF_PATH;    }
sub updates_path { return $AV_UPDATES_PATH; }
sub conf_file    { return $AV_CONF_FILE;    }
sub tmpl_path    { return $AV_TMPL_PATH;    }
sub code_path    { return $AV_CODE_PATH;    }

sub apache_uid   { return $_[0]->{'apache_uid'} };
sub apache_gid   { return $_[0]->{'apache_gid'} };

sub _ask_apxs {
	my $param = shift;

	my $APXS = $Apache::MyConfig::Setup{'APXS'};
	open(APXS,"$APXS -q $param |") || die "Can't get info from $APXS: $!";
	my $item = <APXS>;
	close(APXS);
	return $item;
}

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
