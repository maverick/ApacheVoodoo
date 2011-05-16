package Apache::Voodoo::Soap;

$VERSION = "3.0206";

use strict;
use warnings;

use JSON;
use Data::Structure::Util qw(unbless);


# FIXME: Hack to prefer my extended version of Pod::WSDL over the
# one on CPAN.  This will need to stay in place until either the
# author of Pod::WSDL replys or I release my own version.
my $PWSDL;
BEGIN {
	eval {
		require Pod::WSDL2;
		$PWSDL = 'Pod::WSDL2';
	};
	if ($@) {
		require Pod::WSDL;
		$PWSDL = 'Pod::WSDL';
	}
}

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

	# JSON Decode

	my $uri = $self->{'mp'}->uri();
	$uri =~ s/(\/|\.tmpl)*$//;
	unless ($self->{'mp'}->{'method'} eq 'POST') {
		$uri =~ s/([\w_]+)$/$self->{'run'}->{'method'}_$1/i;
	}

	my $filename = $self->{'mp'}->document_root().$uri;
	unless (-e "$filename.tmpl" &&
	        -r "$filename.tmpl") {
		$self->{'status'} = $self->{'mp'}->not_found();
		$self->_client_fault($self->{'mp'}->not_found(),'No such service:'.$filename);
	};

	my $content;
	eval {
		$self->{'engine'}->begin_run();

		$content = $self->{'engine'}->execute_controllers($uri,$params);
	};
	if (my $e = Exception::Class->caught()) {
		if ($e->isa("Apache::Voodoo::Exception::Application::Redirect")) {
			$self->{'status'} = $self->{'mp'}->redirect;
			$self->_client_fault($self->{'mp'}->redirect,"Redirected",$e->target);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::DisplayError")) {
			# apparently OK doesn't return 200 anymore, it returns 0.  When used in conjunction
			# with a SOAP fault that lets the server default it to 500, which isn't what we want.
			# The server didn't have an internal error, we just didn't like what the client sent.
			$self->{'status'} = 200;
			$self->_client_fault($e->code, $e->error, $e->detail, $e->trace);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::AccessDenied")) {
			$self->{'status'} = $self->{'mp'}->forbidden;
			$self->_client_fault($self->{'mp'}->forbidden, $e->error, $e->detail, $e->trace);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::RawData")) {
			$self->{'status'} = $self->{'mp'}->ok;
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
			$self->{'status'} = $self->{'mp'}->ok;
			$self->_client_fault(700, $e->error, $e->target);
		}
		elsif ($self->{'engine'}->is_devel_mode) {
			if ($e->isa("Apache::Voodoo::Exception::RunTime")) {
				# Apache::Voodoo::Exception::RunTime
				# Apache::Voodoo::Exception::RunTime::BadCommand
				# Apache::Voodoo::Exception::RunTime::BadReturn
				$self->{'status'} = $self->{'mp'}->server_error;
				$self->_server_fault($self->{'mp'}->server_error, $e->error, undef, $e->trace);
			}
			elsif ($e->isa("Exception::Class::DBI")) {
				$self->{'status'} = $self->{'mp'}->server_error;
				$self->_server_fault($self->{'mp'}->server_error, $@->description, {
					"message" => $@->errstr,
					"package" => $@->package,
					"line"    => $@->line,
					"query"   => $@->statement
				});
			}
			else {
				$self->{'status'} = $self->{'mp'}->server_error;
				$self->_server_fault($self->{'mp'}->server_error, ref($e)?$e->error:"$e");
			}
		}
		else {
			$self->{'status'} = $self->{'mp'}->server_error;
			$self->_server_fault($self->{'mp'}->server_error, "Internal Server Error");
		}
	}

	#JSON Encode
	$self->{mp}->print($content);
	
	$self->{'engine'}->status($self->{'status'});

	return $self->{'mp'}->ok;
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

	my ($type,$code,$string,$detail,$trace) = @_;

	my %message;
	if (defined($code)) {
		$message{'faultcode'} = $type.'.'.$code;
	}
	else {
		$message{'faultcode'} = $type;
	}

	$message{'faultstring'} = $string;

	if (defined($detail)) {
		$message{'faultdetail'} = $detail;
	}
	elsif ($self->{'engine'}->is_devel_mode() && defined($trace)) {
		$message{'faultdetail'} = Apache::Voodoo::Exception::parse_stack_trace($trace);
	}

	die SOAP::Fault->new(%message);
}

1;

################################################################################
# Copyright (c) 2005-2010 Steven Edwards (maverick@smurfbane.org).
# All rights reserved.
#
# You may use and distribute Apache::Voodoo under the terms described in the
# LICENSE file include in this package. The summary is it's a legalese version
# of the Artistic License :)
#
################################################################################
