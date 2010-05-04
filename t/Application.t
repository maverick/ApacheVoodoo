use strict;
use warnings;

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

my $app;
eval {
	$app = Apache::Voodoo::Application->new();
};
is($app->{errors},'ID is a required parameter.', "ID is a required param");

my $loc = $INC{'Apache/Voodoo/Constants.pm'};
$loc =~ s/lib\/Apache\/Voodoo\/Constants.pm/t/;

my $constants = Apache::Voodoo::Constants->new();
$constants->{INSTALL_PATH} = $loc;
$constants->{CONF_FILE} = 'voodoo2.conf';

eval {
	$app = Apache::Voodoo::Application->new('test_data');
};
ok(!$@,'ID alone works') || diag($@);

eval {
	$app = Apache::Voodoo::Application->new('test',$constants);
};
ok(!$@,'ID and constants object works') || diag($@);

