use 5.008000;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME         => 'Apache::Voodoo',
	VERSION_FROM => 'lib/Apache/Voodoo/Handler.pm',
	PREREQ_PM    => {
		Apache::DBI      => 0,
		Apache::Session  => 0,
		Config::General  => 0,
		Email::Valid     => 0,
		HTML::Template   => 0,
		IPC::Shareable   => 0,
		IPC::SharedCache => 0,
		Time::HiRes      => 0
	},
	(
		$] >= 5.008 ?
		(ABSTRACT_FROM => 'lib/Apache/Voodoo.pod', # retrieve abstract from module
		AUTHOR         => 'Maverick Edwards <maverick@smurfbane.org>') : ()
	),
);

################################################################################
# Copyright (c) 2005 Steven Edwards.  All rights reserved.
################################################################################
