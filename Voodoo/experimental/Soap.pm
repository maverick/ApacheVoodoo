package Apache::Voodoo::Soap;

use strict;
use warnings;

use SOAP::Transport::HTTP;

use Data::Dumper;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 ); 
			  
=pod
# setup primary hook to mod_perl depending on which version we're running
BEGIN {
	if (MP2) {
		*handler = sub : method { shift()->handle_request(@_) };
	}
	else {
		*handler = sub ($$) { shift()->handle_request(@_) };
	}
}
=cut

sub new {
	my $class = shift;

	my $self = {};
	bless $self,$class;


	$self->{handler} = Apache::Voodoo::Soap::Handler->new();

	$self->{soap} = SOAP::Transport::HTTP::Apache->on_dispatch(
		sub {
			my $req = shift;

			print STDERR "in on_dispatch closure\n";
			$self->{handler}->{method} = $req->dataof->name;

			return ("Apache/Voodoo/Soap/Handler","target");
		}
	);

	$self->{soap}->dispatch_to($self->{handler},"target");

	return $self;
}

sub handler { 
	my ($self,$r) = @_;

	print STDERR "$$ called ".$self."\n";

	$self->{handler}->{uri} = $r->uri();

	return $self->{soap}->handler($r);
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
