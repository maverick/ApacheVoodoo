#####################################################################################

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

use strict;

use Apache;
use Apache::Constants qw(:response M_GET);
use Apache::Session::File;

use Apache::DBI;	

use HTML::Template;
use Time::HiRes;

use Data::Dumper;
$Data::Dumper::Terse = 1;

use Apache::Voodoo::ServerConfig;
use Apache::Voodoo::Debug;
use Apache::Voodoo::display_error;

######################################
# GLOBAL CONFIG VARIABLES            #
# set once at compile time by init() #
######################################

# untie is weird, bad and wrong.  
# The *ONLY* way to properly untie is with the *ORIGINAL* variable that was tied too.
# Thus, this is a global variable so that we can get to it from elsewhere in the code
# *barf*
my %session;

# Debugging object.  I don't like using an 'our' variable, but it is just too much
# of a pain to pass this thing around to everywhere it needs to go. So, I just tell
# myself that this is STDERR on god's own steroids so I can sleep at night.
our $debug = Apache::Voodoo::Debug->new();

$Apache::Voodoo::Handler = bless {};

sub handle($$) {
	my $self = shift;
	my $r    = shift;

	my $id = $r->dir_config("ID");
	unless (defined($id)) {
		$r->log_error("PerlSetVar ID not present in configuration.  Giving up");
		return 503;
	}

	unless (defined($self->{'hosts'}->{$id})) {
		$r->log_error("host id '$id' unknown");
		return 503;
	}

	# holds all vars associated with this page processing request
	my $run = {};

	$run->{'filename'} = $r->filename();
	$run->{'uri'}      = $r->uri();

	####################
	# URI translation jazz to get down to a proper filename
	####################
	if ($run->{'uri'} =~ /\/$/o) {
		if (-e "$run->{'filename'}/index.tmpl") { 
			return $self->redirect($r,$run->{'uri'}."index");
		}
		else { 
			return DECLINED;
		}
	}

   	# remove the optional trailing .tmpl
   	$run->{'filename'} =~ s/\.tmpl$//o;
   	$run->{'uri'}      =~ s/\.tmpl$//o;

	unless (-e "$run->{'filename'}.tmpl") {  return DECLINED;  }
	unless (-r "$run->{'filename'}.tmpl") {  return FORBIDDEN; }

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
		return 503;
	}

	$host->{'site_root'} = $r->dir_config("SiteRoot") || "/";
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
	
		$self->display_host_error($r,
			"========================================================\n" .
			"DB CONNECT FAILED\n" .
			"$DBI::errstr\n" .
			"========================================================\n"
		);
		return OK;
	}

	####################
	# Attach session
	####################
	$run->{'session'} = $self->attach_session($r,$host);
	$debug->mark("session attachment");

	if ($run->{'uri'} eq "logout") {
		# handle logout
		$r->err_header_out("Set-Cookie" => $host->{'cookie_name'} . "='!'; path=/");
		tied(%{$run->{'session'}})->delete();
		$self->untie();
		return $self->redirect($r,$host->{'site_root'}."index");
	}

	####################
	# get paramaters 
	####################
	$run->{'input_params'} = $self->parse_params($r);
	$debug->mark("parameter parsing");

	####################
	# history capture 
	####################
	$self->history_queue($run);
	$debug->mark("history capture");

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
	$debug->{'enabled'} = $debug_enabled;

	####################
	# Get configuation for this template or section
	####################
	$run->{'template_conf'} = $self->resolve_conf_section($host,$run);
	$debug->mark("config section resolution");

	####################
	# prepare main body contents
	####################
	my $return = $self->generate_html($r,$host,$run);

	$self->untie();

	$debug->reset();

	return $return;
}

sub parse_params {
	my $self = shift;
	my $r    = shift;

	my %params;
	my @p = $r->method eq 'POST' ? $r->content : $r->args;

	# no we step through the list
	for (my $i=0; $i <= $#p; $i += 2) {
		if (defined($params{$p[$i]})) {
			# this is a param we've seen before
			if (ref($params{$p[$i]})) {
				# this isn't the first duplicate, so we just push onto the existing array
				push(@{$params{$p[$i]}},$p[$i+1]);
			}
			else {
				# this is the first duplicate, make an array
				$params{$p[$i]} = [ $params{$p[$i]}, $p[$i+1] ];
			}
		}
		else {
			# haven't seen this one before, or it's a singlular param
			$params{$p[$i]} = $p[$i+1];
		}
	}

	return \%params;
}

sub attach_session {
	my $self = shift;

	my $r    = shift;
	my $host = shift;

	# read the session id either from a note passed down by a previous module, or out of a cookie.
	my ($cookie_val) = ($r->header_in('Cookie') =~ /$host->{'cookie_name'}=([0-9a-z]+)/);
	my $sess_id = $r->notes('SESSION_ID') || $cookie_val;

	# my fist big complaint about Apache::Ssssion, 
	# There's now way to validate a session id other then this eval.
	eval {
		tie(%session,'Apache::Session::File',$sess_id, { Directory => $host->{'session_dir'}, LockDirectory => $host->{'session_dir'} }) || die "Global data not available: $!";	
	};
	if ($@) {
		undef $sess_id;
		tie(%session,'Apache::Session::File',$sess_id, { Directory => $host->{'session_dir'}, LockDirectory => $host->{'session_dir'} }) || die "Global data not available: $!";	
	}

	# if this was a new session, or there was an old cookie from a previous sesion,
	# set the session cookie.
	if (!defined($sess_id) || $sess_id ne $cookie_val) {
		$r->err_header_out("Set-Cookie" => "$host->{'cookie_name'}=$session{_session_id}; path=/");	# err_headers get sent on both successful and errored requests
		$session{'timestamp'} = time;
	}

	# see if the session has expired
	if ($host->{'session_timeout'} > 0 && $session{'timestamp'} < (time - ($host->{'session_timeout'}*60))) {
		$r->err_header_out("Set-Cookie" => $host->{'cookie_name'} . "='!'; path=/");  # use err header out since this is a redirect
		tied(%session)->delete();
		return $self->redirect($r,$host->{'site_root'}."timeout");
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

	my $config_sec = undef;
	if (exists($host->{'template_conf'}->{$run->{'uri'}})) {
		# one specific to this page
		$config_sec = $run->{'uri'};
	}
	else {
		foreach (sort { length($b) <=> length($a) } keys %{$host->{'template_conf'}}) {
			if ($run->{'uri'} =~ /^$_$/) {
				$config_sec = $_;
				last;
			}
		}
	}

	my %template_conf = %{$host->{'template_conf'}->{'default'}};

	# add the page specific section if it exists...
	if (defined($host->{'template_conf'}->{$config_sec})) {
		@template_conf{keys %{$host->{'template_conf'}->{$config_sec}}} = values %{$host->{'template_conf'}->{$config_sec}};
	}

	return \%template_conf;
}

sub generate_html {
	my $self = shift;
	my $r    = shift;
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
						"dbconn"        => $host->{'dbh'},		#DEPRECATED
						"dir_config"    => $r->dir_config,
						"document_root" => $host->{'template_dir'},
						"params"        => $run->{'input_params'},
						"parameters"    => $run->{'input_params'},	#DEPRECATED
						"session"       => $run->{'session'},
						"template_conf" => $run->{'template_conf'},
						"themes"        => $host->{'themes'},
						"uri"           => $run->{'uri'},
						"user-agent"    => $r->header_in('User-Agent')
					}
				);
			};
			if ($@) {
				# caught a runtime error from perl
				if ($host->{'debug'}) {
					$self->display_host_error($r,"Module: $_->[0] $method\n$@");
					return OK;
				}
				else {
					return SERVER_ERROR;
				}
			}

			$debug->mark("handler for ".$_->[0]." ".$_->[1]);

			if (ref($return) eq "ARRAY") {
				if    ($return->[0] eq "REDIRECTED") {
					if ($host->{'site_root'} ne "/" && $return->[1] =~ /^\//o) {
						$return->[1] =~ s/^\//$host->{'site_root'}/;
					}
					return $self->redirect($r,$return->[1]);
				}
				elsif ($return->[0] eq "DISPLAY_ERROR") {     
					my $ts = Time::HiRes::time;
					$run->{'session'}->{"er_$ts"}->{'error'}  = $return->[1];
					$run->{'session'}->{"er_$ts"}->{'return'} = $return->[2];

					return $self->redirect($r,$host->{'site_root'}."display_error?error=$ts",1);
				}
				elsif ($return->[0] eq "ACCESS_DENIED") {
					if (defined($return->[1])) {
						if ($return->[1] =~ /^\//o) {
							$return->[1] =~ s/^/$host->{'site_root'}/;
						}
						return $self->redirect($r,$return->[1]);
					}
					else {
						return FORBIDDEN;
					}
				}
				elsif ($return->[0] eq "RAW_MODE") {
					$r->headers_out->set(each %{$return->[3]}) if $return->[3];
					$r->send_http_header($return->[1] || "text/html");
					$r->print($return->[2]);
					return OK;
				}
				else {
					print STDERR "AIEEE!! $return->[0] is not a supported command\n";
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
				$self->display_host_error($r,$return->[1],1);
			}
			else {
				$self->display_host_error($r,"theme handler returned and unsupported type");
			}
			return OK;
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
		$self->display_host_error($r,$@);
		return OK;
	}

	# output page
	$r->send_http_header($run->{'template_conf'}->{'content-type'} || "text/html");

	$r->print($skeleton->output);

	$r->rflush();

	return OK;
}


sub display_host_error {
	my $self  = shift;
	my $r     = shift;
	my $error = shift;

	$r->send_http_header("text/html");
	$r->print("<h2>The following error was encountered while processing this request:</h2>");
	$r->print("<pre>$error</pre>");

	$r->rflush();
}

sub restart($$) { 
	my $self = shift;
	my $r    = shift;

	print STDERR "Voodoo starting...\n";

	# wipe / initialize host information
	$self->{'hosts'} = {};

	my $conf_dir = $r->server_root_relative("conf/voodoo");
	opendir(DIR,$conf_dir) || die "Can't open configuration dir: $!";
	foreach (readdir(DIR)) {
		next unless $_ =~ /[a-zA-Z]\w*\.conf$/;
		next unless -f "$conf_dir/$_";
		next unless -r "$conf_dir/$_";

		print STDERR "starting host $_\n";

		$self->start_host("$conf_dir/$_");
	}
	closedir(DIR);
}


sub start_host {
	my $self = shift;
	my $conf = Apache::Voodoo::ServerConfig->new(shift);

	# check to see if we can get a database connection
	foreach (@{$conf->{'dbs'}}) {
		$conf->{'dbh'} = DBI->connect(@{$_});
		last if $conf->{'dbh'};
		
		print STDERR "========================================================\n";
		print STDERR "DB CONNECT FAILED FOR ".$conf->{'id'}."\n";
		print STDERR "$DBI::errstr\n";
		print STDERR "========================================================\n";
	}

	# if the database connection was invalid (or there wasn't one, this would 'die'.  
	# eval wrap is to trap and trow away this possible error ('cause we don't care)
	eval {
		$conf->{'dbh'}->disconnect;
	};

	$self->{'hosts'}->{$conf->{'id'}} = $conf;
	
	# notifiy of start errors
	$self->{'hosts'}->{$conf->{'id'}}->{"DEAD"} = 0;

	if ($conf->{'errors'}) {
		print STDERR $conf->{'id'}." has ".$conf->{'errors'}." errors";
		if ($conf->{'halt_on_errors'}) {
			print STDERR " (dropping this site)\n";

			$self->{'hosts'}->{$conf->{'id'}}->{"DEAD"} = 1;

			return;
		}
		else {
			print STDERR " (loading anyway)\n";
		}
	}

	# ick..this feels wrong...don't know of a cleaner way yet.
	unless (defined($conf->{'handlers'}->{'display_error'})) {
		$conf->{'handlers'}->{'display_error'} = Apache::Voodoo::display_error->new();
	}

	if ($conf->{'use_themes'} && !defined($self->{'theme_handler'})) {
		# we're using themes and the theme handler hasn't been initialized yet
		require "Voodoo/Theme.pm";
		$self->{'theme_handler'} = Apache::Voodoo::Theme->new();
	}
}

sub untie {
	my $self = shift;

	untie %session;
}

sub redirect {
	my $self     = shift;
	my $r        = shift;
	my $loc      = shift;
	my $internal = shift;

	if ($r->method eq "POST") {
		$r->method_number(M_GET);
		$r->method('GET');
		$r->headers_in->unset('Content-length');

		$r->header_out("Location" => $loc);
		$r->status(REDIRECT);
		$r->send_http_header;
		return REDIRECT;
	}
	elsif ($internal) {
		$self->untie();
		$r->internal_redirect($loc);
		return OK;
	}
	else {
		$r->header_out("Location" => $loc);
		return REDIRECT;
	}
}

sub html_tidy {
	my $lines = shift;
	foreach (@{$lines}) {
		s/^\s*/ /;
		s/\s*$/ /;
	}
}

1;

################################################################################
=head1 APACHE CONFIGURATION

There are a couple of setup steps to begin writing an app with Voodoo, the following sections
describe those steps.  Some basic understanding of how mod_perl interacts with Apache would be
helpful ;)

=head2 Example Configuration

  # load these at server start (optional, slighty quicker startup time)
  PerlModule Apache::DBI
  PerlModule Apache::Session
  PerlModule HTML::Template

  # load the Apache Handler
  PerlModule Apache::Voodoo::Handler

  # hook in the restart function
  PerlRestartHandler $Apache::Voodoo::Handler->restart

 <Directory /data/sites/test_app/html>
    SetHandler perl-script
    PerlHandler $Apache::Voodoo::Handler->handle
    PerlSetVar ID test_app

    Options Indexes Includes FollowSymLinks
    AllowOverride None

    Order allow,deny
    Allow from all
 </Directory>

The directory block may be repeated as many times as necessary.  Directory Aliases and Virtual Hosts may also
be used in the same manner.

=over 4

=item PerlModule Apache::Voodoo::Handler

Loads Voodoo.  This line must be present somewhere inside the 'main' section of the
apache configuration file...ie. not within a <directory> or <virtual> block.

=item SetHandle perl-script

Tells Apache that a mod_perl is going to be use for this directory or virtual host
	
=item PerlHandler $Apache::Voodoo::Handler->handle
	
Tells Apache what method to call to handle requests for this directory

=item PerlSetVar ID name_of_your_app

This let's Voodoo know what application is attached to this directory.  You can run any number of 
Voodoo powered sites under a single instance of Apache.  This is also corresponds to the name of
the configuration file, and base package name (unless overridden) of your application.  Names matching 
/[a-z][\w-]*/i are valid.

=back

=head1 VOODOO CONFIGURATION FILE

Voodoo uses the L<Config/General> module for its configuration files.  See its documentation for more
information on its syntax rules.

Configuration files for each of the hosts that run under Voodoo are kept in <ServerRoot>/conf/voodoo.
The name of the file is 'value of the ID param'.conf, in our example, it would be 'test_app.conf'.

This is the identifier for this application. This is also used as the top level package name that Voodoo will use in 
loading all other modules.  This can be overridden with the optional BASE_PACKAGE directive.

See L<perlobj> for more information on objects

=head2 Example Configuration

	cookie_name  = TEST_APP_SID
	session_timeout = 0
	shared_cache    = 0
	session_dir  = /usr/local/apache/sessions/test_app
	debug = 1

	<database>
		connect  = "dbi:mysql:database=test_app;host=127.0.0.1;mysql_connect_timeout=2"
		username = "test_user"
		password = "test_password"
	</database>
	
	<modules>
		login
		admin::login_history
	</modules>

	<includes>
		date
		main_menu
	</includes>

	<template_conf>
		<default>
			skeleton = skeleton.tmpl
			pre_include = date
			post_include = main_menu
		</default>
	</template_conf>

=over 4

=item cookie_name

This is and optional parameter that sets the name of the cookie used by Voodoo 
for session identification.  If it is not supplied the cookie name will be set to $ID."_SID"

=item session_timeout

Number of minutes before a cookie expires.  Set to 0 for no expiration.

=item shared_cache

Whether or not to use Shared memory for caching of templates. typically 0 for development
and 1 for production

=item database

This is a list of database connect info.  Datbases are connected to in the order listed. 
If the first connection fails the next in the list is used.  An error message is generated 
in the Apache error log file on a failed connection, but no other action is taken.  
There are good database monitoring packages out there :) .  The contents of each array element 
is passed directly to DBI->connect

=item session_dir

This is the directory that Apache::Session will use to store session information

=item debug

Enables or disables the debug() method from Apache::Voodoo. and its associated output on each page.  See L<Apache::Voodoo::Debug> for more information.

=item halt_on_errors

If set to 1, this causes the server to return a 503 (server temprary unavailable) message 
for the host if any modules fail to load.  Defaults to 1

=item modules

This contains the list of page handling modules that will be loaded by Voodoo.
Note that the modules names do not contain the base package name.

=item includes

This contains a list of modules that can be used on a per page basis to inject extra info 
into the output.  For example, if you wish to have the current date and time appear on every page,
create a module that returns that info, include it in this list and add it to the template_conf section
accordingly.

=item template_conf

The entries here are regular expression entries that match one or more page with the site.
Each section may be used to control certain aspects of how Voodoo presents the page.
The magic entry <default> matches any page that doesn't have another matching entry.
Standard items are:

=over 4

=item skeleton

which skeleton template to use

=item pre_include

a list of include modules to call on this page, BEFORE the main page handling module

=item post_include

a list of include modules to call on this page, AFTER the main page handling module

=item content-type

content type for the output.  Defaults to text/html

=back

Any other params will be passed to the tempalte directly.

=head1 PAGE MODULES

Each page module must inherit from Apache::Voodoo.  This modules provides the new() method to 
make the package a proper object under Voodoo, along with some other minor black magic.  
Inheriting from this module provides access to some essential methods for interacting 
with Voodoo.  See L<Apache::Voodoo>.

=cut ################################################################################