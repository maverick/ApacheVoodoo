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

$VERSION = '2.01';

use strict;

use Apache::DBI;	
use Apache::Session::File;

use HTML::Template;
use Time::HiRes;

use Data::Dumper;
$Data::Dumper::Terse = 1;

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;
use Apache::Voodoo::ServerConfig;
use Apache::Voodoo::Debug;
use Apache::Voodoo::DisplayError;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 ); 
			  
# setup primary hook to mod_perl depending on which version we're running
BEGIN {
	if (MP2) {
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

# untie does something weird, bad and wrong.  
# The *ONLY* way to properly untie is with the *ORIGINAL* variable that was tied too.
# Thus, this is a global variable so that we can get to it from elsewhere in the code.
# *barf*
my %session;

# Debugging object.  I don't like using an 'our' variable, but it is just too much
# of a pain to pass this thing around to everywhere it needs to go. So, I just tell
# myself that this is STDERR on god's own steroids so I can sleep at night.
our $debug = Apache::Voodoo::Debug->new();

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{'mp'}        = Apache::Voodoo::MP->new();
	$self->{'constants'} = Apache::Voodoo::Constants->new();

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

	unless (defined($self->{'hosts'}->{$id})) {
		$self->{mp}->error("host id '$id' unknown. Valid ids are: ".join(",",keys %{$self->{'hosts'}}));
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
	$debug->reset();
	$debug->mark("Start");

	# local copy of currently processing host, save a few reference lookups (and a bunch o' typing)
	my $host = $self->{'hosts'}->{$id};

	if ($host->{'dynamic_loading'}) {
		$host->refresh;
	}

	if ($host->{"DEAD"}) {
		return $self->{mp}->server_error;
	}

	$host->{'site_root'} = $self->{mp}->site_root;
	if ($host->{'site_root'} ne "/") {
		$host->{'site_root'} =~ s:/$::;
		$run->{'uri'} =~ s/^$host->{'site_root'}//;
	}

	($host->{'template_dir'}) = ($run->{'filename'} =~ /^(.*)$run->{'uri'}$/);

   	# remove the beginning /
   	$run->{'uri'} =~ s/^\///o;

	$debug->mark("template dir resolution");

	####################
	# connect to db
	####################
	foreach (@{$host->{'dbs'}}) {
		$host->{'dbh'} = DBI->connect_cached(@{$_});
		last if $host->{'dbh'};
	
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
	$run->{'session'} = $self->attach_session($host);
	$debug->mark("session attachment");

	if ($run->{'uri'} eq "logout") {
		# handle logout
		$self->{mp}->err_header_out("Set-Cookie" => $host->{'cookie_name'} . "='!'; path=/");
		tied(%{$run->{'session'}})->delete();
		$self->untie();
		return $self->{mp}->redirect($host->{'site_root'}."index");
	}

	####################
	# get paramaters 
	####################
	$run->{'input_params'} = $self->{mp}->parse_params($host->{'upload_size_max'});
	unless (ref($run->{'input_params'})) {
		# something went boom
		return $self->display_host_error($run->{'input_params'});
	}

	$debug->mark("parameter parsing");

	####################
	# history capture 
	####################
	if ($self->{mp}->is_get && !$run->{input_params}->{ajax_mode}) {
		$self->history_queue($run);
		$debug->mark("history capture");
	}

	####################
	# see if the user has switched debugging on or off 
	# They can only do this if the server is already in debug mode, 
	# it would be a security issue otherwise.
	####################
	my $debug_enabled = $host->{'debug'};
	if ($debug_enabled) {
		if (defined($run->{'input_params'}->{'DEBUG'})) {
			$run->{'session'}->{'DEBUG'} = ($run->{'input_params'}->{'DEBUG'} =~ /^(on|1)$/i)?1:0;
		}

		if (defined($run->{'session'}->{'DEBUG'})) {
			$debug_enabled = $run->{'session'}->{'DEBUG'};
		}
	}
	$debug->enable($debug_enabled);

	####################
	# Get configuation for this template or section
	####################
	$run->{'template_conf'} = $self->resolve_conf_section($host,$run);
	$debug->mark("config section resolution");

	####################
	# prepare main body contents
	####################
	my $return = $self->generate_html($host,$run);

	$self->untie();

	$debug->reset();

	return $return;
}

sub attach_session {
	my $self = shift;
	my $host = shift;

	my ($cookie_val) = ($self->{mp}->header_in('Cookie') =~ /$host->{'cookie_name'}=([0-9a-z]+)/);
	my $sess_id = $cookie_val;

	# my fist big complaint about Apache::Ssssion, 
	# There's now way to validate a session id other then this eval.
	eval {
		tie(%session,'Apache::Session::File',$sess_id, 
			{
				Directory     => $host->{'session_dir'},
				LockDirectory => $host->{'session_dir'}
			}
		) || die "Global data not available: $!";	
	};
	if ($@) {
		undef $sess_id;
		tie(%session,'Apache::Session::File',$sess_id,
			{
				Directory     => $host->{'session_dir'},
				LockDirectory => $host->{'session_dir'}
			}
		) || die "Global data not available: $!";	
	}

	# if this was a new session, or there was an old cookie from a previous sesion,
	# set the session cookie.
	if (!defined($sess_id) || $sess_id ne $cookie_val) {
		# err_headers get sent on both successful and errored requests
		$self->{mp}->err_header_out("Set-Cookie" => "$host->{'cookie_name'}=$session{_session_id}; path=/");
		$session{'timestamp'} = time;
	}

	# see if the session has expired
	if ($host->{'session_timeout'} > 0 && $session{'timestamp'} < (time - ($host->{'session_timeout'}*60))) {
		# use err header out since this is a redirect
		$self->{mp}->err_header_out("Set-Cookie" => $host->{'cookie_name'} . "='!'; path=/");
		tied(%session)->delete();
		return $self->{mp}->redirect($host->{'site_root'}."timeout");
	}
	else {
		$session{'timestamp'} = time;
	}

	return \%session;
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

	if (scalar(@{$session->{'history'}}) > 10) {
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
	my $host = shift;
	my $run  = shift;

	if (exists($host->{'template_conf'}->{$run->{'uri'}})) {
		# one specific to this page
		return $host->{'template_conf'}->{$run->{'uri'}};
	}

	foreach (sort { length($b) <=> length($a) } keys %{$host->{'template_conf'}}) {
		if ($run->{'uri'} =~ /^$_$/) {
			# match by uri regexp
			return $host->{'template_conf'}->{$_};
		}
	}

	# not one, return the default
	return $host->{'template_conf'}->{'default'};
}

sub generate_html {
	my $self = shift;
#	my $r    = shift;
	my $host = shift;
	my $run  = shift;

	my $c=0;
	my $t_params;
	# call each of the pre_include modules followed by our page specific module followed by our post_includes
	foreach ( 
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $run->{'template_conf'}->{'pre_include'}) ),
		$host->map_uri($run->{'uri'}),
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $run->{'template_conf'}->{'post_include'}) )
		) {


		if (defined($host->{'handlers'}->{$_->[0]}) && $host->{'handlers'}->{$_->[0]}->can($_->[1])) {
			my $obj    = $host->{'handlers'}->{$_->[0]};
			my $method = $_->[1];

			my $return;
			eval {

				$return = $obj->$method(
					{
						"dbh"           => $host->{'dbh'},
						"dir_config"    => $self->{mp}->dir_config,
						"document_root" => $host->{'template_dir'},
						"params"        => $run->{'input_params'},
						"session"       => $run->{'session'},
						"template_conf" => $run->{'template_conf'},
						"themes"        => $host->{'themes'},
						"uri"           => $run->{'uri'},
						"user-agent"    => $self->{mp}->header_in('User-Agent'),
						"r"             => $self->{mp}->{r}
					}
				);
			};
			if ($@) {
				# caught a runtime error from perl
				if ($host->{'debug'}) {
					return $self->display_host_error("Module: $_->[0] $method\n$@");
				}
				else {
					return $self->{mp}->server_error;
				}
			}

			$debug->mark("handler for ".$_->[0]." ".$_->[1]);

			if (ref($return) eq "ARRAY") {
				if    ($return->[0] eq "REDIRECTED") {
					if ($host->{'site_root'} ne "/" && $return->[1] =~ /^\//o) {
						$return->[1] =~ s/^\//$host->{'site_root'}/;
					}
					return $self->{mp}->redirect($return->[1]);
				}
				elsif ($return->[0] eq "DISPLAY_ERROR") {     
					my $ts = Time::HiRes::time;
					$run->{'session'}->{"er_$ts"}->{'error'}  = $return->[1];
					$run->{'session'}->{"er_$ts"}->{'return'} = $return->[2];
					$self->untie();
					return $self->{mp}->redirect($host->{'site_root'}."display_error?error=$ts",1);
				}
				elsif ($return->[0] eq "ACCESS_DENIED") {
					if (defined($return->[1])) {
						if ($return->[1] =~ /^\//o) {
							$return->[1] =~ s/^/$host->{'site_root'}/;
						}
						return $self->{mp}->redirect($return->[1]);
					}
					elsif (-e $host->{'template_dir'}."/access_denied.tmpl") {
						return $self->{mp}->redirect($host->{'site_root'}."access_denied");
					}
					else {
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

			# this benchmarks about 3 times faster than any other technique. weird but true.
			while (my ($k,$v) = each %{$return}) {
				$t_params->{$k} = $v;
			}
			$debug->mark("result packing");
		}
	}


	# pack up the params. note the presidence: module overrides template_conf
	my $template_params;
	while (my ($k,$v) = each %{$run->{'template_conf'}}) { $template_params->{$k} = $v; }
	while (my ($k,$v) = each %{$t_params})               { $template_params->{$k} = $v; }

	my $skeleton_file;
	if ($host->{'use_themes'}) {
		# time to do the theme processing stuff.
		my $return = $self->{'theme_handler'}->handle(
			{
				"document_root" => $host->{'template_dir'},
				"themes"        => $host->{'themes'},
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

	my $skeleton;
	eval {
		# load the template
		my $template = HTML::Template->new(
			'filename'          => $host->{'template_dir'}."/".$run->{'uri'}.".tmpl",
			'path'              => [ $host->{'template_dir'} ],
			'shared_cache'      => $host->{'shared_cache'},
			'ipc_max_size'      => $host->{'ipc_max_size'},
			'loop_context_vars' => $host->{'context_vars'},
			'global_vars'       => 1,
			'die_on_bad_params' => 0,
		);

		$debug->mark("template open");

		$template_params->{'SITE_ROOT'} = $host->{'site_root'};

		# pack up the params
		$template->param($template_params);

		# generate the main body contents
		$template_params->{'_MAIN_BODY_'} = $template->output;
		
		$debug->mark("main body content");

		# load the skeleton template
		$skeleton = HTML::Template->new(
			'filename'          => $host->{'template_dir'}."/$skeleton_file.tmpl",
			'path'              => [ $host->{'template_dir'} ],
			'shared_cache'      => $host->{'shared_cache'},
			'ipc_max_size'      => $host->{'ipc_max_size'},
			'loop_context_vars' => $host->{'context_vars'},
			'global_vars'       => 1,
			'die_on_bad_params' => 0,
		);
		$debug->mark("skeleton open");

		# generate the debugging report
		$template_params->{'_DEBUG_'} = $debug->report(
			'params'  => $t_params,
			'conf'    => $run->{'template_conf'},
			'session' => $run->{'session'}
		);

		# pack everything into the skeleton
		$skeleton->param($template_params);
	};
	if ($@) {
		# caught a runtime error from perl
		return $self->display_host_error($@);
	}

	# output page
	$self->{mp}->content_type($run->{'template_conf'}->{'content-type'} || "text/html");

	$self->{mp}->print($skeleton->output);

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
	$self->{'hosts'} = {};

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
		my $fp = "$install_path/$id/$cf_name";
		next unless -f $fp;
		next unless -r $fp;

		$self->{mp}->error("starting host $id");

		my $conf = Apache::Voodoo::ServerConfig->new($id,$fp);

		# check to see if we can get a database connection
		foreach (@{$conf->{'dbs'}}) {
			$conf->{'dbh'} = DBI->connect(@{$_});
			last if $conf->{'dbh'};
			
			$self->{mp}->error("========================================================");
			$self->{mp}->error("DB CONNECT FAILED FOR $id");
			$self->{mp}->error("$DBI::errstr");
			$self->{mp}->error("========================================================");
		}

		# if the database connection was invalid (or there wasn't one, this would 'die'.  
		# eval wrap is to trap and trow away this possible error ('cause we don't care)
		eval {
			$conf->{'dbh'}->disconnect;
		};

		$self->{'hosts'}->{$id} = $conf;
		
		# notifiy of start errors
		$self->{'hosts'}->{$id}->{"DEAD"} = 0;

		if ($conf->{'errors'}) {
			$self->{mp}->error("$id has ".$conf->{'errors'}." errors");
			if ($conf->{'halt_on_errors'}) {
				$self->{mp}->error(" (dropping this site)");

				$self->{'hosts'}->{$conf->{'id'}}->{"DEAD"} = 1;

				return;
			}
			else {
				$self->{mp}->error(" (loading anyway)");
			}
		}

		# ick..this feels wrong...don't know of a cleaner way yet.
		unless (defined($conf->{'handlers'}->{'display_error'})) {
			$conf->{'handlers'}->{'display_error'} = Apache::Voodoo::DisplayError->new();
		}

		if ($conf->{'use_themes'} && !defined($self->{'theme_handler'})) {
			# we're using themes and the theme handler hasn't been initialized yet
			require "Apache/Voodoo/Theme.pm";
			$self->{'theme_handler'} = Apache::Voodoo::Theme->new();
		}
	}
	closedir(DIR);
}

sub untie {
	my $self = shift;

	untie %session;
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
