package Apache::Voodoo::Debug;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class = shift;
	my $conf  = shift;

	unless (ref($conf->{'debug'}) eq "HASH") {
		# old style config, so we'll go full monty for devel and silence for production.
		$conf->{'debug'} = {
			'FirePHP' => { all => 1 },
			'Native'  => { all => 1 }
		};
	}

	my @handlers;
	foreach (keys %{$conf->{'debug'}}) {
		if ($conf->{'debug'}->{$_}) {
			my $package = 'Apache::Voodoo::Debug::'.$_;
			my $file = $package.'.pm';

			$file =~ s/::/\//g;

			require $file;
			push(@handlers, $package->new($conf->{'id'},$conf->{'debug'}->{$_}));
		}
	}

	if (scalar(@handlers) > 1) {
		require Apache::Voodoo::Debug::Multiplex;
		return Apache::Voodoo::Debug::Multiplex->new(@handlers);
	}
	elsif (scalar(@handlers) == 1) {
		return $handlers[0];
	}
	else {
		# Common implements the api, but doesn't do any logging of any sort.
		# So we can use it as a sink if debugging is turned off.
		require Apache::Voodoo::Debug::Common;
		return Apache::Voodoo::Debug::Common->new();
	}
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include in
this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version of 
the Artistic License :)

=cut ################################################################################
