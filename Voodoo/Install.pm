=pod ################################################################################

=head1 NAME

Apache::Voodoo::Install - Contains Apache installation path information extracted from apxs at install time

=head1 SYNOPSIS

	use Apache::Voodoo::Install;

	# Apache installation prefix (server root)
	print $Apache::Voodoo::Install::PREFIX,"\n";

	# Apache bin directory (where apxs, apachectl, and the like resite)
	print $Apache::Voodoo::Install::SBINDIR,"\n";

	# Apache configuration file directory (usually PREFIX/conf)
	print $Apache::Voodoo::Install::SYSCONFDIR,"\n";

=cut ###########################################################################
package Apache::Voodoo::Install;

use strict;
use Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
	get_prefix
	get_confdir
	get_bindir
	setup_symlink
	make_writeable_dirs
	parse_version
);

my $PREFIX     = "/data/apache";
my $SYSCONFDIR = "/data/apache/conf";
my $SBINDIR    = "/data/apache/bin";

sub get_prefix  { return $PREFIX;     }
sub get_confdir { return $SYSCONFDIR; }
sub get_bindir  { return $SBINDIR;    }

sub setup_symlink {
	my $source  = shift;
	my $target  = shift;
	my $pretend = shift;

	print "- Checking symlink $target: ";

	lstat($target);
	if (-e _ && -l _ ) {
		# it's there and it's a link, let's make sure it points to the correct place.
		my @ss = stat($target);
		my @ts = stat($source);
		if ($ss[1] != $ts[1]) {
			# inode's are different.
			$pretend || unlink($target) || die "Can't remove bogus link: $!";
			$pretend || symlink($source,$target) || die "Can't create symlink: $!";
			print "invalid, fixed\n";
		}
		else {
			print "ok\n";
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
		print "missing, created\n";
	}
}

sub make_writeable_dirs {
	my $dirs     = shift;
	my $apache   = shift;
	my $pretend  = shift;

	my (undef,undef,$uid,$gid) = getpwnam($apache) or die "Can't find password entry for $apache";

	foreach my $dir (@{$dirs}) {
		print "- Checking directory $dir: ";
		stat($dir);
		if (-e _ && -d _ ) {
			print "ok\n";
		}
		else {
			$pretend || mkdir($dir,770) or die "Can't create attachments directory: $!";
			print "created\n";
		}
		print "- Making sure the $dir directory is writable by apache: ";
		$pretend || chown($uid,$gid,$dir) or die "Can't chown directory: $!";
		$pretend || chmod(0770,$dir)      or die "Can't chmod directory: $!";
		print "ok\n";
	}
}

sub parse_version {
	my $v = shift;

	if ($v =~ /^SVN:\s*/) {
		# Looks like a Subversion HeadURL
 		$v =~ s/SVN:\s*//;
	        $v =~ s!^.*svn://[^/]*/[^/]+/!!;
                $v =~ s!^branch/!!;
                $v =~ s!^release/!!;
                $v =~ s/\/.*$//;
      	}
	# If it doesn't look like one of the above, we'll just treat is as the actual version number.
	return $v;
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
