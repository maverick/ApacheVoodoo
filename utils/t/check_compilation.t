use Test::More tests => 11;
BEGIN { 
	use_ok('Apache::Voodoo');
	use_ok('Apache::Voodoo::Debug');
	use_ok('Apache::Voodoo::DisplayError');
	use_ok('Apache::Voodoo::Handler');
	use_ok('Apache::Voodoo::Loader');
	use_ok('Apache::Voodoo::Loader::Dynamic');
	use_ok('Apache::Voodoo::Loader::Static');
	use_ok('Apache::Voodoo::Pager');
	use_ok('Apache::Voodoo::ServerConfig');
	use_ok('Apache::Voodoo::Table');
	use_ok('Apache::Voodoo::Zombie');
};
