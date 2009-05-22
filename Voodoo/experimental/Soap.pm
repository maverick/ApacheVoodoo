package Apache::Voodoo::Soap;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use SOAP::Transport::HTTP;

use Apache::Voodoo::MP;
use Apache::Voodoo::Engine;

use Data::Dumper;

sub new {
	my $class = shift;

	my $self = {};
	bless $self,$class;

	$self->{'mp'}     = Apache::Voodoo::MP->new();
	$self->{'engine'} = Apache::Voodoo::Engine->new('mp' => $self->{'mp'});

	$self->{'soap'} = SOAP::Transport::HTTP::Apache->new();
	$self->{'soap'}->on_dispatch(
		sub {
			my $req = shift;
			$self->{'run'}->{'method'} = $req->dataof->name;
			return ("Apache/Voodoo/Soap","handle_request");
		}
	);

	$self->{'soap'}->dispatch_to($self,"handle_request");

	return $self;
}

sub handler { 
	my $self = shift;
	my $r    = shift;

	$self->{'mp'}->set_request($r);

	my $id = $self->{'mp'}->get_app_id();
	unless (defined($id)) {
		print STDERR  "PerlSetVar ID not present in configuration.  Giving up\n";
		return $self->{'mp'}->server_error();
	}

	unless ($self->{'engine'}->valid_app($id)) {
		warn "application id '$id' unknown. Valid ids are: ".join(",",$self->{engine}->get_apps())."\n";
		return $self->{'mp'}->server_error();
	}

	$self->{'run'}->{'id'} = $id;

	my $return = $self->{soap}->handle($r);

	$self->{'engine'}->finish();

	return $return;
}

sub handle_request {
	my $self = shift;

	my @params = @_;

	my $uri = $self->{'mp'}->uri();
	if ($uri =~ /\/$/) {
		$self->make_404;
	}

	my $filename = $self->{'mp'}->filename();
	$filename =~ s/\.tmpl$//;
	unless ($self->{'run'}->{'method'} eq 'handle') {
		$filename =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
		$uri      =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
	}

	unless (-e "$filename.tmpl" && 
	        -r "$filename.tmpl") {
		$self->make_404;
	};

	$self->{'engine'}->init_app($self->{'run'}->{'id'});

	$self->{'engine'}->{'run'}->{'session'}->{'value'}++;

	open(DUMP,">>/tmp/soap.dump");
	print DUMP $filename,"\n";
	print DUMP $uri,"\n";
	print DUMP $self->{'run'}->{'method'},"\n";
	print DUMP Dumper \@params;
	print DUMP Dumper $self->{'engine'}->{'run'}->{'session'};

	my $content;
	eval {
		$content = $self->{'engine'}->execute_controllers($uri,\@params);
	};
	if ($@) {
		die SOAP::Fault->new(faultcode => $self->{mp}->server_error(), faulstring => scalar($@));
	}
	print DUMP Dumper $content;

	close(DUMP);

	return $content;
}

sub make_404 {
	my $self = shift;
	die SOAP::Fault->new(faultcode => $self->{mp}->not_found(), faultstring => 'No such service.');
}


1;
