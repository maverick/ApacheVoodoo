use 5.008000;
use ExtUtils::MakeMaker;

my %required_modules = (
	# voodoo-control uses CPAN under the hood to do some of it's work which is why it's listed here.
	CPAN	             => 1.9205,	
	Apache::Session      => 1.6,
	Config::General      => 2.27,
	Devel::StackTrace    => 1.20,
	Digest::MD5          => 2.36,
	Email::Valid         => 0.15,
	Exception::Class     => 1.26,
	Exception::Class::DBI=> 1.00,
	File::Pid            => 1.01,
	HTML::Template       => 2.7,
	IO::Handle::Record   => 0.13,
	IPC::SharedCache     => 1.3,
	Daemon::Generic      => 0.51,
	Proc::UID            => 0.05,
	Time::HiRes          => 1.65,
	XML::Checker::Parser => 0
);

eval {
	require "mod_perl2.pm";
};
if ($@) {
	eval {
		require "mod_perl.pm";
	};
}

print STDERR "mod_perl version: $mod_perl::VERSION\n";
if ($mod_perl::VERSION >= 1.99) {
	print STDERR "Adding prequisites for mod_perl Version 2 API...\n";
	$required_modules{Apache2::Request} = 2.08;
	$required_modules{Apache2::Cookie}  = 2.08;
}
elsif ($mod_perl::VERSION > 0) {
	print STDERR "Adding prequisites for mod_perl Version 1 API...\n";
	$required_modules{Apache::Request} = 1.33;
	$required_modules{Apache::Cookie}  = 0;
}
else {
	# I'd much rather do something else here besides guess; but prompting 
	# or dying seems to make the CPAN auto tester unhappy.
	print STDERR "==WARNING== \n";
	print STDERR "Can't find mod_perl.pm or mod_perl2.pm. I'm going to assume you're running Apache 2.X\n";
	print STDERR "==WARNING==\n\n";
	$required_modules{Apache2::Request} = 0;
}


WriteMakefile(
	NAME          => 'Apache::Voodoo',
	VERSION_FROM  => 'lib/Apache/Voodoo.pm',
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
