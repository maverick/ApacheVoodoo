=pod ################################################################################

=head1 NAME

Apache::Voodoo::Installer

=head1 SYNOPSIS

This package provides the methods that do the real installation behind the scenes
installation work that voodoo-control provides.

=cut ###########################################################################
package Apache::Voodoo::Installer;

$VERSION = '1.14';

use strict;
use warnings;

use Apache::MyConfig;
use CPAN::Config;
use CPAN;
use Config::General;
use DBI;
use Data::Dumper;
use ExtUtils::Install;
use File::Find;
use File::Pid;
use Sys::Hostname;
use XML::Checker::Parser;

use Data::Dumper;

# make CPAN download dependancies
$CPAN::Config->{'prerequisites_policy'} = 'follow';

sub new {
	my $class = shift;
	my %params = @_;

	my $self = {};

	bless $self, $class;

	$self->{'verbose'} = 0;

	#FIXME determine apache username automatically
	my $APACHE = 'apache';
	my (undef,undef,$uid,$gid) = getpwnam($APACHE) or die "Can't find password entry for $APACHE";

	$self->{'apache_uid'} = $uid;
	$self->{'apache_gid'} = $gid;

	my $APXS = '[no used]';
	unless ($params{'PREFIX'} && $params{'SBINDIR'} && $params{'SYSCONFDIR'}) {
		# User hasn't supplied/overridden them so we'll figure out where apache is installed.

		# Originally I had the Makefile hard code this, but later realized that this made distributed 
		# development kind of tricky and meant than any alterations to the apache setup paths post
		# install would break things.
		$APXS = $Apache::MyConfig::Setup{'APXS'};

		foreach my $item (qw{PREFIX SBINDIR SYSCONFDIR}) {
			open(APXS,"$APXS -q $item |") || die "Can't get info from $APXS: $!";
			$self->{$item} = <APXS>;
			close(APXS);
		}
	}


	# we do this below the apache uid/gid setup to allow the user to override it in the constructor.
	foreach (keys %params) {
		$self->{$_} = $params{$_};
	}

	if (!$self->{'pretend'} && $<) {
		print "\nSetup must be ran as root.\n\n";
		exit;
	}

	if ($self->{'pretend'}) {
		$self->mesg("== Pretending to run ==");
	}

	$self->{'pid'} = File::Pid->new();
	my $id = $self->{'pid'}->running;
	if ($id) {
		print "ERROR: Already Running ($id)\n";
		exit;
	}

	unless ($self->{'pid'}->write) {
		die "ERROR: Couldn't write pid: $!";
	}

	$self->debug("APXS: $APXS");
	$self->debug("PREFIX: $self->{'PREFIX'}");
	$self->debug("SBINDIR: $self->{'SBINDIR'}");
	$self->debug("SYSCONFDIR: $self->{'SYSCONFDIR'}");

	return $self;
}

sub _printer {
	my $self  = shift;
	my $level = shift;

	if ($self->{'verbose'} >= $level) {
		foreach (@_) {
			if (ref($_)) {
				print Dumper $_;
			}
			else {
				print $_,"\n";
			}
		}
	}
}

sub mesg {
	my $self = shift;
	$self->_printer(0,@_);
}

sub info {
	my $self = shift;
	$self->_printer(1,@_);
}

sub debug {
	my $self = shift;
	$self->_printer(2,@_);
}

################################################################################
# Handles installer cleanup tasks.
################################################################################
sub cleanup {
	my $self = shift;

	if ($self->{'unpack_dir'}) {
		system("rm", "-rf", $self->{'unpack_dir'});
	}

	$self->{'pid'}->remove;
}

################################################################################
# Accessor methods
################################################################################
sub get_prefix  { return $_[0]->{'PREFIX'};     }
sub get_confdir { return $_[0]->{'SYSCONFDIR'}; }
sub get_bindir  { return $_[0]->{'SBINDIR'};    }

################################################################################
# Sets / unsets the 'pretend' run mode
################################################################################
sub pretend {
	my $self = shift;
	$self->{'pretend'} = shift;
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
		print "ERROR: Distribution file names must follow the format: AppName-Version.tar.gz\n";
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

sub post_setup_checks {
	my $self = shift;

	my $install_path = $self->{'install_path'};
	my $app_name     = $self->{'app_name'};

	my $conf_dir = $self->{'SYSCONFDIR'}."/voodoo";

	$self->info("- Checking symlinks:");
	unless (-e $conf_dir) {
		mkdir($conf_dir,0700) || die "Can't create $conf_dir: $!";
	}

	$self->make_symlink("$install_path/etc/$app_name.conf","$conf_dir/$app_name.conf");
	$self->make_symlink("$install_path/code",$self->{'PREFIX'}."/lib/perl/$app_name");

	$self->info("- Checking session directory:");
	# $self->make_writeable_dirs($new_cdata{'session_dir'});
}

sub make_symlink {
	my $self    = shift;
	my $source  = shift;
	my $target  = shift;

	my $pretend = $self->{'pretend'};

	$self->info("- Checking symlink $target");

	lstat($target);
	if (-e _ && -l _ ) {
		# it's there and it's a link, let's make sure it points to the correct place.
		my @ss = stat($target);
		my @ts = stat($source);
		if ($ss[1] != $ts[1]) {
			# inode's are different.
			$pretend || unlink($target) || die "Can't remove bogus link: $!";
			$pretend || symlink($source,$target) || die "Can't create symlink: $!";
			$self->debug(": invalid, fixed");
		}
		else {
			$self->debug(": ok");
		}
	}
	else {
		# not there, or not a link.	

		# make sure the path is valid
		my $p;
		my @p = split('/',$target);
		pop @p; # throw away filename
		foreach my $d (@p) {
			$p .= '/'.$d;
			unless (-e $p && -d $p) {
				$pretend || mkdir ($p,0755) || die "Can't create directory: $!";
			}
		}

		$pretend || unlink($target);	# in case it was there.

		$pretend || symlink($source,$target) || die "Can't create symlink: $!";
		$self->debug(": missing, created");
	}
}

sub make_writeable_dirs {
	my $self = shift;
	my @dirs = shift;

	my $pretend = $self->{'pretend'};
	my $uid     = $self->{'apache_uid'};
	my $gid     = $self->{'apache_gid'};

	foreach my $dir (@dirs) {
		$self->info("- Checking directory $dir");
		stat($dir);
		if (-e _ && -d _ ) {
			$self->debug(": ok");
		}
		else {
			$pretend || mkdir($dir,770) or die "Can't create directory $dir: $!";
			$self->debug(": created");
		}
		$self->info("- Making sure the $dir directory is writable by apache");
		$pretend || chown($uid,$gid,$dir) or die "Can't chown directory: $!";
		$pretend || chmod(0770,$dir)      or die "Can't chmod directory: $!";
		$self->debug(": ok");
	}
}

sub make_writeable_files {
	my $self  = shift;
	my @files = shift;

	my $pretend = $self->{'pretend'};
	my $uid     = $self->{'apache_uid'};
	my $gid     = $self->{'apache_gid'};

	foreach my $file (@files) {
		$self->info("- Checking file $file");
		if (-e $file) {
			$self->debug(": ok");
		}
		else {
			$pretend || (system("touch $file") && die "Can't create file: $!");
			$self->debug(": created");
		}
		$self->info("- Making sure the $file directory is writable by apache");
		$pretend || chown($uid,$gid,$file) or die "Can't chown file: $!";
		$pretend || chmod(0600,$file)      or die "Can't chmod file: $!";
		$self->debug(": ok");
	}
}

sub parse_version {
	my $self = shift;
	my $ver  = shift;

	if ($ver =~ /^SVN:\s*/) {
		# Looks like a Subversion HeadURL
 		$ver =~ s/SVN:\s*//;
		$ver =~ s!^.*svn://[^/]*/[^/]+/!!;
		$ver =~ s!^branch/!!;
		$ver =~ s!^release/!!;
		$ver =~ s/\/.*$//;
	}

	# If it doesn't look like one of the above, we'll just treat is as the actual version number.
	return $ver;
}

sub find_updates {
	my $self = shift;
	my $path = shift;

	my @updates;
	find({
			wanted => sub {
				my $file = $_;
				if ($file =~ /\d+\.\d+\.\d+(-[a-z\d]+)?\.xml$/) {
					push(@updates,$file);
				}
			},
			no_chdir => 1
		},
		$path
	);

	return @updates;
}

sub sort_updates {
	my $self = shift;

	# Swartzian transform
	return map { 
		$_->[0]
	}
	sort { 
		$a->[1] <=> $b->[1] || 
		$a->[2] <=> $b->[2] ||
		$a->[3] <=> $b->[3] ||
		defined($b->[4]) <=> defined($a->[4]) ||
		$a->[4] cmp $b->[4]
	}
	map {
		my $f = $_;
		s/.*\///;
		s/\.xml$//;
		[ $f , split(/[\.-]/,$_) ]
	}
	@_;
}

sub prepare_setup_commands {
	my $self = shift;

	my $unpack_dir = $self->{'unpack_dir'};

	$self->mesg("- Looking for setup/update command xml files");
	my @comm_sets;

	if (-e "$unpack_dir/etc/pre-setup.xml") {
		$self->debug("    pre-setup.xml");
		push(@comm_sets,{file => "$unpack_dir/etc/pre-setup.xml"});
	}

	if ($self->{'old_version'}) {
		my @updates = $self->sort_updates($self->find_updates($unpack_dir.'/etc/updates'));

		# bleh.  I'm replicated a good chunk of the sort_updates routine.
		# maybe they need to be combined somehow?
		my $keep = 0;
		my @oldv = split(/[\.-]/,$self->{'old_version'});
		my @newv = split(/[\.-]/,$self->{'app_version'});
		foreach my $file (@updates) {
			my $v = $file;
			$v =~ s/.*\///;
			$v =~ s/\.xml//;
			my @v = split(/[\.-]/,$v);

				if ($v[0] >= $newv[0] &&
				$v[1] >= $newv[1] &&
				$v[2] >= $newv[2] &&
				(!defined($newv[3]) || $v[3] ge $newv[3])) {

				# this one is too new
				$keep = 2;
			}
			
			print "    $v";
			if ($keep == 0) {
				$self->debug(" (skipped. already applied)");
			}
			elsif ($keep == 1) {
				push(@comm_sets,{file => $file});
			}
			elsif ($keep == 2) {
				$self->debug(" (skipped. too new)");
			}
			print "\n";

			if ($keep == 0 &&
				$v[0] >= $oldv[0] &&
				$v[1] >= $oldv[1] &&
				$v[2] >= $oldv[2] &&
				(!defined($v[3]) || $v[3] ge $oldv[3])) {

				# we've skipped all the old ones
				$keep = 1;
			}
		}
	}
	else {
		if (-e "$unpack_dir/etc/setup.xml") {
			$self->debug("    setup.xml");
			push(@comm_sets,{file => "$unpack_dir/etc/setup.xml"});
		}
	}

	if (-e "$unpack_dir/etc/post-setup.xml") {
		$self->debug("    post-setup.xml");
		push(@comm_sets,{file => "$unpack_dir/etc/post-setup.xml"});
	}

	print "- Parsing files:\n";

	for (my $i=0; $i <= $#comm_sets; $i++) {
		my $data = $self->parse_xml($comm_sets[$i]->{'file'});

		if (!defined($data)) {
			print "\n* Parse of $comm_sets[$i]->{'file'} failed. Aborting *\n";
			exit;
		}
		print "    parsed $comm_sets[$i]->{'file'}\n";
		$comm_sets[$i]->{'commands'} = $data;
	}

	$self->{'comm_sets'} = \@comm_sets;
	return \@comm_sets;
}

sub parse_xml {
	my $self    = shift;
	my $xmlfile = shift;

	my $parser = new XML::Checker::Parser(
		'Style' => 'Tree',
		'SkipInsignifWS' => 1
	);

	my $dtdpath = $INC{'Apache/Voodoo/Install.pm'};
	$dtdpath =~ s/Install\.pm$//;

	$parser->set_sgml_search_path($dtdpath);

	my $data;
	eval {
			# parser checker only dies on catastrophic errors.  Adding this handler
			# makes it die on ALL errors.
			local $XML::Checker::FAIL = sub {
				my $errcode = shift;

				print "\n ** Parse of $xmlfile failed **\n";
				die XML::Checker::error_string ($errcode, @_) if $errcode < 200;
				XML::Checker::print_error ($errcode, @_);
			};

			$data = $parser->parsefile($xmlfile);
	};
	if ($@) {
			print $@;
			return undef;
	}
	return $data;

}

sub execute_setup_commands {
	my $self = shift;

	my $pretend      = $self->{'pretend'};
	my $install_path = $self->{'install_path'};

	chdir($install_path);

	# find out what our hostname is
	my $hostname = Sys::Hostname::hostname();

	$self->info("- Running setup/update commands");
	foreach (@{$self->{'comm_sets'}}) {
		$self->debug("    $_->{'file'}");

		# drop first tags (they're always empty)
		my (undef,@commands) = @{$_->{'commands'}->[1]};

		for (my $i=0; $i < $#commands; $i+=2) {
			my $type = $commands[$i];
			my $data = $commands[$i+1]->[2];

			if (defined($commands[$i+1]->[0]->{'onhosts'})) {
				next unless grep { /^$hostname$/ } split(/\s*,\s*/,$commands[$i+1]->[0]->{'onhosts'});
			}

			$data =~ s/^\s*//;
			$data =~ s/\s*$//;

			#$data =~ s/\$DBHOST/$dbhost/g;
			#$data =~ s/\$DBNAME/$dbname/g;
			#$data =~ s/\$DBUSER/$dbuser/g;
			#$data =~ s/\$DBPASS/$dbpass/g;

			if ($type eq "shell") {
				$self->debug("        SHELL: ", $data);
				$pretend || (system($data) && die "Shell command failed: $!");
			}
			elsif ($type eq "sql") {
				$self->debug("        SQL: ", $data);
				next if $pretend;

				if ($data =~ /^source\s/i) {
					$data =~ s/^source\s*//i;

					my ($query,$in_quote,$close_quote);
					open(SQL,"$install_path/$data") || die "Can't open $install_path/$data: $!";
					while (!eof(SQL)) {
						my $c = getc SQL;
						if (!$in_quote && $c eq ';') {
							next if ($query =~ /^[\s;]*$/); # an empty query turns a do into a don't
							#$dbh->do($query) || die "sql source failed $query: ".DBI->errstr;
							$query = '';
							$c = getc SQL;
						}

						if ($c eq '\\') {
							$query .= $c;
							$c = getc SQL;  # automatically add the next character
						}
						elsif ($c eq "'") {
							if ($in_quote && $close_quote eq "'") {
								$in_quote = 0;
								$close_quote = '';
							}
							elsif (!$in_quote) {
								$in_quote = 1;
								$close_quote = "'";
							}
						}
						elsif ($c eq '"') {
							if ($in_quote && $close_quote eq '"') {
								$in_quote = 0;
								$close_quote = '';
							}
							elsif (!$in_quote) {
								$in_quote = 1;
								$close_quote = '"';
							}
						}

						$query .= $c;
					}
					close(SQL);
				}
				else {
					#$dbh->do($data) || die "sql failed: DBI->errstr";
				}
			}
			elsif ($type eq "mkdir") {
				$self->debug("        MKDIR: ", $data);
				$self->make_writeable_dirs("$install_path/$data");
			}
			elsif ($type eq "mkfile") {
				$self->debug("        TOUCH/CHMOD: ", $data);
				$self->make_writeable_files("$install_path/$data");
			}
			elsif ($type eq "install") {
				$self->debug("        CPAN Install: ", $data);
				unless ($pretend) {
					CPAN::Shell->install($data);
				}
			}
			else {
				print "\n* Unsupported command type ($type). Aborting *\n";
				exit;
			}
		}
	}
}

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
