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
			'FirePHP' => {
				'devel' => { all => 1}
			},
			'Native' => {
				'devel' => { all => 1}
			}
		};
	}

	my $type = ($conf->{'devel_mode'})?'devel':'production';

	my @handlers;
	foreach (keys %{$conf->{'debug'}}) {
		if ($conf->{'debug'}->{$_}->{$type}) {
			my $package = 'Apache::Voodoo::Debug::'.$_;
			$file = $package'.pm';
			$file =~ s/::/\//;

			require $file;
			push(@handlers, $package->new($conf->{'id'},$conf->{'debug'}->{$_}->{$type}));
		}
	}

	if (scalar(@handlers) > 1) {
		require Apache::Voodoo::Debug::Multi;
		return Apache::Voodoo::Debug::Multi->new(@handlers);
	}
	elsif (scalar(@handlers) == 1) {
		return $handlers[0];
	}
	else {
		require Apache::Voodoo::Debug::Null;
		return Apache::Voodoo::Debug::Null->new();
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
