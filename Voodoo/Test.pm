=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Test - Testing harness for Apache Voodoo applications.

=head1 SYNOPSIS

Provides a testing harness for Apache Voodoo applications.

Complete documentation is available at http://www.apachevoodoo.com

=cut ###############################################################################
package Apache::Voodoo::Test;

$VERSION = "3.0002";

use strict;

use Time::HiRes;
use File::Spec;

use Apache::Voodoo::Constants;
use Apache::Voodoo::Engine;

sub new {
	my $class = shift;
	my %opts  = @_;

	die "id is a required parameter" unless $opts{'id'};

	my $self = {};
	bless $self, $class;

	$self->{'id'}        = $opts{'id'};
	$self->{'constants'} = Apache::Voodoo::Constants->new();

	$self->{'engine'} = Apache::Voodoo::Engine->new(
		'mp'         => $self,
		'only_start' => $opts{'id'}
	);

	$self->{'engine'}->init_app();

	return $self;
}

sub make_request {
	my $self   = shift;

	$self->set_request();
	$self->method(shift);
	$self->uri(shift);

	$self->parameters(@_);

	####################
	# URI translation jazz to get down to a proper filename
	####################
	my $uri = $self->uri();
	if ($uri =~ /\/$/o) {
		return $self->redirect($uri."index");
	}

	my $filename = $self->filename();

   	# remove the optional trailing .tmpl
   	$filename =~ s/\.tmpl$//o;
   	$uri      =~ s/\.tmpl$//o;
	
	unless (-e "$filename.tmpl") { return $self->declined;  }
	unless (-r "$filename.tmpl") { return $self->forbidden; } 

	########################################
	# We now know we have a valid request that we need to handle,
	# Get the engine ready to serve it.
	########################################
	eval {
		$self->{'engine'}->init_app();
		$self->{'engine'}->begin_run();
	};
	if (my $e = Apache::Voodoo::Exception::Application::SessionTimeout->caught()) {
		return $self->redirect($e->target());
	}
	elsif ($e = Exception::Class->caught()) {
		warn "$e";
		return $self->server_error;
	}

	####################
	# Get paramaters 
	####################
	my $params;
	eval {
		$params = $self->{'engine'}->parse_params();
	};
	if (my $e = Exception::Class->caught()) {
		warn "$e";
		$self->server_error;
	}

	####################
	# History capture 
	####################
	if ($self->is_get && 
		!$params->{ajax_mode} &&
		!$params->{return}
		) {
		$self->{'engine'}->history_capture($uri,$params);
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
			$self->{'engine'}->finish($self->redirect);
			return $self->redirect($e->target());
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::RawData")) {
			$self->header_out(each %{$e->headers}) if (ref($e->headers) eq "HASH");
			$self->content_type($e->content_type);
			$self->print($e->data);

			$self->{'engine'}->finish($self->ok);
			return $self->ok;
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::Unauthorized")) {
			$self->{'engine'}->finish($self->unauthorized);
			return $self->unauthorized;
		}
		elsif (! $e->isa("Apache::Voodoo::Exception::Application")) {
			# Apache::Voodoo::Exception::RunTime
			# Apache::Voodoo::Exception::RunTime::BadCommand
			# Apache::Voodoo::Exception::RunTime::BadReturn
			# Exception::Class::DBI
			unless ($self->{'engine'}->is_devel_mode()) {
				warn "$@";
				$self->{'engine'}->finish($self->server_error);
				return $self->server_error;
			}

		}
		$content = $e;
	}

	$self->{'controller_output'} = $content;
	my $view = $self->{'engine'}->execute_view($content);

	# output content
	$self->content_type($view->content_type());
	$self->print($view->output());

	####################
	# Clean up
	####################
	$self->{'engine'}->finish($self->ok);
	$view->finish();

	return $self->ok;
}

sub get_session {
#FIXME implement
}

sub get_model {
	my $self  = shift;
	my $model = shift;

	return $self->{'engine'}->get_model($self->{'id'},$model);
}

sub set_request {
    my $self = shift;

    $self->{'request_id'} = Time::HiRes::time;

	foreach (qw(uri cookiejar content_type is_get redirected_to controller_output)) {
    	delete $self->{$_};
	}

	foreach (qw(err_header_out header_out header_in)) {
		$self->{$_} = [];
	}

	foreach (qw(parameters)) {
		$self->{$_} = {};
	}

	$self->{'method'}      = 'GET';
	$self->{'remote_host'} = 'localhost';
	$self->{'remote_ip'}   = '127.0.0.1';
}

sub request_id { return $_[0]->{'request_id'}; }

# TODO
sub dir_config { undef; }

sub uri {
	my $self = shift;

	if ($_[0]) {
		$self->{'uri'} = $_[0];
		$self->{'uri'} =~ s/^\///g;
	}
	return $self->{'uri'};
}

sub filename { 
	my $self = shift;
	return File::Spec->catfile(
		$self->{'constants'}->install_path(),
		$self->{'id'},
		$self->{'constants'}->tmpl_path(),
		$self->{'uri'}
	);
}

sub method { 
	my $self = shift;

	if ($_[0] =~ /^(get|post)$/) {
		$self->{'method'} = uc($_[0]);
	}

	return $self->{'method'};
}


sub print {
	my $self = shift;

	$self->{'output'} .= $_[0];
}

sub controller_output { 
	my $self = shift;
	return $self->{'controller_output'};
}

sub output { 
	my $self = shift;
	return $self->{'output'};
}

sub is_get     { return ($_[0]->method eq "GET"); }
sub get_app_id { return $_[0]->{"id"}; }
sub site_root  { return "/"; }

sub remote_ip {
	my $self = shift;
	$self->{'remote_ip'} = $_[0] if $_[0];
	return $self->{'remote_ip'};
}

sub remote_host {
	my $self = shift;
	$self->{'remote_host'} = $_[0] if $_[0];
	return $self->{'remote_host'};
}

sub server_url {
	return "http://localhost/";
}

sub if_modified_since {
}

sub status { return $_[0]->{'status'}; }

sub declined     { my $self = shift; $self->{'status'} = "DECLINED";      return $self->{'status'}; }
sub forbidden    { my $self = shift; $self->{'status'} = "FORBIDDEN";     return $self->{'status'}; }
sub unauthorized { my $self = shift; $self->{'status'} = "AUTH_REQUIRED"; return $self->{'status'}; }
sub ok           { my $self = shift; $self->{'status'} = "OK";            return $self->{'status'}; }
sub server_error { my $self = shift; $self->{'status'} = "SERVER_ERROR";  return $self->{'status'}; }
sub not_found    { my $self = shift; $self->{'status'} = "NOT_FOUND";     return $self->{'status'}; }

sub content_type { 
	my $self = shift;

	$self->{'content_type'} = [ @_ ] if scalar(@_);
	return $self->{'content_type'};
}

sub err_header_out { 
	my $self = shift;

	push(@{$self->{'err_header_out'}},@_) if scalar(@_);
	return $self->{'err_header_out'};
}

sub header_out { 
	my $self = shift;

	push(@{$self->{'header_out'}},@_) if scalar(@_);
	return $self->{'header_out'};
}

sub header_in {
	my $self = shift;

	push(@{$self->{'header_in'}},@_) if scalar(@_);
	return $self->{'header_in'};
}   

sub redirected_to { return $_[0]->{'redirected_to'}; }
sub redirect {
	my $self = shift;
	my $loc  = shift;

	$self->{'redirected_to'} = $loc;
	$self->{'status'} = "REDIRECT";

	return "REDIRECT";                         
}                                                                

sub parameters {
	my $self = shift;

	if (scalar(@_)) {
		if (scalar(@_) == 1 && ref($_[0]) eq "HASH") {
			$self->{'parameters'} = shift;
		}
		else {
			$self->{'parameters'} = [ @_ ];
		}
	}

	return $self->{'parameters'};
}

sub parse_params {
	my $self       = shift;
	my $upload_max = shift;

	if (ref($self->{'parameters'}) eq "HASH") {
		return $self->{'parameters'};
	}
	else {
		my $params = {};
		my $c=0;
		foreach (@{$self->{'parameters'}}) {
			if (ref($_) eq "HASH") {
				while (my ($k,$v) = each %{$_}) {
					$params->{$k} = $v;
				}
			}
			$params->{'ARGV'}->[$c] = $_;
			$c++;
		}
		return $params;
	}
}                       

sub set_cookie {
	my $self = shift;

	my $name    = shift;
	my $value   = shift;
	my $expires = shift;

	my $c = "$name=$value; path=/; domain=".$self->remote_host() ."; HttpOnly";
	$self->{"cookie"} = $c;

	$self->err_header_out('Set-Cookie' => $c);
}

sub get_cookie {
	my $self = shift;
	
	return $self->{"cookie"};
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
