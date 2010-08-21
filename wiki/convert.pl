#!/usr/bin/perl

use strict;
use warnings;

foreach my $ifile (@ARGV) {
	(my $ofile = $ifile) =~ s/\.txt/\.pod/;

	open(IN,$ifile)    || die "Can't open infile: $!";
	open(OUT,">$ofile") || die "Can't write to outfile: $!";

	my $verbatim = 0;
	while (my $line=<IN>) {
		$line =~ s/^---\+\+\+\+\+\+\s*(.*)/=head5 $1\n/;
		$line =~ s/^---\+\+\+\+\+\s*(.*)/=head4 $1\n/;
		$line =~ s/^---\+\+\+\+\s*(.*)/=head3 $1\n/;
		$line =~ s/^---\+\+\+\s*(.*)/=head2 $1\n/;
		$line =~ s/^---\+\+\s*(.*)/=head1 $1\n/;
		$line =~ s/^---\+\s*(.*)/=head1 $1\n/;

		$line =~ s/=([^=]+)=/C<$1>/g;
		
		$line =~ s/&lt;/E<lt>/g;
		$line =~ s/&gt;/E<gt>/g;
		$line =~ s/!!//g;
		$line =~ s/<nop>//g;

		next if $line =~ /^%META/ or $line =~ /\%TOC/;

		if ($line =~ /<verbatim>/) {
			$verbatim = 1;
			print OUT "\n";
		}
		elsif ($line =~ /<\/verbatim>/) {
			$verbatim = 0;
			print OUT "\n";
		}
		else {
			print OUT "\t" if $verbatim;
			print OUT $line;
		}
	}

	close(IN);
	close(OUT);
}
