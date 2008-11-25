=pod ####################################################################################

=head1 NAME

Apache::Voodoo::Handler - Main interface between mod_perl and Voodoo

=head1 VERSION

$Id$

=head1 SYNOPSIS
 
This is the main generic presentation module that interfaces with apache, 
handles session control, database connections, and interfaces with the 
application's page handling modules.

=cut ################################################################################
package Apache::Voodoo::Handler;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use strict;

use DBI;
use Time::HiRes;

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;
use Apache::Voodoo::Application;
use Apache::Voodoo::Debug;
use Apache::Voodoo::DisplayError;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 ); 
			  
# setup primary hook to mod_perl depending on which version we're running
BEGIN {
	if (1) {
		*handler = sub : method { shift()->handle_request(@_) };
	}
	else {
		*handler = sub ($$) { shift()->handle_request(@_) };
	}
}

# *THE* one thing that has never made any sense to me about the mod_perl universe:
# "How" to make method handlers is well documented, but MP doesn't call new() or provide
# any way of making that happen...and weirder yet, no one seems to notice.
# Thus we're left with leaving a global $self haning around long enough to copy
# replace the first arg to our handler with it.
my $self_init = Apache::Voodoo::Handler->new();

# Debugging object.  I don't like using an 'our' variable, but it is just too much
# of a pain to pass this thing around to everywhere it needs to go. So, I just tell
# myself that this is STDERR on god's own steroids so I can sleep at night.
our $debug;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{'mp'}        = Apache::Voodoo::MP->new();
	$self->{'constants'} = Apache::Voodoo::Constants->new();

	$self->{debug_root} = $self->{constants}->debug_path();
	$self->{debug_template} = $INC{"Apache/Voodoo/Handler.pm"};
	$self->{debug_template} =~ s/Handler.pm$/Debug\/html\/debug.tmpl/;

	$debug = Apache::Voodoo::Debug->new($self->{'constants'});

	if (exists $ENV{'MOD_PERL'}) {
		# let's us do a compile check outside of mod_perl
		$self->restart;
	}

	return $self;
}

sub handle_request {
	my $self = shift;
	my $r    = shift;

	unless (ref($self)) {
		$self = $self_init;
	};

	$self->{mp}->set_request($r);

	my $id = $self->{mp}->get_app_id();
	unless (defined($id)) {
		$self->{mp}->error("PerlSetVar ID not present in configuration.  Giving up");
		return $self->{mp}->server_error;
	}

	unless (defined($self->{'apps'}->{$id})) {
		$self->{mp}->error("application id '$id' unknown. Valid ids are: ".join(",",keys %{$self->{'apps'}}));
		return $self->{mp}->server_error;
	}

	# holds all vars associated with this page processing request
	my $run = {};

	$run->{'filename'} = $self->{mp}->filename();
	$run->{'uri'}      = $self->{mp}->uri();

	####################
	# URI translation jazz to get down to a proper filename
	####################
	if ($run->{'uri'} =~ /\/$/o) {
		if (-e "$run->{'filename'}/index.tmpl") { 
			return $self->{mp}->redirect($run->{'uri'}."index");
		}
		else { 
			return $self->{mp}->declined;
		}
	}

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

	# Get ready to start tracing what's going on
	$run->{'app_id'}     = $id;
	$run->{'request_id'} = $self->{mp}->request_id();
	$debug->init($id,$run->{request_id},$app->{debug});

	if ($app->{"DEAD"}) {
		return $self->{mp}->server_error;
	}

	$debug->mark("START");

	$app->{'site_root'} = $self->{mp}->site_root;
	if ($app->{'site_root'} ne "/") {
		$app->{'site_root'} =~ s:/$::;
		$run->{'uri'} =~ s/^$app->{'site_root'}//;
	}

	($app->{'template_dir'}) = ($run->{'filename'} =~ /^(.*)$run->{'uri'}$/);
	$debug->url($run->{'uri'});

   	# remove the beginning /
   	$run->{'uri'} =~ s/^\///o;

	$debug->mark("template dir resolution");

	####################
	# connect to db
	####################
	foreach (@{$app->{'dbs'}}) {
		$app->{'dbh'} = DBI->connect_cached(@{$_});
		last if $app->{'dbh'};
	
		return $self->display_host_error(
			"========================================================\n" .
			"DB CONNECT FAILED\n" .
			"$DBI::errstr\n" .
			"========================================================\n"
		);
	}

	####################
	# Attach session
	####################
	$run->{session_handler} = $self->attach_session($app);
	$run->{session} = $run->{session_handler}->session;

	$debug->mark("session attachment");
	$debug->session_id($run->{session}->{_session_id});

	if ($run->{'uri'} eq "logout") {
		# handle logout
		$self->{mp}->err_header_out("Set-Cookie" => $app->{'cookie_name'} . "='!'; path=/; HttpOnly"); # .($app->{https_cookies})?"; secure":'');
		$run->{'session_handler'}->destroy();
		return $self->{mp}->redirect($app->{'logout_target'});
#		return $self->{mp}->redirect($app->{'site_root'}."index");
	}

	####################
	# get paramaters 
	####################
	$run->{'input_params'} = $self->{mp}->parse_params($app->{'upload_size_max'});
	unless (ref($run->{'input_params'})) {
		# something went boom
		return $self->display_host_error($run->{'input_params'});
	}

	$debug->mark("parameter parsing");
	$debug->params($run->{'input_params'});

	####################
	# history capture 
	####################
	if ($self->{mp}->is_get && 
		!$run->{input_params}->{ajax_mode} &&
		!$run->{input_params}->{return}
		) {
		$self->history_queue($run);
		$debug->mark("history capture");
	}

	####################
	# Get configuation for this template or section
	####################
	$run->{'template_conf'} = $self->resolve_conf_section($app,$run);

	$debug->mark("config section resolution");
	$debug->template_conf($run->{'template_conf'});

	####################
	# prepare main body contents
	####################
	my $return = $self->generate_html($app,$run);

	$debug->session($run->{session});
	$debug->result($return);
	$run->{session_handler}->disconnect();

	$debug->mark('END');
	$debug->shutdown();
	return $return;
}

sub attach_session {
	my $self = shift;
	my $app  = shift;

	my ($session_id) = ($self->{mp}->header_in('Cookie') =~ /$app->{'cookie_name'}=([0-9a-z]+)/);
	my $instance = $app->{session_handler}->attach($session_id,$app->{dbh});

	my $session = $instance->session;

	# if this was a new session, or there was an old cookie from a previous sesion,
	# set the session cookie.
	if (!defined($session_id) || $instance->{id} ne $session_id) {
		# err_headers get sent on both successful and errored requests
		$self->{mp}->err_header_out("Set-Cookie" => "$app->{'cookie_name'}=$instance->{id}; path=/; HttpOnly"); #.($app->{https_cookies})?"; secure":'');
		$session->{'timestamp'} = time;
	}

	# see if the session has expired
	if ($app->{'session_timeout'} > 0 && $session->{'timestamp'} < (time - ($app->{'session_timeout'}*60))) {
		# use err header out since this is a redirect
		$self->{mp}->err_header_out("Set-Cookie" => $app->{'cookie_name'} . "='!'; path=/; HttpOnly"); # .($app->{https_cookies})?"; secure":'');
		$instance->destroy;
		return $self->{mp}->redirect($app->{'site_root'}."timeout");
	}
	else {
		$session->{'timestamp'} = time;
	}

	return $instance;
}

sub history_queue {
	my $self = shift;
	my $p = shift;

	my $session = $p->{'session'};
	my $params  = $p->{'input_params'};
	my $uri     = $p->{'uri'};

	$uri = "/".$uri if $uri !~ /^\//;

	# don't put the login page in the referrer queue
	return if $uri eq "/login";

	if (!defined($session->{'history'}) ||
		$session->{'history'}->[0]->{'uri'} ne $uri) {

		# queue is empty or this is a new page
		unshift(@{$session->{'history'}}, {'uri' => $uri, 'params' => $self->mkurlparams($params)});
	}
	else {
		# re-entrant call to page, update the params
		$session->{'history'}->[0]->{'params'} = $self->mkurlparams($params);
	}

	if (scalar(@{$session->{'history'}}) > 30) {
		# keep the queue at 10 items
		pop @{$session->{'history'}};
	}
}

sub mkurlparams {
	my $self = shift;
	my $p = shift;

	return join("&",map { $_."=".$p->{$_} } keys %{$p});
}

sub resolve_conf_section {
	my $self = shift;
	my $app  = shift;
	my $run  = shift;

	if (exists($app->{'template_conf'}->{$run->{'uri'}})) {
		# one specific to this page
		return $app->{'template_conf'}->{$run->{'uri'}};
	}

	foreach (sort { length($b) <=> length($a) } keys %{$app->{'template_conf'}}) {
		if ($run->{'uri'} =~ /^$_$/) {
			# match by uri regexp
			return $app->{'template_conf'}->{$_};
		}
	}

	# not one, return the default
	return $app->{'template_conf'}->{'default'};
}

sub generate_html {
	my $self = shift;
	my $app  = shift;
	my $run  = shift;

	my $c=0;
	my $t_params = {};
	# call each of the pre_include modules followed by our page specific module followed by our post_includes
	foreach my $handle ( 
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $run->{'template_conf'}->{'pre_include'}) ),
		$app->map_uri($run->{'uri'}),
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $run->{'template_conf'}->{'post_include'}) )
		) {


		if (defined($app->{'handlers'}->{$handle->[0]}) && $app->{'handlers'}->{$handle->[0]}->can($handle->[1])) {
			my $obj    = $app->{'handlers'}->{$handle->[0]};
			my $method = $handle->[1];

			my $return;
			eval {

				$return = $obj->$method(
					{
						"dbh"           => $app->{'dbh'},
						"document_root" => $app->{'template_dir'},
						"params"        => $run->{'input_params'},
						"session"       => $run->{'session'},
						"template_conf" => $run->{'template_conf'},
						"themes"        => $app->{'themes'},
						"uri"           => $run->{'uri'},
						"mp"            => $self->{mp},
						# these are deprecated.  In the future get them from $p->{mp}
						"dir_config"    => $self->{mp}->dir_config,
						"user-agent"    => $self->{mp}->header_in('User-Agent'),
						"r"             => $self->{mp}->{r}
					}
				);
			};
			if ($@) {
				# caught a runtime error from perl
				if ($app->{'debug'}) {
					return $self->display_host_error("Module: $handle->[0] $method\n$@");
				}
				else {
					return $self->{mp}->server_error;
				}
			}

			$debug->mark("handler for ".$handle->[0]." ".$handle->[1]);
			$debug->return_data($handle->[0],$handle->[1],$return);

			if (ref($return) eq "ARRAY") {
				if    ($return->[0] eq "REDIRECTED") {
					if ($app->{'site_root'} ne "/" && $return->[1] =~ /^\//o) {
						$return->[1] =~ s/^\//$app->{'site_root'}/;
					}
					return $self->{mp}->redirect($return->[1]);
				}
				elsif ($return->[0] eq "DISPLAY_ERROR") {     
					my $ts = Time::HiRes::time;
					$run->{'session'}->{"er_$ts"}->{'error'}  = $return->[1];
					$run->{'session'}->{"er_$ts"}->{'return'} = $return->[2];

					# internal redirects have always been touchy, removing for now until I can
					# figure out why it's being a pain now.
					$run->{'session_handler'}->disconnect();
					return $self->{mp}->redirect($app->{'site_root'}."display_error?error=$ts",1);

					#return $self->{mp}->redirect($app->{'site_root'}."display_error?error=$ts");
				}
				elsif ($return->[0] eq "ACCESS_DENIED") {
					if (defined($return->[2])) {
						# using the user supplied destination page
						if ($return->[2] =~ /^\//o) {
							$return->[2] =~ s/^/$app->{'site_root'}/;
						}

						if (defined($return->[1])) {
							$return->[2] .= "?error=".$return->[1];
						}
						return $self->{mp}->redirect($return->[2]);
					}
					elsif (-e $app->{'template_dir'}."/access_denied.tmpl") {
						# using the default destination page
						if (defined($return->[1])) {
							return $self->{mp}->redirect($app->{'site_root'}."access_denied?error=".$return->[1]);
						}
						else {
							return $self->{mp}->redirect($app->{'site_root'}."access_denied");
						}
					}
					else {
						# fall back on ye olde apache forbidden
						return $self->{mp}->forbidden;
					}
				}
				elsif ($return->[0] eq "RAW_MODE") {
					$self->{mp}->header_out(each %{$return->[3]}) if $return->[3];
					$self->{mp}->content_type($return->[1] || "text/html");
					$self->{mp}->print($return->[2]);
					return $self->{mp}->ok;
				}
				else {
					$self->{mp}->error("AIEEE!! $return->[0] is not a supported command");
					$return = {};
				}
			}

			foreach my $k ( keys %{$return}) {
				$t_params->{$k} = $return->{$k};
			}
			$debug->mark("result packing");
		}
	}


	# pack up the params. note the presidence: module overrides template_conf
	my $template_params = {};
	foreach my $k (keys %{$run->{'template_conf'}}) { 
		$template_params->{$k} = $run->{'template_conf'}->{$k};
	}
	foreach my $k (keys %{$t_params}) { 
		$template_params->{$k} = $t_params->{$k};
	}

	my $skeleton_file;
	if ($app->{'use_themes'}) {
		# time to do the theme processing stuff.
		my $return = $self->{'theme_handler'}->handle(
			{
				"document_root" => $app->{'template_dir'},
				"themes"        => $app->{'themes'},
				"session"       => $run->{'session'},
				"uri"           => $run->{'uri'},
			}
		);

		if (ref($return) eq "ARRAY") {
			if ($return->[0] eq "DISPLAY_ERROR") {     
				return $self->display_host_error($return->[1],1);
			}
			else {
				return $self->display_host_error("theme handler returned an unsupported type");
			}
		}

		while (my ($k,$v) = each %{$return}) { $template_params->{$k} = $v; }

		$skeleton_file = $self->{'theme_handler'}->get_skeleton();
	}
	else {
		$skeleton_file = $run->{'template_conf'}->{'skeleton'} || 'skeleton';
	}

	eval {
		# load the template
		$app->{'template_engine'}->template($run->{'uri'});
		$debug->mark("template open");

		$template_params->{'SITE_ROOT'}  = $app->{'site_root'};

		# remove once the debugging ui is complete.
		$template_params->{'DEBUG_ROOT'} = $self->{'debug_root'};

		# pack up the params
		$app->{'template_engine'}->params($template_params);

		# generate the main body contents
		$template_params->{'_MAIN_BODY_'} = $app->{'template_engine'}->output();
		$debug->mark("main body content");

		if ($debug->enabled()) {
			$app->{'template_engine'}->template_abs($self->{'debug_template'});
			$debug->mark("debug template open");

			# pack up the params
			$app->{'template_engine'}->params({
				app_id     => $run->{app_id},
				request_id => $run->{request_id},
				session_id => $run->{session}->{_session_id},
				debug_root => $self->{'debug_root'},
			});

			# generate the main body contents
			$template_params->{'_DEBUG_'} = $app->{'template_engine'}->output();
		}

		# load the skeleton template
		$app->{'template_engine'}->template($skeleton_file);
		$debug->mark("skeleton open");

		# pack everything into the skeleton
		$app->{'template_engine'}->params($template_params);
	};
	if ($@) {
		# caught a runtime error from perl
		return $self->display_host_error($@);
	}

	# output page
	$self->{mp}->content_type($run->{'template_conf'}->{'content-type'} || "text/html");

	$self->{mp}->print($app->{'template_engine'}->output());

	$app->{'template_engine'}->finish();

	$self->{mp}->flush();

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

sub restart { 
	my $self = shift;

	# wipe / initialize host information
	$self->{'apps'} = {};

	$self->{mp}->error("Voodoo starting...");

	my $cf_name      = $self->{'constants'}->conf_file();
	my $install_path = $self->{'constants'}->install_path();

	$self->{mp}->error("Scanning: $install_path");

	unless (opendir(DIR,$install_path)) {
		$self->{mp}->error("Can't open dir: $!");
		return;
	}

	foreach my $id (readdir(DIR)) {
		next unless $id =~ /^[a-z]\w*$/i;
		my $fp = File::Spec->catfile($install_path,$id,$cf_name);
		next unless -f $fp;
		next unless -r $fp;

		$self->{mp}->error("starting host $id");

		my $app = Apache::Voodoo::Application->new($id,$self->{'constants'});
		$app->setup();

		# check to see if we can get a database connection
		foreach (@{$app->{'dbs'}}) {
			$app->{'dbh'} = DBI->connect(@{$_});
			last if $app->{'dbh'};
			
			$self->{mp}->error("========================================================");
			$self->{mp}->error("DB CONNECT FAILED FOR $id");
			$self->{mp}->error("$DBI::errstr");
			$self->{mp}->error("========================================================");
		}

		# if the database connection was invalid (or there wasn't one, this would 'die'.  
		# eval wrap is to trap and trow away this possible error ('cause we don't care)
		eval {
			$app->{'dbh'}->disconnect;
		};

		$self->{'apps'}->{$id} = $app;
		
		# notifiy of start errors
		$self->{'apps'}->{$id}->{"DEAD"} = 0;

		if ($app->{'errors'}) {
			$self->{mp}->error("$id has ".$app->{'errors'}." errors");
			if ($app->{'halt_on_errors'}) {
				$self->{mp}->error(" (dropping this site)");

				$self->{'apps'}->{$app->{'id'}}->{"DEAD"} = 1;

				return;
			}
			else {
				$self->{mp}->error(" (loading anyway)");
			}
		}

		# ick..this feels wrong...don't know of a cleaner way yet.
		unless (defined($app->{'handlers'}->{'display_error'})) {
			$app->{'handlers'}->{'display_error'} = Apache::Voodoo::DisplayError->new();
		}

		if ($app->{'use_themes'} && !defined($self->{'theme_handler'})) {
			# we're using themes and the theme handler hasn't been initialized yet
			require "Apache/Voodoo/Theme.pm";
			$self->{'theme_handler'} = Apache::Voodoo::Theme->new();
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
