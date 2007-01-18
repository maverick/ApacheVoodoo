use 5.008000;
use ExtUtils::MakeMaker;

my %required_modules = (
		Apache::DBI          => 0.94,
		Apache::Session      => 1.6,
		Config::General      => 2.27,
		Digest::MD5          => 2.36,
		Email::Valid         => 0.15,
		File::Pid            => 0,
		HTML::Template       => 2.7,
		IPC::Shareable       => 0.6,
		IPC::SharedCache     => 1.3,
		Time::HiRes          => 1.65,
		XML::Checker::Parser => 0,
		# Apache::Admin::Config => 0.92
);

eval {
	require "mod_perl2.pm";
};
if ($@) {
	eval {
		require "mod_perl.pm";
	};

	if ($@) {
		die "Can't find mod_perl.pm or mod_perl2.pm.  Do you have mod_perl installed?";
	}
}

print STDERR "mod_perl version $mod_perl::VERSION found...\n";
if ($mod_perl::VERSION >= 1.99) {
	print STDERR "Adding prequisites for the Version 2 API...\n";
	$required_modules{Apache2::Request} = 0;
}
else {
	print STDERR "Adding prequisites for the Version 1 API...\n";
	$required_modules{Apache::Request} = 1.33;
}


WriteMakefile(
	NAME          => 'Apache::Voodoo',
	VERSION_FROM  => 'lib/Apache/Voodoo/Handler.pm',
	PREREQ_PM     => \%required_modules,
	(
		$] >= 5.008 ?
		(ABSTRACT_FROM => 'lib/Apache/Voodoo.pod', # retrieve abstract from module
		AUTHOR         => 'Maverick Edwards <maverick@smurfbane.org>') : ()
	),
	INSTALLSCRIPT => $paths{'SBINDIR'},
	EXE_FILES => ['bin/voodoo-control']
	# PM_FILTER => $filter
);

################################################################################
# Copyright (c) 2005 Steven Edwards.  All rights reserved.
################################################################################
