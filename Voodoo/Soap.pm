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
use Apache::Voodoo::Exception;
use Exception::Class::DBI;

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

		my $wsdl;
		eval {
			$wsdl = new Pod::WSDL2(
				source   => $m,
				location => $self->{mp}->server_url().$uri,
				pretty   => 1,
				withDocumentation => 1
			);
			$wsdl->targetNS($self->{mp}->server_url().$uri);
		};
		if ($@) {
			$self->{'mp'}->content_type('text/plain');
			$self->{'mp'}->print("Error generating WDSL:\n\n$@");
		}
		else {
			$self->{'mp'}->content_type('text/xml');
			$self->{'mp'}->print($wsdl->WSDL);
		}

		$self->{'mp'}->flush();
		$return = $self->{mp}->ok;
	}
	else {
		$return = $self->{'soap'}->handle($r);
	}

	$self->{'engine'}->finish($self->{status});

	return $self->{status};
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
		$self->{status} = $self->{mp}->not_found();
		$self->_client_fault($self->{mp}->not_found(),'No such service.');
	}

	$filename =~ s/\.tmpl$//;
	unless ($self->{'run'}->{'method'} eq 'handle') {
		$filename =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
		$uri      =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
	}

	unless (-e "$filename.tmpl" && 
	        -r "$filename.tmpl") {
		$self->{status} = $self->{mp}->not_found();
		$self->_client_fault($self->{mp}->not_found(),'No such service.');
	};

	my $content;
	eval {
		$self->{'engine'}->begin_run();

		$content = $self->{'engine'}->execute_controllers($uri,$params);
	};
	if (my $e = Apache::Voodoo::Exception->caught()) {
		if ($e->isa("Apache::Voodoo::Exception::Application::Redirect")) {
			$self->{status} = $self->{mp}->redirect;
			$self->_client_fault($self->{mp}->redirect,"Redirected",$e->target);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::DisplayError")) {
			# apparently OK doesn't return 200 anymore, it returns 0.  When used in conjunction
			# with a SOAP fault that lets the server default it to 500, which isn't what we want.
			# The server didn't have an internal error, we just didn't like what the client sent.
			$self->{status} = 200;	
			$self->_client_fault($e->code, $e->error, $e->detail);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::AccessDenied")) {
			$self->{status} = $self->{mp}->forbidden;
			$self->_client_fault($self->{mp}->forbidden, $e->error, $e->detail);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::RawData")) {
			$self->{status} = $self->{mp}->ok;
			return {
				'error'        => 0,
				'success'      => 1,
				'rawdata'      => 1,
				'content-type' => $e->content_type,
				'headers'      => $e->headers,
				'data'         => $e->data
			};
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::SessionTimeout")) {
			$self->{status} = $self->{mp}->ok;
			$self->_client_fault(700, $e->error, $e->target);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::RunTime") && $self->{'engine'}->is_devel_mode()) {
			# Apache::Voodoo::Exception::RunTime
			# Apache::Voodoo::Exception::RunTime::BadCommand
			# Apache::Voodoo::Exception::RunTime::BadReturn
			$self->{status} = $self->{mp}->server_error;
			$self->_server_fault($self->{mp}->server_error, $e->error, Apache::Voodoo::Exception::parse_stack_trace($e->trace));
		}
		elsif ($self->{'engine'}->is_devel_mode()) {
			$self->{status} = $self->{mp}->server_error;
			$self->_server_fault($self->{mp}->server_error, $e->error);
		}
		else {
			$self->{status} = $self->{mp}->server_error;
			$self->_server_fault($self->{mp}->server_error, "Internal Server Error");
		}
	}
	elsif (ref($@) =~ /^Exception::Class::DBI/ && $self->{'engine'}->is_devel_mode()) {
		$self->{status} = $self->{mp}->server_error;
		$self->_server_fault($self->{mp}->server_error, $@->description, {
			"message" => $@->errstr,
			"package" => $@->package,
			"line"    => $@->line,
			"query"   => $@->statement
		});
	}
	elsif ($@) {
		$self->{status} = $self->{mp}->server_error;
		if ($self->{'engine'}->is_devel_mode()) {
			$self->_server_fault($self->{mp}->server_error, "$@");
		}
		else {
			$self->_server_fault($self->{mp}->server_error, 'Internal Server Error');
		}
	}

	$self->{status} = $self->{mp}->ok;
	return $content;
}

sub _client_fault {
	my $self = shift;
	$self->_make_fault('Client',@_);
}

sub _server_fault {
	my $self = shift;
	$self->_make_fault('Server',@_);
}

sub _make_fault {
	my $self = shift;

	my ($t,$c,$s,$d) = @_;

	my %msg;
	if (defined($c)) {
		$msg{faultcode} = $t.'.'.$c;
	}
	else {
		$msg{faultcode} = $t;
	}

	warn($msg{faultcode});
	$msg{faultstring} = $s;
	$msg{faultdetail} = $d if (defined($d));

	die SOAP::Fault->new(%msg);
}

1;
