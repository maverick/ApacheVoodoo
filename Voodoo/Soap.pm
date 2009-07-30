package Apache::Voodoo::Soap;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use lib("/data/apache/sites/test");

use SOAP::Transport::HTTP;
use Pod::WSDL2;
use MIME::Entity;

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
			$self->{'run'}->{'method'} = $_[0]->dataof->name;
			$self->{'run'}->{'uri'}    = $_[0]->dataof->uri;
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


	my $return;
	if ($self->{mp}->is_get() && $r->unparsed_uri =~ /\?wsdl$/) {
		my $uri = $self->{'mp'}->uri();
		if ($uri =~ /\/$/) {
			return $self->{mp}->not_found();
		}

		# FIXME hack.  Shouldn't be looking in there to get this
		$uri =~ s/^\///;
		unless ($self->{'engine'}->{'run'}->{'app'}->{'controllers'}->{$uri}) {
			return $self->{mp}->not_found();
		}
		
		my $m = ref($self->{'engine'}->{'run'}->{'app'}->{'controllers'}->{$uri});
		if ($m eq "Apache::Voodoo::Loader::Dynamic") {
			$m = ref($self->{'engine'}->{'run'}->{'app'}->{'controllers'}->{$uri}->{'object'});
		}
		# FIXME here ends the hackery

		my $wsdl = new Pod::WSDL2(
			source   => $m,
			location => $self->{mp}->server_url().$uri,
			pretty   => 1,
			withDocumentation => 1
		);
		$wsdl->targetNS($self->{mp}->server_url().$uri);

		$self->{'mp'}->content_type('text/xml');
		$self->{'mp'}->print($wsdl->WSDL);
		$self->{'mp'}->flush();
		$return = $self->{mp}->ok;
	}
	else {
		$return = $self->{'soap'}->handle($r);
	}

	$self->{'engine'}->finish($self->{mp}->ok);

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

	my $e;
	my $content;
	eval {
		$self->{'engine'}->begin_run();

		$content = $self->{'engine'}->execute_controllers($uri,$params);
	};
	if    ($e = Apache::Voodoo::Exception::Application::Redirect->caught()) {
		return $self->_make_fault($self->{mp}->redirect, "Redirected",$e->target);
	}
	elsif ($e = Apache::Voodoo::Exception::Application::DisplayError->caught()) {
		return $self->_make_fault(600, $e->error, {nextservice => $e->target});
	}
	elsif ($e = Apache::Voodoo::Exception::Application::AccessDenied->caught()) {
		return $self->_make_fault($self->{mp}->forbidden, $e->error);
	}
	elsif ($e = Apache::Voodoo::Exception::Application::RawData->caught()) {
		return {
			'error'        => 0,
			'success'      => 1,
			'rawdata'      => 1,
			'content-type' => $e->content_type,
			'headers'      => $e->headers,
			'data'         => $e->data
		};
	}
	elsif ($@) {
		# Apache::Voodoo::Exception::RunTime
		# Apache::Voodoo::Exception::RunTime::BadCommand
		# Apache::Voodoo::Exception::RunTime::BadReturn
		# Exception::Class::DBI
		return $self->_make_fault($self->{mp}->server_error, "$@");
	}

	return $content;
}

sub _make_fault {
	my $self = shift;

	my %msg;
	$msg{faultcode}   = shift;
	$msg{faultstring} = shift;
	$msg{detail}      = shift if $_[0];

	die SOAP::Fault->new(%msg);
}

1;
