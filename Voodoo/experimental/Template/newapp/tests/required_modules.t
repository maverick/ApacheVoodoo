use lib ('<TMPL_VAR SERVER_ROOT>/lib/perl');

use Test::More;

# List the modules required for your application here
my @modules = qw (
);

plan tests => scalar @modules;

foreach (@modules) {
	use_ok($_);
}
