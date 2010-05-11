use File::Find;
use Test::More;
use HTML::Template;

my @templates;

find({
	wanted => \&wanted,
	no_chdir => 1
},"html");

plan tests => scalar @templates;

foreach my $file (@templates) {
	eval {
		HTML::Template->new(
                        'filename'          => $file,
                        'path'              => [ 'html' ],
                        'die_on_bad_params' => 0,
                );
	};

	ok($@ eq "") || diag("\n$file\n$@\n");
}

sub wanted {
   $File::Find::prune = 1 if $_ =~ /\.svn/;

   push(@templates,$_) if ($_ =~ /\.tmpl$/);
}
