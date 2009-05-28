=pod ####################################################################################

=head1 NAME

Apache::Voodoo::Engine

=head1 VERSION

$Id: Handler.pm 11537 2008-12-11 21:36:23Z medwards $

=head1 SYNOPSIS
 
=cut ################################################################################
package Apache::Voodoo::Engine;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;

use File::Spec;
use DBI;
use Time::HiRes;

use Apache::Voodoo::Constants;
use Apache::Voodoo::Application;
use Apache::Voodoo::Exception;

# Debugging object.  I don't like using an 'our' variable, but it is just too much
# of a pain to pass this thing around to everywhere it needs to go. So, I just tell
# myself that this is STDERR on god's own steroids so I can sleep at night.
our $debug;

our $i_am_a_singleton;

sub new {
	my $class = shift;
	my %opts  = @_;

	if (ref($i_am_a_singleton)) {
		return $i_am_a_singleton;
	}

	my $self = {};
	bless $self, $class;

	$self->{'mp'} = $opts{'mp'};

	$self->{constants} = Apache::Voodoo::Constants->new();

	# Setup signal handler for die so that all deaths become exception objects
	# This way we can get a stack trace from where the death occurred, not where it was caught.
	$SIG{__DIE__} = sub { 
		if (ref($_[0]) =~ /^Apache::Voodoo::Exception/ || ref($_[0]) =~ /^Exception::Class::DBI/) {
			# Already died using an exception class, just pass it up the chain
			$_[0]->rethrow;
		}
		else {
			Apache::Voodoo::Exception::RunTime->throw(error => join("\n", @_));
		}
	};

	if (exists $ENV{'MOD_PERL'}) {
		# let's us do a compile check outside of mod_perl
		$self->restart;
	}

	$i_am_a_singleton = $self;

	return $self;
}

sub valid_app {
	my $self   = shift;
	my $app_id = shift;

	return (defined($self->{'apps'}->{$app_id}))?1:0;
}

sub get_apps {
	my $self = shift;

	return keys %{$self->{'apps'}};
}

sub is_devel_mode {
	my $self = shift;
	return 1;
	return ($self->{'run'}->{'config'}->{'devel_mode'})?1:0;
}

sub set_request {
	my $self = shift;
	$self->{'mp'}->set_request(shift);
}

sub init_app {
	my $self = shift;

	my $id = shift || $self->{'mp'}->get_app_id();

	unless (defined($id)) {
		Apache::Voodoo::Exception::Application->throw(
			"PerlSetVar ID not present in configuration.  Giving up."
		);
	}

	# app exists?
	unless ($self->valid_app($id)) {
		delete $self->{'run'};
		Apache::Voodoo::Exception::Application->throw(
			"Application id '$id' unknown. Valid ids are: ".join(",",$self->get_apps())
		);
	}

	my $run = {};
	$run->{'app_id'} = $id;
	$run->{'app'}    = $self->{'apps'}->{$id};

	if ($run->{'app'}->{'dynamic_loading'}) {
		$run->{'app'}->refresh();
	}

	if ($run->{'app'}->{'DEAD'}) {
		Apache::Voodoo::Exception::Application->throw("Application $id failed to load.");
	}

	$run->{'config'}    = $run->{'app'}->config();
	$run->{'site_root'} = $self->{mp}->site_root();

	$self->{'run'} = $run;

	return 1;
}

sub begin_run {
	my $self = shift;

	my $run = $self->{'run'};
	my $app = $run->{'app'};

	# setup debugging
	$debug = $app->{'debug_handler'};
	$debug->init($self->{'mp'});
	$debug->mark(Time::HiRes::time,"START");

	$run->{'session_handler'} = $self->attach_session($app,$run->{'config'});
	$run->{'session'} = $run->{'session_handler'}->session;

	foreach (@{$app->databases}) {
		eval {
			# we put this in app not run so that database connections persist across requests
			$app->{'dbh'} = DBI->connect_cached(@{$_});
		};
		last if $app->{'dbh'};
	
		Apache::Voodoo::Exception::DBIConnect->throw($DBI::errstr);
	}
	$debug->mark(Time::HiRes::time,'DB Connect');

	return 1;
}

sub parse_params {
	my $self = shift;

	my $params = $self->{mp}->parse_params($self->{'run'}->{'config'}->{'upload_size_max'});
	unless (ref($params)) {
		Apache::Voodoo::Exception::ParamParse->throw($params);
	}
	$debug->mark(Time::HiRes::time,"Parameter parsing");
	$debug->params($params);

	return $params;
}

sub finish {
	my $self   = shift;
	my $status = shift;

	$debug->session($self->{'run'}->{'session'});
	$debug->status($status);

	if ($self->{'run'}->{'p'}->{'uri'} eq '/logout') {
		$self->{'mp'}->err_header_out("Set-Cookie" => $self->{'run'}->{'config'}->{'cookie_name'} . "='!'; path=/");
		$self->{'run'}->{'session_handler'}->destroy();
	}
	else {
		$self->{'run'}->{'session_handler'}->disconnect();
	}

	$debug->mark(Time::HiRes::time,'END');
	$debug->shutdown();

	delete $self->{'run'};
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

		Apache::Voodoo::Exception::Application::SessionTimeout->throw(
			target  => $self->_adjust_url("/timeout"),
			message => "Session has expired"
		);
	}

	# update the session timer
	$session->touch();

	$debug->session_id($session->{'id'});
	$debug->mark(Time::HiRes::time,'Session Attachment');

	return $session;
}

sub history_capture {
	my $self   = shift;
	my $uri    = shift;
	my $params = shift;

	my $session = $self->{'run'}->{'session'};

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

	$debug->mark(Time::HiRes::time,"history capture");
}

sub execute_controllers {
	my $self   = shift;
	my $uri    = shift;
	my $params = shift;

	$uri =~ s/^\///;
	$debug->url($uri);

	my $run = $self->{'run'};
	my $app = $self->{'run'}->{'app'};

	my $template_conf = $app->resolve_conf_section($uri);

	$debug->mark(Time::HiRes::time,"config section resolution");
	$debug->template_conf($template_conf);

	$self->{'run'}->{'p'} = {
		"dbh"           => $self->{'run'}->{'app'}->{'dbh'},
		"params"        => $params,
		"session"       => $self->{'run'}->{'session'},
		"template_conf" => $template_conf,
		"mp"            => $self->{'mp'},
		"uri"           => $uri,

		# these are deprecated.  In the future get them from $p->{mp} or $p->{config}
		"document_root" => $self->{'run'}->{'conf'}->{'template_dir'},
		"dir_config"    => $self->{mp}->dir_config,
		"user-agent"    => $self->{mp}->header_in('User-Agent'),
		"r"             => $self->{mp}->{r},
		"themes"        => $self->{'run'}->{'conf'}->{'themes'}
	};

	my $template_params = {};

	$debug->debug(sort keys %{$app->{'controllers'}});

	# call each of the pre_include modules followed by our page specific module followed by our post_includes
	foreach my $c ( 
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $template_conf->{'pre_include'}) ),
		$app->map_uri($uri),
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $template_conf->{'post_include'}) )
		) {

		if (defined($app->{'controllers'}->{$c->[0]}) && $app->{'controllers'}->{$c->[0]}->can($c->[1])) {
			my $obj    = $app->{'controllers'}->{$c->[0]};
			my $method = $c->[1];

			my $return = $obj->$method($self->{'run'}->{'p'});

			$debug->mark(Time::HiRes::time,"handler for ".$c->[0]." ".$c->[1]);
			$debug->return_data($c->[0],$c->[1],$return);

			if (ref($return) eq "ARRAY") {
				if ($return->[0] eq "REDIRECTED") {
					Apache::Voodoo::Exception::Application::Redirect->throw(target => $self->_adjust_url($return->[1]));
				}
				elsif ($return->[0] eq "DISPLAY_ERROR") {     
					Apache::Voodoo::Exception::Application::DisplayError->throw(
						message => $return->[1],
						target  => $self->_adjust_url(($return->[2])?$return->[2]:"index")
					);
				}
				elsif ($return->[0] eq "ACCESS_DENIED") {
					Apache::Voodoo::Exception::Application::AccessDenied->throw(
						message => $return->[1] || "Access Denied",
						target  => $self->_adjust_url(($return->[2])?$return->[2]:"access_denied")
					);
				}
				elsif ($return->[0] eq "RAW_MODE") {
					Apache::Voodoo::Exception::Application::RawData->throw(
						"content_type" => $return->[1] || "text/html",
						"data"         => $return->[2],
						"headers"      => $return->[3]
					);
				}
				else {
					warn "Controller return an unsupported command in module($c->[0]) method($c->[1]): $return->[0]\n";
					Apache::Voodoo::Exception::RunTime::BadCommand->throw(
						module  => $c->[0],
						method  => $c->[1],
						command => $return->[0]
					);
				}
			}
			elsif (ref($return) eq "HASH") {
				foreach my $k ( keys %{$return}) {
					$template_params->{$k} = $return->{$k};
				}
				$debug->mark(Time::HiRes::time,"result packing");
			}
			else {
				warn "Controller didn't return a hash reference in module($c->[0]) method($c->[1]) ($return)\n";
				Apache::Voodoo::Exception::RunTime::BadReturn->throw(
					module  => $c->[0],
					method  => $c->[1],
					data    => $return
				);
			}

			last if $self->{'run'}->{'p'}->{'_stop_chain_'};
		}
	}

	return $template_params;
}

sub execute_view {
	my $self    = shift;
	my $content = shift;

	my $view;
	if (defined($self->{'run'}->{'p'}->{'_view_'}) && 
		defined($self->{'run'}->{'app'}->{'views'}->{$self->{'run'}->{'p'}->{'_view_'}})) {

		$view = $self->{'run'}->{'app'}->{'views'}->{$self->{'run'}->{'p'}->{'_view_'}};
	}
	elsif (defined($self->{'run'}->{'template_conf'}->{'default_view'}) && 
	       defined($self->{'run'}->{'app'}->{'views'}->{$self->{'run'}->{'template_conf'}->{'default_view'}})) {

		$view = $self->{'run'}->{'app'}->{'views'}->{$self->{'run'}->{'template_conf'}->{'default_view'}};
	}	
	else {
		$view = $self->{'run'}->{'app'}->{'views'}->{'HTML'};
	}	

	$view->begin($self->{'run'}->{'p'});

	if (ref($content) eq "HASH") {
		# pack up the params. note the presidence: module overrides template_conf
		$view->params($self->{'run'}->{'template_conf'});
		$view->params($content);
	}
	else {
		$view->exception($content);
	}

	# add any params from the debugging handlers
	$view->params($debug->finalize());

	return $view;
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

sub _adjust_url {
	my $self = shift;
	my $uri  = shift;

	if ($self->{'run'}->{'site_root'} ne "/" && $uri =~ /^\//o) {
		return $self->{'run'}->{'site_root'}.$uri;
	}
	else {
		return $uri;
	}

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
