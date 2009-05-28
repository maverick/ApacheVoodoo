=pod ####################################################################################

=head1 NAME

Apache::Voodoo::Handler - Main interface between mod_perl and Voodoo

=head1 VERSION

$Id: Handler.pm 11537 2008-12-11 21:36:23Z medwards $

=head1 SYNOPSIS
 
This is the main generic presentation module that interfaces with apache, 
handles session control, database connections, and interfaces with the 
application's page handling modules.

=cut ################################################################################
package Apache::Voodoo::Handler;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;

use Time::HiRes;

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;
use Apache::Voodoo::Engine;

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
	my $self = shift;
	my $r    = shift;

	$self->{'mp'}->set_request($r);
	$self->{'engine'}->set_request($r);

	####################
	# URI translation jazz to get down to a proper filename
	####################
	my $uri = $self->{'mp'}->uri();
	if ($uri =~ /\/$/o) {
		return $self->{'mp'}->redirect($uri."index");
	}

	my $filename = $self->{'mp'}->filename();

   	# remove the optional trailing .tmpl
   	$filename =~ s/\.tmpl$//o;
   	$uri      =~ s/\.tmpl$//o;

	unless (-e "$filename.tmpl") { return $self->{mp}->declined;  }
	unless (-r "$filename.tmpl") { return $self->{mp}->forbidden; } 

	########################################
	# We now know we have a valid request that we need to handle,
	# Get the engine ready to server it.
	########################################
	eval {
		$self->{'engine'}->init_app();
		$self->{'engine'}->begin_run();
	};
	warn "after run";
	if (my $e = Apache::Voodoo::Exception::Application::SessionTimeout->caught()) {
		warn "timeout";
		return $self->{'mp'}->redirect($e->target());
	}
	elsif (my $e = Apache::Voodoo::Exception->caught()) {
		warn "$e";
		return $self->{'mp'}->server_error;
	}

	warn "before params";
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
	warn "after params";

	####################
	# History capture 
	####################
	if ($self->{mp}->is_get && 
		!$params->{ajax_mode} &&
		!$params->{return}
		) {
		$self->{'engine'}->history_capture($uri,$params);
	}

	####################
	# Execute the controllers
	####################
	my $content;
	my $e;
	eval {
		$content = $self->{'engine'}->execute_controllers($uri,$params);
	};
	if ($e = Apache::Voodoo::Exception::Application::Redirect->caught()) {
		$self->{'engine'}->finish($self->{mp}->redirect);
		return $self->{'mp'}->redirect($e->target());
	}
	elsif ($e = Apache::Voodoo::Exception::Application::RawData->caught()) {
		$self->{mp}->header_out(each %{$e->headers}) if (ref($e->headers) eq "HASH");
		$self->{mp}->content_type($e->content_type);
		$self->{mp}->print($e->data);

		$self->{'engine'}->finish($self->{mp}->ok);
		return $self->{mp}->ok;
	}
	elsif ($e = Apache::Voodoo::Exception::Application->caught()) {
		$content = $e;
	}
	elsif ($@) {
		# Apache::Voodoo::Exception::RunTime
		# Apache::Voodoo::Exception::RunTime::BadCommand
		# Apache::Voodoo::Exception::RunTime::BadReturn
		# Exception::Class::DBI
		unless ($self->{'engine'}->is_devel_mode()) {
			warn "$@";
			$self->{'engine'}->finish($self->{mp}->server_error);
			return $self->{mp}->server_error;
		}

		$content = $@;
	}

	my $view = $self->{'engine'}->execute_view($content);

	# output content
	$self->{mp}->content_type($view->content_type());
	$self->{mp}->print($view->output());
	$self->{mp}->flush();

	####################
	# Clean up
	####################
	$self->{'engine'}->finish($self->{mp}->ok);
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

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include
in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
of the Artistic License :)

=cut ################################################################################
