use Test::More tests => 4;
BEGIN { 
	use_ok('Apache::Voodoo'),
	use_ok('Apache::Voodoo::Handler'),
	use_ok('Apache::Voodoo::Pager'),
	use_ok('Apache::Voodoo::Table')
};
