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

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;
use Apache::Voodoo::Application;
use Apache::Voodoo::Exception;

# Debugging object.  I don't like using an 'our' variable, but it is just too much
# of a pain to pass this thing around to everywhere it needs to go. So, I just tell
# myself that this is STDERR on god's own steroids so I can sleep at night.
our $debug;

my $i_am_a_singleton;

sub new {
	my $class = shift;
	my %opts  = @_;

	if (ref($i_am_a_singleton)) {
		return $i_am_a_singleton;
	}

	my $self = {};
	bless $self, $class;

	$self->{mp} = $opts{'mp'} || Apache::Voodoo::MP->new();

	$self->{constants} = Apache::Voodoo::Constants->new();

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

sub init_app {
	my $self   = shift;
	my $app_id = shift;

	# app exists?
	unless ($self->valid_app($app_id)) {
		delete $self->{'run'};
		Apache::Voodoo::Exception::Application->throw("No such application");
	}

	my $run = {};
	$run->{'app_id'} = $app_id;
	$run->{'app'}    = $self->{'apps'}->{$app_id};

	if ($run->{'app'}->{'dynamic_loading'}) {
		$run->{'app'}->refresh();
	}

	if ($run->{'app'}->{'DEAD'}) {
		Apache::Voodoo::Exception::Application->throw("Application failed to load");
	}

	$run->{'config'} = $run->{'app'}->config();

	# setup debugging
	$debug = $run->{'app'}->{'debug_handler'};
	$debug->init($self->{'mp'});
	$debug->mark(Time::HiRes::time,"START");

	$run->{'session_handler'} = $self->attach_session($run->{app},$run->{config});
	$run->{'session'} = $run->{session_handler}->session;

	foreach (@{$run->{'app'}->databases}) {
		eval {
			# we put this in app not run so that database connections persist across requests
			$run->{'app'}->{'dbh'} = DBI->connect_cached(@{$_});
		};
		last if $run->{'app'}->{'dbh'};
	
		Apache::Voodoo::Exception::DBIConnect->throw($DBI::errstr);
	}

	$self->{'run'} = $run;

	return 1;
}

sub finish {
	my $self = shift;

	$self->{'run'}->{'session_handler'}->disconnect();

	$debug->mark(Time::HiRes::time,'END');
	$debug->shutdown();

	delete $self->{'run'};
}

=pod
sub execute {
	my $self = shift;
	my $uri  = shift;

	$self->{'run'}->{'uri'} = $uri;

	####################
	# Get configuation for this template or section
	####################
	$self->{'run'}->{'template_conf'} = $self->{'app'}->resolve_conf_section($self->{'run'}->{'uri'});

	$debug->mark(Time::HiRes::time,"config section resolution");
	$debug->template_conf($self->{'run'}->{'template_conf'});

	####################
	# Generate the content
	####################
	my $return = $self->generate_content($app,$conf,$run);

	$debug->session($run->{session});
	$debug->status($return);

	return $return;
}
=cut

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

sub execute_controllers {
	my $self   = shift;
	my $uri    = shift;
	my $params = shift;

	$uri =~ s/^\///;
	warn "am here $uri";

	my $run           = $self->{'run'};
	my $app           = $self->{'run'}->{'app'};
	my $template_conf = $self->{'run'}->{'template_conf'};

	my $p = {
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

	# call each of the pre_include modules followed by our page specific module followed by our post_includes
	foreach my $c ( 
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $template_conf->{'pre_include'}) ),
		$app->map_uri($uri),
		( map { [ $_, "handle"] } split(/\s*,\s*/o, $template_conf->{'post_include'}) )
		) {

		$debug->debug("here");
		if (defined($app->{'controllers'}->{$c->[0]}) && $app->{'controllers'}->{$c->[0]}->can($c->[1])) {
			$debug->debug("here too");
			my $obj    = $app->{'controllers'}->{$c->[0]};
			my $method = $c->[1];

			my $return = $obj->$method($p);

			$debug->mark(Time::HiRes::time,"handler for ".$c->[0]." ".$c->[1]);
			$debug->return_data($c->[0],$c->[1],$return);

			if (ref($return) eq "ARRAY") {
				if ($return->[0] eq "REDIRECTED") {
					Apache::Voodoo::Exception::Application::Redirect->throw(target => $return->[1]);
				}
				elsif ($return->[0] eq "DISPLAY_ERROR") {     
					Apache::Voodoo::Exception::Application::DisplayError->throw(
						message => $return->[1],
						target  => ($return->[2])?$return->[2]:"index"
					);
				}
				elsif ($return->[0] eq "ACCESS_DENIED") {
					Apache::Voodoo::Exception::Application::AccessDenied->throw(
						message => $return->[1],
						target  => ($return->[2])?$return->[2]:"access_denied"
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
					Apache::Voodoo::Exception::Application::BadCommand->throw(
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
				warn "Controller didn't return a hash reference in module($c->[0]) method($c->[1])\n";
				Apache::Voodoo::Exception::Application::BadReturn->throw(
					module  => $c->[0],
					method  => $c->[1],
					data    => $return
				);
			}

			last if $p->{_stop_chain_};
		}
	}

	return $template_params;
}

sub execute_view {
	my $self = shift;

=pod
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
=cut
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
