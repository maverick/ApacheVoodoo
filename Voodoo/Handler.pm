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

use DBI;
use Time::HiRes;

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;
use Apache::Voodoo::Application;
use Apache::Voodoo::Exception;

# Debugging object.  I don't like using an 'our' variable, but it is just too much
# of a pain to pass this thing around to everywhere it needs to go. So, I just tell
# myself that this is STDERR on god's own steroids so I can sleep at night.
our $debug;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{mp}        = Apache::Voodoo::MP->new();
	$self->{constants} = Apache::Voodoo::Constants->new();

	if (exists $ENV{'MOD_PERL'}) {
		# let's us do a compile check outside of mod_perl
		$self->restart;
	}

	# Setup signal handler for die so that all deaths become exception objects
	# This way we can get a stack trace from where the death occurred, not where it was caught.
	$SIG{__DIE__} = sub { 
		if (ref($_[0]) =~ /^Apache::Voodoo::Exception/ || ref($_[0]) =~ /^Exception::Class::DBI/) {
			# Already died using an exception class, just pass it up the chain
			$_[0]->rethrow;
		}
		else {
			Apache::Voodoo::Exception::RunTime->throw( error => join '', @_ );
		}
	};

	return $self;
}

sub handler {
	my $self = shift;
	my $r    = shift;

####
#### not env specific
####
	$self->{mp}->set_request($r);

	my $id = $self->{mp}->get_app_id();
	unless (defined($id)) {
		warn "PerlSetVar ID not present in configuration.  Giving up\n";
		return $self->{mp}->server_error;
	}

	unless (defined($self->{'apps'}->{$id})) {
		warn "application id '$id' unknown. Valid ids are: ".join(",",keys %{$self->{'apps'}})."\n";
		return $self->{mp}->server_error;
	}

	# holds all vars associated with this request
	my $run = {};

####
#### env specific
####

	####################
	# URI translation jazz to get down to a proper filename
	####################
	$run->{'uri'} = $self->{mp}->uri();
	if ($run->{'uri'} =~ /\/$/o) {
		return $self->{mp}->redirect($run->{'uri'}."index");
	}

	$run->{'filename'} = $self->{mp}->filename();

####
#### not env specific
####

   	# remove the optional trailing .tmpl
   	$run->{'filename'} =~ s/\.tmpl$//o;
   	$run->{'uri'}      =~ s/\.tmpl$//o;

	unless (-e "$run->{'filename'}.tmpl") { return $self->{mp}->declined;  }
	unless (-r "$run->{'filename'}.tmpl") { return $self->{mp}->forbidden; } 

	########################################
	# We now know we have a valid file that we need to handle
	########################################


	# local copy of currently processing host, save a few reference lookups (and a bunch o' typing)
	my $app = $self->{'apps'}->{$id};

	if ($app->{'dynamic_loading'}) {
		$app->refresh;
	}

	my $conf = $app->config();

	# Get ready to start tracing what's going on
	$run->{'app_id'}     = $id;

	$debug = $app->{'debug_handler'};

	$debug->init($self->{mp});

	if ($app->{"DEAD"}) {
		return $self->{mp}->server_error;
	}

	$debug->mark(Time::HiRes::time,"START");

	$app->{'site_root'} = $self->{mp}->site_root;
	if ($app->{'site_root'} ne "/") {
		$app->{'site_root'} =~ s:/$::;
		$run->{'uri'} =~ s/^$app->{'site_root'}//;
	}

	$debug->url($run->{'uri'});

   	# remove the beginning /
   	$run->{'uri'} =~ s/^\///o;

	$debug->mark(Time::HiRes::time,"template dir resolution");

	####################
	# Attach session
	####################
	$run->{session_handler} = $self->attach_session($app,$conf);
	$run->{session} = $run->{session_handler}->session;

	$debug->mark(Time::HiRes::time,"session attachment");
	$debug->session_id($run->{session}->{_session_id});

	if ($run->{'uri'} eq "logout") {
		$self->{mp}->set_cookie($conf->{'cookie_name'},'!','now');
		$run->{'session_handler'}->destroy();
		if($app->{'logout_is_handled'}){
			#Quick and fast, but this prevents possble sessionless processing.
			#Intended for the event that you need to handle the logout process
			#in order to return UI directives as  part of logout 
			$run->{'template_conf'} = $self->resolve_conf_section($app,$run);
			my $return = $self->generate_content($app,$run);
			return $return;
		}
		return $self->{mp}->redirect($conf->{'logout_target'});
	}

	####################
	# Connect to db
	####################
	foreach (@{$app->databases}) {
		eval {
			# we put this in app not run so that database connections persist across requests
			$app->{'dbh'} = DBI->connect_cached(@{$_});
		};
		last if $app->{'dbh'};
	
		return $self->display_host_error(
			"========================================================\n" .
			"DB CONNECT FAILED\n" .
			"$DBI::errstr\n" .
			"========================================================\n"
		);
	}

####
#### Env specific
####

	####################
	# Get paramaters 
	####################
	$run->{'input_params'} = $self->{mp}->parse_params($conf->{'upload_size_max'});
	unless (ref($run->{'input_params'})) {
		# something went boom
		return $self->display_host_error($run->{'input_params'});
	}

	$debug->mark(Time::HiRes::time,"parameter parsing");
	$debug->params($run->{'input_params'});

	####################
	# History capture 
	####################
	if ($self->{mp}->is_get && 
		!$run->{input_params}->{ajax_mode} &&
		!$run->{input_params}->{return}
		) {
		$self->history_queue($run);
		$debug->mark(Time::HiRes::time,"history capture");
	}

####
#### Not env specific
####

	####################
	# Get configuation for this template or section
	####################
	$run->{'template_conf'} = $app->resolve_conf_section($run->{'uri'});

	$debug->mark(Time::HiRes::time,"config section resolution");
	$debug->template_conf($run->{'template_conf'});

	####################
	# Generate the content
	####################
	my $return = $self->generate_content($app,$conf,$run);

	$debug->session($run->{session});
	$debug->status($return);


	####################
	# Clean up
	####################
	$run->{session_handler}->disconnect();

	$debug->mark(Time::HiRes::time,'END');
	$debug->shutdown();

	return $return;
}

sub attach_session {
	my $self = shift;
	my $app  = shift;
	my $conf = shift;

	my $session_id = $self->{'mp'}->get_cookie($conf->{'cookie_name'});
	my $session = $app->{'session_handler'}->attach($session_id,$app->{'dbh'});

	if (!defined($session_id) || $session->{'id'} ne $session_id) {
		# This is a new session, or there was an old cookie from a previous sesion,
		$self->{'mp'}->set_cookie($conf->{'cookie_name'},$session->{'id'});
	}
	elsif ($session->has_expired($conf->{'session_timeout'})) {
		# the session has expired
		$self->{'mp'}->set_cookie($conf->{'cookie_name'},'!','now');
		$session->destroy;

		return $self->{'mp'}->redirect($app->{'site_root'}."timeout");
	}

	# update the session timer
	$session->touch();

	return $session;
}

sub history_queue {
	my $self = shift;
	my $p    = shift;

	my $session = $p->{'session'};
	my $params  = $p->{'input_params'};
	my $uri     = $p->{'uri'};

	$uri = "/".$uri if $uri !~ /^\//;

	# don't put the login page in the referrer queue
	return if $uri eq "/login";

	if (!defined($session->{'history'}) ||
		$session->{'history'}->[0]->{'uri'} ne $uri) {

		# queue is empty or this is a new page
		unshift(@{$session->{'history'}}, {'uri' => $uri, 'params' => $params});
	}
	else {
		# re-entrant call to page, update the params
		$session->{'history'}->[0]->{'params'} = $params;
	}

	if (scalar(@{$session->{'history'}}) > 30) {
		# keep the queue at 10 items
		pop @{$session->{'history'}};
	}
}

sub generate_content {
	my $self = shift;
	my $app  = shift;
	my $conf = shift;
	my $run  = shift;

	my $p = {
		"dbh"           => $app->{'dbh'},
		"params"        => $run->{'input_params'},
		"session"       => $run->{'session'},
		"template_conf" => $run->{'template_conf'},
		"mp"            => $self->{'mp'},
		"uri"           => $run->{'uri'},

		# these are deprecated.  In the future get them from $p->{mp} or $p->{config}
		"document_root" => $conf->{'template_dir'},
		"dir_config"    => $self->{mp}->dir_config,
		"user-agent"    => $self->{mp}->header_in('User-Agent'),
		"r"             => $self->{mp}->{r},
		"themes"        => $conf->{'themes'}
	};

	my $c=0;
	my $template_params = {};

	my $e;

	# call each of the pre_include modules followed by our page specific module followed by our post_includes
	foreach my $c ( 
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $run->{'template_conf'}->{'pre_include'}) ),
		$app->map_uri($run->{'uri'}),
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $run->{'template_conf'}->{'post_include'}) )
		) {

		if (defined($app->{'controllers'}->{$c->[0]}) && $app->{'controllers'}->{$c->[0]}->can($c->[1])) {
			my $obj    = $app->{'controllers'}->{$c->[0]};
			my $method = $c->[1];

			my $return;
			eval {
				$return = $obj->$method($p);
			}; 
			if ($@) {
				$e = $@;
				last;
			}

			$debug->mark(Time::HiRes::time,"handler for ".$c->[0]." ".$c->[1]);
			$debug->return_data($c->[0],$c->[1],$return);

			if (ref($return) eq "ARRAY") {
				if    ($return->[0] eq "REDIRECTED") {
					return $self->{mp}->redirect($self->adjust_url($app->{'site_root'},$return->[1]));
				}
				elsif ($return->[0] eq "DISPLAY_ERROR") {     
					$p->{'uri'} = 'display_error';
					$template_params->{'error_string'} = $return->[1];
					$template_params->{'error_url'}    = ($return->[2])?$return->[2]:$app->{'site_root'}."index";
					last;
				}
				elsif ($return->[0] eq "ACCESS_DENIED") {
					$p->{'uri'} = (defined($return->[2]))?$return->[2]:'access_denied';
					$template_params->{'error_string'} = $return->[1];
					last;
				}
				elsif ($return->[0] eq "RAW_MODE") {
					$self->{mp}->header_out(each %{$return->[3]}) if $return->[3];
					$self->{mp}->content_type($return->[1] || "text/html");
					$self->{mp}->print($return->[2]);
					return $self->{mp}->ok;
				}
				else {
					warn "AIEEE!! $return->[0] is not a supported command\n";
					$return = {};
				}
			}

			foreach my $k ( keys %{$return}) {
				$template_params->{$k} = $return->{$k};
			}
			$debug->mark(Time::HiRes::time,"result packing");

			last if $p->{_stop_chain_};
		}
	}

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


sub adjust_url {
	my $self = shift;

	my $root = shift;
	my $uri  = shift;

	if ($root ne "/" && $uri =~ /^\//o) {
		return $root.$uri;
	}
	else {
		return $uri;
	}
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

sub restart { 
	my $self = shift;

	# wipe / initialize host information
	$self->{'apps'} = {};

	warn "Voodoo starting...\n";

	my $cf_name      = $self->{'constants'}->conf_file();
	my $install_path = $self->{'constants'}->install_path();

	warn "Scanning: $install_path\n";

	unless (opendir(DIR,$install_path)) {
		warn "Can't open dir: $!\n";
		return;
	}

	foreach my $id (readdir(DIR)) {
		next unless $id =~ /^[a-z]\w*$/i;
		my $fp = File::Spec->catfile($install_path,$id,$cf_name);
		next unless -f $fp;
		next unless -r $fp;

		warn "starting host $id\n";

		my $app = Apache::Voodoo::Application->new($id,$self->{'constants'});

		# check to see if we can get a database connection
		foreach (@{$app->databases}) {
			eval {
				# we put this in app not run so that database connections persist across requests
				$app->{'dbh'} = DBI->connect_cached(@{$_});
			};
			last if $app->{'dbh'};
			
			warn "========================================================\n";
			warn "DB CONNECT FAILED FOR $id\n";
			warn "$DBI::errstr\n";
			warn "========================================================\n";
		}

		$self->{'apps'}->{$id} = $app;
		
		# notifiy of start errors
		$self->{'apps'}->{$id}->{"DEAD"} = 0;

		if ($app->{'errors'}) {
			warn "$id has ".$app->{'errors'}." errors\n";
			if ($app->{'halt_on_errors'}) {
				warn " (dropping this site)\n";

				$self->{'apps'}->{$app->{'id'}}->{"DEAD"} = 1;

				return;
			}
			else {
				warn " (loading anyway)\n";
			}
		}
	}
	closedir(DIR);
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
