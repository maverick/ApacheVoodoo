=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Install::Updater

=head1 SYNOPSIS

This package provides the methods that do pre/post/upgrade commands as specified
by the various .xml files in an application.

=cut ###########################################################################
package Apache::Voodoo::Install::Distribution;

use strict;
use warnings;

use base("Apache::Voodoo::Install");

use Apache::Voodoo::Constants;

use Config::General;
use ExtUtils::Install;

sub new {
	my $class = shift;
	my %params = @_;

	my $self = {%params};

	$self->{'app_name'} = $self->{'distribution'};
	$self->{'app_name'} =~ s/\.tar\.(bz2|gz)$//i;
	$self->{'app_name'} =~ s/-.*$//;
	$self->{'app_name'} =~ s/.*\///;

	unless ($self->{'app_name'} =~ /^[a-z]\w*$/i) {
		die "ERROR: Distribution file names must follow the format: AppName-Version.tar.(gz|bz2)\n";
	}

	my $ac = Apache::Voodoo::Constants->new();

	$self->{'install_path'} = $ac->install_path()."/".$self->{'app_name'};

	$self->{'conf_file'}    = $self->{'install_path'}."/".$ac->conf_file();
	$self->{'conf_path'}    = $self->{'install_path'}."/".$ac->conf_path();
	$self->{'updates_path'} = $self->{'install_path'}."/".$ac->updates_path();
	$self->{'apache_uid'}   = $ac->apache_uid();
	$self->{'apache_gid'}   = $ac->apache_gid();

	bless $self,$class;

	return $self;
}


################################################################################
# Handles installer cleanup tasks.
################################################################################
sub cleanup {
	my $self = shift;

	if ($self->{'unpack_dir'}) {
		system("rm", "-rf", $self->{'unpack_dir'});
	}
}

################################################################################
# Unpacks a tar.gz to a temporary directory.
# Returns the path to the directory.
################################################################################
sub unpack_distribution {
	my $self = shift;
	my $file = shift;

	unless (-e $file && -f $file) {
		# no such file.
		print "ERROR: No such file or directory\n";
		exit;
	}

	my ($app_name,$app_version) = ($file =~ /(\w+)-([\w\.]+)\.tar\.gz$/);
	unless ($app_name && $app_version) {
		exit;
	}

	$self->{'install_path'} = $self->{'PREFIX'}."/sites/".$app_name;

	$self->{'app_name'} = $app_name;
	$self->{'app_version'} = $app_version;

	my $unpack_dir = "/tmp/av_unpack_$$";

	if (-e $unpack_dir) {
		print "ERROR: $unpack_dir already exists\n";
		exit;
	}

	mkdir($unpack_dir,0700) || die "Can't create directory $unpack_dir: $!";
	chdir($unpack_dir) || die "Can't change to direcotyr $unpack_dir: $!";
	$self->info("- Unpacking distribution to $unpack_dir");
	system("tar","xzf",$file) && die "Can't unpack $file: $!";

	$self->{'unpack_dir'} = $unpack_dir;

	return ($unpack_dir,$app_name);
}

################################################################################
# Checks for an existing installation of the app.  If it exists, it saves
# it's site specific config data, and returns it's version number.
################################################################################
sub check_existing {
	my $self = shift;

	my $app_name = $self->{'app_name'};

	$self->{'install_path'} = $self->{'PREFIX'}."/sites/".$app_name;
	my $install_path = $self->{'install_path'};

	my $old_version = 0;
	if (-e $install_path."/etc/$app_name.conf") {
		$self->info("Found one. We will be performing an upgrade");

		my $old_config = Config::General->new($install_path."/etc/$app_name.conf");
		my %old_cdata = $old_config->getall();

		# save old (maybe customized?) config variables
		foreach ('session_dir','devel_mode','shared_cache','debug','devel_mode','cookie_name','database') {
			$self->{'old_conf_data'}->{$_} = $old_cdata{$_};
		}

		$old_version = $self->parse_version($old_cdata{'version'});
		$self->{'old_version'} = $old_version;
		$self->info("Old Version determined to be: $old_version");

		my $dbhost = $old_cdata{'database'}->{'connect'};
		my $dbname = $old_cdata{'database'}->{'connect'};

		$dbhost =~ s/.*\bhost=//;
		$dbhost =~ s/[^\w\.-]+.*$//;

		$dbname =~ s/.*\bdatabase=//;
		$dbname =~ s/[^\w\.-]+.*$//;

		$self->{'dbhost'} ||= $dbhost;
		$self->{'dbname'} ||= $dbname;
		$self->{'dbuser'} ||= $old_cdata{'database'}->{'username'};
		$self->{'dbpass'} ||= $old_cdata{'database'}->{'password'};
	}
	else {
		$self->info("not found. This will be a fresh install.");
	}

	return $old_version;
}

sub check_distribution {
	my $self = shift;

	my $dir      = shift;
	my $app_name = shift;

	unless (-e $dir."/etc/$app_name.conf") {
		print "ERROR: install doesn't contain a configuration file at: $dir/etc/$app_name.conf\n";
		$self->cleanup;
		exit;
	}

	my $new_config = Config::General->new("$dir/etc/$app_name.conf");
	my %new_cdata = $new_config->getall();

	my $new_version = $self->parse_version($new_cdata{'version'});

	if ($self->{'app_version'}) {
		# unpacked directory
		if ($new_version != $self->{'app_version'}) {
			print "ERROR: Version from filename ($self->{'app_version'}) and version from config file ($new_version) don't agree.  aborting.\n";
			$self->cleanup;
			exit;
		}
	}
	else {
		$self->{'app_version'} = $new_version;
	}

	$self->mesg("Determined app version to be: $self->{'app_version'}");
}

sub update_conf_file {
	my $self = shift;

	my $install_path = $self->{'install_path'};
	my $app_name     = $self->{'app_name'};

	my $config = Config::General->new("$install_path/dir/etc/$app_name.conf");
	my %cdata = $config->getall();

	foreach (keys %{$self->{'old_conf_data'}}) {
		$self->debug("Merging config data: $_");
		$cdata{$_} = $self->{'old_conf_data'}->{$_};
	}

	$self->debug("Merging database config: $_");
	$cdata{'database'}->{'username'} = $self->{'dbuser'};
	$cdata{'database'}->{'password'} = $self->{'dbpass'};
	$cdata{'database'}->{'connect'} =~ s/\bdatabase=[^;"]+/database=$self->{'dbname'}/;
	$cdata{'database'}->{'connect'} =~ s/\bhost=[^;"]+/host=$self->{'host'}/;

	$self->{'pretend'} || $config->save_file;
}

sub install_files {
	my $self = shift;

	my $pretend      = $self->{'pretend'};
	my $unpack_dir   = $self->{'unpack_dir'};
	my $install_path = $self->{'install_path'};

	if ($self->{'verbose'} >= 0) {
		$self->mesg("\n* Preparing to install.  Press ctrl-c to abort *\n");
		$self->mesg("* Installing in ");
		foreach (5,4,3,2,1) {
			$self->mesg("$_");
			$self->{'pretend'} || sleep(1);
		}
		$self->mesg("\n");

		$self->mesg("- Installing files:");
	}

	$self->{'pretend'} || ExtUtils::Install::install({$unpack_dir => $install_path});
}
