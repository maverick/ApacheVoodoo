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
			$self->{'run'}->{'uri'}    = $req->dataof->uri;
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
	$self->{'engine'}->set_request($r);

	eval {
		$self->{'engine'}->init_app();
	};
	if ($@) {
		warn "$@";
		return $self->{'mp'}->server_error();
	}

	my $return = $self->{'soap'}->handle($r);

	$self->{'engine'}->finish();

	return $return;
}

sub handle_request {
	my $self = shift;

	my $params = {};
	my $c=0;
	foreach (@_) {
		if (ref($_) eq "HASH") {
			while (my ($k,$v) = each %{$_}) {
				$params->{$k} = $v;
			}
		}
		$params->{'ARGV'}->[$c] = $_;
		$c++;
	}

	my $uri      = $self->{'mp'}->uri();
	my $filename = $self->{'mp'}->filename();
	if (defined($self->{'run'}->{'uri'})) {
		$uri      = File::Spec->catfile($uri,     $self->{'run'}->{'uri'});
		$filename = File::Spec->catfile($filename,$self->{'run'}->{'uri'});
	}

	if ($uri =~ /\/$/) {
		die SOAP::Fault->new(faultcode => $self->{mp}->not_found(), faultstring => 'No such service.');
	}

	$filename =~ s/\.tmpl$//;
	unless ($self->{'run'}->{'method'} eq 'handle') {
		$filename =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
		$uri      =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
	}

	unless (-e "$filename.tmpl" && 
	        -r "$filename.tmpl") {
		die SOAP::Fault->new(faultcode => $self->{mp}->not_found(), faultstring => 'No such service.');
	};

	my $content;
	eval {
		$self->{'engine'}->begin_run();

		$content = $self->{'engine'}->execute_controllers($uri,$params);
	};
	if ($@) {
		die SOAP::Fault->new(faultcode => 500, faultstring => "$@");
	}

	return $content;
}

1;
