use lib("<TMPL_VAR SERVER_ROOT>/lib/perl");

use File::Find;
use Test::More;

my @modules;

find({
	wanted => \&wanted,
	no_chdir => 1
},"code");

plan tests => scalar @modules;

foreach my $pm (@modules) {
	$pm =~ s/\//::/g;
	$pm =~ s/\.pm$//;
	$pm =~ s/^code/cpetracking/;

	use_ok($pm);
}

sub wanted {
   $File::Find::prune = 1 if $_ =~ /\.svn/;

   push(@modules,$_) if ($_ =~ /\.pm$/);
}
