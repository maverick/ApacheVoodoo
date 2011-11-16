################################################################################
#
# Apache::Voodoo::Rest - Implements a REST like interface to Voodoo based apps
#
################################################################################
package Apache::Voodoo::Rest;

$VERSION = "3.0206";

use strict;
use warnings;

use Time::HiRes;

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;
use Apache::Voodoo::Engine;
use JSON::DWIW;

my $self = Apache::Voodoo::Rest->new();

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{'mp'}        = Apache::Voodoo::MP->new();
	$self->{'constants'} = Apache::Voodoo::Constants->new();

	$self->{'engine'} = Apache::Voodoo::Engine->new('mp' => $self->{'mp'});

	return $self;
}

sub handler {
	my $r = shift;

	$self->{'mp'}->set_request($r);

	$self->{'engine'}->set_request($r);

	####################
	# URI translation jazz to get down to a proper filename
	####################
	my $uri = $self->{'mp'}->uri();
	if ($uri =~ /\/$/o) {
		$uri .= 'index';
	}
	else {
		$uri =~ s:([^/]+)/([^/]*)$:$2_$1:;
	}

	my $filename = $self->{'mp'}->document_root().$uri;
	unless (-e "$filename.tmpl") { return $self->{mp}->declined;  }
	unless (-r "$filename.tmpl") { return $self->{mp}->forbidden; }

	########################################
	# We now know we have a valid request that we need to handle,
	# Get the engine ready to serve it.
	########################################
	eval {
		$self->{'engine'}->init_app();
		$self->{'engine'}->begin_run();
	};
	if (my $e = Apache::Voodoo::Exception::Application::SessionTimeout->caught()) {
		return $self->{'mp'}->redirect($e->target());
	}
	elsif ($e = Exception::Class->caught()) {
		warn "$e";
		return $self->{'mp'}->server_error;
	}

	####################
	# Get paramaters
	####################
	my $params;
	eval {
		$params = $self->{'engine'}->parse_params();
	};
	if ($@) {
		return $self->display_host_error($@);
	}

	if ($self->{mp}->method eq "POST" && 
		$self->{mp}->header_in('Content-type') eq "application/json") {
		my $buffer;
		my $data;
		my $offset=0;
		while (my $c = $self->{mp}->{r}->read($buffer,4096,$offset)) {
			$offset += $c;
			$data   .= $buffer;
			$buffer  = '';
			#if ($offset > $upload_max) {
				# yell loudly
			#	return {};
			#}
		}
		if ($data) {
			my $jp = JSON::DWIW::deserialize_json($data);
			if (ref($jp) eq "ARRAY") {
				$params->{ARGV} = $jp;
			}
			elsif (ref($jp) eq "HASH") {
				foreach (keys %{$jp}) {
					$params->{$_} = $jp->{$_};
				}
			}
		}
	}

	####################
	# Execute the controllers
	####################
	my $content;
	eval {
		$content = $self->{'engine'}->execute_controllers($uri,$params);
	};
	if (my $e = Exception::Class->caught()) {
		if ($e->isa("Apache::Voodoo::Exception::Application::Redirect")) {
			$self->{'engine'}->status($self->{mp}->redirect);
			return $self->{'mp'}->redirect($e->target());
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::RawData")) {
			$self->{mp}->header_out(each %{$e->headers}) if (ref($e->headers) eq "HASH");
			$self->{mp}->content_type($e->content_type);
			$self->{mp}->print($e->data);

			$self->{'engine'}->status($self->{mp}->ok);
			return $self->{mp}->ok;
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::Unauthorized")) {
			$self->{'engine'}->status($self->{mp}->unauthorized);
			return $self->{mp}->unauthorized;
		}
		elsif (! $e->isa("Apache::Voodoo::Exception::Application")) {
			# Apache::Voodoo::Exception::RunTime
			# Apache::Voodoo::Exception::RunTime::BadCommand
			# Apache::Voodoo::Exception::RunTime::BadReturn
			# Exception::Class::DBI
			warn $e;
			unless ($self->{'engine'}->is_devel_mode()) {
				$self->{'engine'}->status($self->{mp}->server_error);
				return $self->{mp}->server_error;
			}

		}
		$content = $e;
	}

	my $view = $self->{'engine'}->execute_view($content,'JSON');

	# output content
	$self->{mp}->content_type($view->content_type());
	$self->{mp}->print($view->output());
	$self->{mp}->flush();

	####################
	# Clean up
	####################
	$self->{'engine'}->status($self->{mp}->ok);
	$view->finish();

	return $self->{mp}->ok;
}

sub display_host_error {
	my $self  = shift;
	my $error = shift;

	$self->{'mp'}->content_type("text/html");
	$self->{'mp'}->print("<h2>The following error was encountered while processing this request:</h2>");
	$self->{'mp'}->print("<pre>$error</pre>");
	$self->{'mp'}->flush();

	return $self->{mp}->ok;
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
