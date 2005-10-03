use 5.008000;
use ExtUtils::MakeMaker;
use Apache::MyConfig;

# figure out where apache in installed
my $APXS = $Apache::MyConfig::Setup{'APXS'};

my %paths;
my $filter;
foreach my $item (qw{PREFIX SBINDIR SYSCONFDIR}) {
	open(APXS,"$APXS -q $item |") || die "Can't get info from $APXS: $!";
	$paths{$item} = <APXS>;
	close(APXS);

}

# one would have though that this would have been a simple task for PM_FILTER, but alas,
# it is not.
open(OUT,"> Install.pm")                   || die "Can't open Install.pm for writing: $!";
open(IN, "< lib/Apache/Voodoo/Install.pm") || die "Can't open Install.pm for reading: $!";

while (<IN>) {
	    s/^\$PREFIX\s*=\s*['"][\w\/\-]*['"]\s*;\s*$/\$PREFIX     = '$paths{PREFIX}';\n/;
	   s/^\$SBINDIR\s*=\s*['"][\w\/\-]*['"]\s*;\s*$/\$SBINDIR    = '$paths{SBINDIR}';\n/;
	s/^\$SYSCONFDIR\s*=\s*['"][\w\/\-]*['"]\s*;\s*$/\$SYSCONFDIR = '$paths{SYSCONFDIR}';\n/;

	print OUT;
}
close(IN);
close(OUT);
unlink('lib/Apache/Voodoo/Install.pm');
rename('Install.pm','lib/Apache/Voodoo/Install.pm');

WriteMakefile(
	NAME          => 'Apache::Voodoo',
	VERSION_FROM  => 'lib/Apache/Voodoo/Handler.pm',
	PREREQ_PM     => {
		Apache::DBI      => 0.94,
		Apache::Session  => 1.6,
		Config::General  => 2.27,
		Email::Valid     => 0.15,
		HTML::Template   => 2.7,
		IPC::Shareable   => 0.6,
		IPC::SharedCache => 1.3,
		Time::HiRes      => 1.65,
		Apache::Request  => 1.33,
		File::Pid        => 0,
		# Apache::Admin::Config => 0.92
	},
	(
		$] >= 5.008 ?
		(ABSTRACT_FROM => 'lib/Apache/Voodoo.pod', # retrieve abstract from module
		AUTHOR         => 'Maverick Edwards <maverick@smurfbane.org>') : ()
	),
	INSTALLSCRIPT => $paths{'SBINDIR'},
	EXE_FILES => ['bin/voodoo-control'],
	PM_FILTER => $filter
);

################################################################################
# Copyright (c) 2005 Steven Edwards.  All rights reserved.
################################################################################
