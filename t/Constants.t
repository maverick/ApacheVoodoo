use strict;
use warnings;

use Test::More tests => 16;

use_ok('Apache::Voodoo::Constants') || 
	BAIL_OUT("Can't load constants, all other test will fail");

my $c;
eval {
	$c = Apache::Voodoo::Constants->new();
};
if ($@ =~ /find Apache::Voodoo::MyConfig/) {
	# This means that it's a new install, so change to a directory where a
	# config can be found.
	chdir('t');
	chdir('test_data');
	$c = Apache::Voodoo::Constants->new();
}
elsif($@) {
	# This means that we found a config but it's broken.
	BAIL_OUT($@);
}

is($c,Apache::Voodoo::Constants->new(),'is a singleton');

# Since we might be upgrading an existing install, we don't know
# if the config we have is an existing one on the system or one the one
# we faked up.  So we're just going to check that the accessors return something.

lives_ok('apache_gid');
lives_ok('apache_uid');
lives_ok('code_path');
lives_ok('conf_file');
lives_ok('conf_path');
lives_ok('install_path');
lives_ok('prefix');
lives_ok('session_path');
lives_ok('tmpl_path');
lives_ok('updates_path');
lives_ok('debug_dbd');
lives_ok('debug_path');
lives_ok('use_log4perl');
lives_ok('log4perl_conf');

sub lives_ok {
	my $method = shift;

	eval {
		$c->$method;
	};
	ok(!$@,$method);
}
