#!/usr/bin/perl

use strict;
use warnings;

foreach my $ifile (@ARGV) {
	(my $ofile = $ifile) =~ s/\.txt/\.pod/;

	open(IN,$ifile)    || die "Can't open infile: $!";
	open(OUT,">$ofile") || die "Can't write to outfile: $!";

	my $verbatim = 0;
	while (my $line=<IN>) {
		$line =~ s/^---++++++\s*\!*\s*/=head5/;
		$line =~ s/^---+++++\s*\!*\s*/=head4/;
		$line =~ s/^---++++\s*\!*\s*/=head3/;
		$line =~ s/^---+++\s*\!*\s*/=head2/;
		$line =~ s/^---++\s*\!*\s*/=head1/;
		$line =~ s/^---+\s*\!*\s*/=head1/;
	}

	close(IN);
	close(OUT);
}
