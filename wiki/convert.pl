#!/usr/bin/perl

use strict;
use warnings;

foreach my $ifile (@ARGV) {
	(my $ofile = $ifile) =~ s/\.txt/\.pod/;

	open(IN,$ifile)    || die "Can't open infile: $!";
	open(OUT,">$ofile") || die "Can't write to outfile: $!";

	my $verbatim = 0;
	while (my $line=<IN>) {
		next if $line =~ /^%META/ or $line =~ /\%TOC/;

		unless ($verbatim) {
			$line =~ s/^---\+\+\+\+\+\+\s*(.*)/=head5 $1\n/;
			$line =~ s/^---\+\+\+\+\+\s*(.*)/=head4 $1\n/;
			$line =~ s/^---\+\+\+\+\s*(.*)/=head3 $1\n/;
			$line =~ s/^---\+\+\+\s*(.*)/=head2 $1\n/;
			$line =~ s/^---\+\+\s*(.*)/=head1 $1\n/;
			$line =~ s/^---\+\s*(.*)/=head1 $1\n/;

			$line =~ s/=([^=]+)=/C<$1>/g;
			
			$line =~ s/&lt;/E<lt>/g;
			$line =~ s/&gt;/E<gt>/g;
			$line =~ s/\!\!+//g;
			$line =~ s/<nop>//g;

			$line =~ s/\[\[http:\/\/([^\]]+)\]\[([^\]]+)\]\]/$2/g; #  (L<http:\/\/$1>)/g;

			$line =~ s/\[\[#([^\]]+)\]\[([^\]]+)\]\]/L<$2|\/$1>/g;
			$line =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/L<$2|$1>/g;

			# CPAN: macro
			$line =~ s/CPAN:([^ ]+)/L<$1>/g;

			# CamelCase links.
			$line =~ s/\b([A-Z][a-z]+[A-Z]\w+)\b/L<Apache::Voodoo::$1>/g;
		}

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
