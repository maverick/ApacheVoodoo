use Test::More tests => 3;
BEGIN { 
	use_ok('mod_perl_hooks');
};

BEGIN {
	use mod_perl_hooks;
	
	my %hooks = map { $_ => 1 } mod_perl::hooks;

	ok($hooks{'PerlHandler'}        == 1,'mod_perl has PerlHandler hook');
	ok($hooks{'PerlRestartHandler'} == 1,'mod_perl has PerlHandlerRestart hook');
}
