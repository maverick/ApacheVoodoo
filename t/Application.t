use strict;
use warnings;

use lib("t");

use File::Copy;

use Test::More 'no_plan' => 1;
use Data::Dumper;

BEGIN {
	# fall back to eq_or_diff if we don't have Test::Differences
	if (!eval q{ use Test::Differences; 1 }) {
		*eq_or_diff = \&is_deeply;
	}
}

use_ok('Apache::Voodoo::Constants')   || BAIL_OUT($@);
use_ok('Apache::Voodoo::Application') || BAIL_OUT($@);

my $path = $INC{'Apache/Voodoo/Constants.pm'};
$path =~ s:lib/Apache/Voodoo/Constants.pm:t/app_newstyle:;

copy("$path/C/a/controller.pm.orig","$path/C/a/controller.pm") || die "can't reset controller.pm: $!";
copy("$path/M/a/model.pm.orig",     "$path/M/a/model.pm")      || die "can't reset model.pm: $!";
copy("$path/V/a/view.pm.orig",      "$path/V/a/view.pm")       || die "can't reset view.pm: $!";

my $app;
eval {
	$app = Apache::Voodoo::Application->new();
};
ok($@ =~ /ID is a required parameter/, "ID is a required param");

my $loc = $INC{'Apache/Voodoo/Constants.pm'};
$loc =~ s/lib\/Apache\/Voodoo\/Constants.pm/t/;

my $constants = Apache::Voodoo::Constants->new();
$constants->{INSTALL_PATH} = $loc;

eval {
	$app = Apache::Voodoo::Application->new('app_blank');
};
print STDERR $@;
ok(!$@,'ID alone works') || diag($@);

eval {
	$app = Apache::Voodoo::Application->new('app_oldstyle',$constants);
};
ok(!$@,'ID and constants object works') || diag($@);

isa_ok($app->{'controllers'}->{'test_module'},            "Apache::Voodoo::Loader::Dynamic");
isa_ok($app->{'controllers'}->{'test_module'}->{'object'},"app_newstyle::test_module");

isa_ok($app->{'controllers'}->{'skeleton'},            "Apache::Voodoo::Loader::Dynamic");
isa_ok($app->{'controllers'}->{'skeleton'}->{'object'},"app_newstyle::skeleton");

eval {
	$app = Apache::Voodoo::Application->new('app_newstyle',$constants);
};
ok(!$@,'New style config works') || diag($@);

isa_ok($app->{'controllers'}->{'a/controller'},            "Apache::Voodoo::Loader::Dynamic");
isa_ok($app->{'controllers'}->{'a/controller'}->{'object'},"app_newstyle::C::a::controller");

isa_ok($app->{'models'}->{'a::model'},            "Apache::Voodoo::Loader::Dynamic");
isa_ok($app->{'models'}->{'a::model'}->{'object'},"app_newstyle::M::a::model");

isa_ok($app->{'views'}->{'a::view'},            "Apache::Voodoo::Loader::Dynamic");
isa_ok($app->{'views'}->{'a::view'}->{'object'},"app_newstyle::V::a::view");
isa_ok($app->{'views'}->{'a::view'}->{'object'},"Apache::Voodoo::View");

eq_or_diff($app->{'controllers'}->{'a/controller'}->handle,{a_controller => 'a controller'},'controller output ok');
eq_or_diff($app->{'models'}->{'a::model'}->get_foo,        "foo",                           'model output ok');

