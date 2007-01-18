use Test::More tests => 22;

use_ok('Apache::Voodoo');
use_ok('Apache::Voodoo::Constants');
use_ok('Apache::Voodoo::Debug');
use_ok('Apache::Voodoo::DisplayError');
use_ok('Apache::Voodoo::Handler');
use_ok('Apache::Voodoo::Install');
use_ok('Apache::Voodoo::Install::Config');
use_ok('Apache::Voodoo::Install::Distribution');
use_ok('Apache::Voodoo::Install::Pid');
use_ok('Apache::Voodoo::Install::Post');
use_ok('Apache::Voodoo::Install::Updater');
use_ok('Apache::Voodoo::Loader');
use_ok('Apache::Voodoo::Loader::Dynamic');
use_ok('Apache::Voodoo::Loader::Static');
use_ok('Apache::Voodoo::MP');
use_ok('Apache::Voodoo::Pager');
use_ok('Apache::Voodoo::ServerConfig');
use_ok('Apache::Voodoo::Table');
use_ok('Apache::Voodoo::Theme');
use_ok('Apache::Voodoo::ValidURL');
use_ok('Apache::Voodoo::Zombie');

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

if ($mod_perl::VERSION >= 1.99) {
	use_ok('Apache::Voodoo::MP::V2');
}
else {
	use_ok('Apache::Voodoo::MP::V1');
}
