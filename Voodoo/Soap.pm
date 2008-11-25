package Apache::Voodoo::Soap;

use strict;
use warnings;

use SOAP::Transport::HTTP;
use Data::Dumper;

use Apache2::Request;
use Apache2::Const;

my $server = SOAP::Transport::HTTP::Apache->dispatch_to('/data/apache/sites/soap/');

sub handler { 
	my $r = $_[0];

	open(DUMP,">>/tmp/soap.dump");

	my $apr = Apache2::Request->new($r);

	my @foo = $apr->param;
	print DUMP Dumper(\@foo);

	my $buffer;
	my $bytes = $r->read($buffer,1024,0);
	print DUMP Dumper($bytes,$buffer);

	$server->handler($_[0],sub {
		print DUMP Dumper(\@_)
	});
	close(DUMP);
}

1;
