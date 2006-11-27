=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Install::Config

=head1 VERSION

$Id$

=head1 SYNOPSIS

This object is used by Voodoo internally by "voodoo-control setconfig".

=cut ###########################################################################
package Apache::Voodoo::Install::Config;

use strict;
use warnings;

# There doesn't seem to be another "user input prompt" mechanism installed
# by default other that this one.  Seems kinda strange to have to use an
# object designed for make file creation for this...oh well.
use ExtUtils::MakeMaker qw{ prompt };
use Data::Dumper;

$Data::Dumper::Indent=1;
$Data::Dumper::Terse=1;

sub new {
	my $class = shift;
	my %params = @_;

	my $self = {};
	if (defined($params{PREFIX})) {
		# take whatever is supplied
		foreach (keys %params) {
			$self->{$_} = $params{$_};
		}
	}

	bless ($self,$class);

	return $self;
}

sub do_config_setup {
	my $self = shift;


	# get settings
	$self->prefix();
	$self->install_path();
	$self->session_path();
	$self->conf_path();
	$self->updates_path();
	$self->conf_file();
	$self->tmpl_path();
	$self->code_path();
	$self->apache_uid();
	$self->apache_gid();

	# FIXME: save settigs
	my %cfg = %{$self};

	my $path = $INC{"Apache/Voodoo/MyConfig.pm"} || $INC{"Apache/Voodoo/Install/Config.pm"};
	$path =~ s/Install\/Config.pm$/MyConfig\.pm/;

	open(OUT,">$path") || die "Can't write to $path: $!";
	print OUT <<'HEADER';
=pod ###########################################################################

=head1 NAME

Apache::Voodoo::MyConfig

=head1 SYNOPSIS

Installation specific settings for Apache Voodoo are stored here.  Do not edit this file
directly; use the supplied "voodoo-control" program instead.

=cut ###########################################################################
package Apache::Voodoo::MyConfig;

HEADER

	print OUT '$CONFIG = '. Dumper(\%cfg).";\n";

	print OUT <<'FOOTER';

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
FOOTER

	close(OUT);
	print "\n\nSetting saved\n";
}

sub prefix {
	my $self = shift;

	unless ($self->{PREFIX}) {
		# test some of the common apache install locations to come up with a sensible default.
		foreach ("/data/apache","/usr/local/apache","/etc/apache/") {
			if (-e $_ && -d $_) {
				$self->{PREFIX} = $_;
				last;
			}
		}
	}

	while (1) {
		my $ans = prompt("Apache Prefix Path",$self->{PREFIX});
		$ans =~ s/\/$//;

		if (-e $ans && -d $ans) {
			$self->{PREFIX} = $ans;
			last;
		}

		print "That directory doesn't exist.  Please try again.\n";
	}
}

sub install_path {
	my $self = shift;

	unless ($self->{INSTALL_PATH}) {
		$self->{INSTALL_PATH} = $self->{PREFIX} . "/sites";
	}

	$self->{INSTALL_PATH} = prompt("App Install Path",$self->{INSTALL_PATH});
	$self->{INSTALL_PATH} =~ s/\/$//;
}

sub session_path {
	my $self = shift;
	
	unless ($self->{SESSION_PATH}) {
		$self->{SESSION_PATH} = $self->{PREFIX} . "/session";
	}

	$self->{SESSION_PATH} = prompt("Session Path",$self->{SESSION_PATH});
	$self->{SESSION_PATH} =~ s/\/$//;
}

sub conf_path {
	my $self = shift;
	
	unless ($self->{CONF_PATH}) {
		$self->{CONF_PATH} = "etc";
	}

	$self->{CONF_PATH} = prompt("Config File Path (relative to App Install Path)",$self->{CONF_PATH});
	$self->{CONF_PATH} =~ s/\/$//;
}

sub conf_file {
	my $self = shift;
	
	unless ($self->{CONF_FILE}) {
		$self->{CONF_FILE} = "etc/voodoo.conf";
	}

	$self->{CONF_FILE} = prompt("Config File Name (relative to App Install Path)",$self->{CONF_FILE});
	$self->{CONF_FILE} =~ s/\/$//;
}

sub updates_path {
	my $self = shift;
	
	unless ($self->{UPDATES_PATH}) {
		$self->{UPDATES_PATH} = "etc/updates";
	}

	$self->{UPDATES_PATH} = prompt("Update File Path (relative to App Install Path)",$self->{UPDATES_PATH});
	$self->{UPDATES_PATH} =~ s/\/$//;
}

sub tmpl_path {
	my $self = shift;
	
	unless ($self->{TMPL_PATH}) {
		$self->{TMPL_PATH} = "html";
	}

	$self->{TMPL_PATH} = prompt("Template File Path (relative to App Install Path)",$self->{TMPL_PATH});
	$self->{TMPL_PATH} =~ s/\/$//;
}

sub code_path {
	my $self = shift;
	
	unless ($self->{CODE_PATH}) {
		$self->{CODE_PATH} = "code";
	}

	$self->{CODE_PATH} = prompt("Perl Module Path (relative to App Install Path)",$self->{CODE_PATH});
	$self->{CODE_PATH} =~ s/\/$//;
}

sub apache_uid {
	my $self = shift;

	my $default = "apache";
	if ($self->{'APACHE_UID'}) {
		my $d = (getpwuid($self->{APACHE_UID}))[0];
		$default = $d if ($d);
	}

	while (1) {
		my $apache = prompt("User that Apache runs as",$default);
		my (undef,undef,$uid,undef) = getpwnam($apache);
		if ($uid =~ /^\d+$/) {
			$self->{'APACHE_UID'} = $uid;
			last;
		}
		print "Can't find this user.  Please try again.\n";
	}
}

sub apache_gid {
	my $self = shift;

	my $default = "apache";
	if ($self->{'APACHE_GID'}) {
		my $d = (getgrgid($self->{APACHE_GID}))[0];
		$default = $d if ($d);
	}

	while (1) {
		my $apache = prompt("Group that Apache runs as",$default);
		my (undef,undef,undef,$gid) = getpwnam($apache);
		if ($gid =~ /^\d+$/) {
			$self->{'APACHE_GID'} = $gid;
			last;
		}
		print "Can't find this group.  Please try again.\n";
	}
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
