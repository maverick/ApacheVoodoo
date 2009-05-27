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
	if (my $e = Apache::Voodoo::Exception::Application::SessionTimeout->caught()) {
		return $self->{'mp'}->redirect($e->target());
	}
	elsif ($@) {
		warn "$@";
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
	eval {
		$content = $self->execute_controllers($uri,$params);
	};
	if (my $e = Apache::Voodoo::Exception::Application::Redirect->caught()) {
		return $self->{'mp'}->redirect($e->target());
	}
	elsif (my $e = Apache::Voodoo::Exception::Application::DisplayError->caught()) {
		$uri = "display_error";
		$content->{error_url}    = $e->target();
		$content->{error_string} = $e->message();
	}
	elsif (my $e = Apache::Voodoo::Exception::Application::AccessDenied->caught()) {
		$uri = $e->target();
		$content->{error_string} = $e->message();
	}
	elsif (my $e = Apache::Voodoo::Exception::Application::RawData->caught()) {
		$self->{mp}->header_out(each %{$e->headers}) if (ref($e->headers) eq "HASH");
		$self->{mp}->content_type($e->content_type);
		$self->{mp}->print($e->data);
		return $self->{mp}->ok;
	}
	elsif (my $e = Apache::Voodoo::Exception::Application::BadCommand->caught()) {
	}
	elsif (my $e = Apache::Voodoo::Exception::Application::BadReturn->caught()) {
	}
	elsif ($@) {
		warn "$@";
	}

	if ($self->{'engine'}->is_devel_mode()) {

	}

#	$debug->status($return);

	####################
	# Clean up
	####################
	$self->{'engine'}->finish();

	return $self->{mp}->ok;
}

=pod
sub generate_content {

	if ($e) {
		# caught a runtime error from perl
		unless ($conf->{'devel_mode'}) {
			warn $e;
			return $self->{mp}->server_error;
		}
	}

####
#### Env specific
####

	my $view;
	if (defined($p->{'_view_'}) && 
		defined($app->{'views'}->{$p->{'_view_'}})) {

		$view = $app->{'views'}->{$p->{'_view_'}};
	}
	elsif (defined($run->{'template_conf'}->{'default_view'}) && 
	       defined($app->{'views'}->{$run->{'template_conf'}->{'default_view'}})) {

		$view = $app->{'views'}->{$run->{'template_conf'}->{'default_view'}};
	}	
	else {
		$view = $app->{'views'}->{'HTML'};
	}	

	$view->begin($p);

	if ($e) {
		$view->exception($e);
	}

	# pack up the params. note the presidence: module overrides template_conf
	$view->params($run->{template_conf});
	$view->params($template_params);

	# add any params from the debugging handlers
	$view->params($debug->finalize());

	# output content
	$self->{mp}->content_type($view->content_type());
	$self->{mp}->print($view->output());

	$view->finish();

	$self->{mp}->flush();

	return $self->{mp}->ok;
}
=cut

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
