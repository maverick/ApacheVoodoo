package Apache::Voodoo::Soap;

use strict;
use warnings;

use SOAP::Transport::HTTP;

use Data::Dumper;

my $handler = Apache::Voodoo::Soap::Handler->new();

my $server = SOAP::Transport::HTTP::Apache->on_dispatch(\&dispatcher);
$server->dispatch_to($handler,"target");


sub handler { 
	my $r = $_[0];

	$handler->{uri} = $r->uri();
	return $server->handler(@_);
}

sub dispatcher {
	my $req = shift;

	open(DUMP,">>/tmp/soap.dump");

	$handler->{method} = $req->dataof->name;

	close(DUMP);

	return ("Apache/Voodoo/Soap/Handler","target");
}


1;

package Apache::Voodoo::Soap::Handler;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my $class = shift;

	my $self = {};

	bless $self,$class;

	return $self;
}

sub target {
	my $self = shift;

	my @params = @_;
	open(DUMP,">>/tmp/soap.dump");
	print DUMP $self->{uri},"\n";
	print DUMP $self->{method},"\n";
	print DUMP $self->_yadda(),"\n";
	print DUMP Dumper "target", @params;
	close(DUMP);

	return { "foo" => "bar" };
}

sub _yadda {
	my $self = shift;

	return "yadda, yadda, yadda";
}

1;
