################################################################################
#
# Apache::Voodoo::Debug::Handler
#
# Handles servicing debugging information requests
#
################################################################################
package Apache::Voodoo::Debug::Handler;

$VERSION = "3.0000";

use strict;
use warnings;

use DBI;
use Time::HiRes;

use Apache::Voodoo::MP;
use Apache::Voodoo::Constants;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{mp}        = Apache::Voodoo::MP->new();
	$self->{constants} = Apache::Voodoo::Constants->new();

	$self->{debug_root} = $self->{constants}->debug_path();

	warn "Voodoo Debugging Handler Starting...\n";

	$self->{template_dir} = $INC{"Apache/Voodoo/Debug/Handler.pm"};
	$self->{template_dir} =~ s/Handler.pm$/html/;

	$self->setup_static_files();
	$self->setup_handlers();

	return $self;
}

sub setup_handlers {
	my $self = shift;

	foreach (
		'profile',
		'debug',
		'return_data',
		'session',
		'template_conf',
		'parameters',
		'request') {

		my $m = 'Apache::Voodoo::Debug::'.$_;
		my $f = 'Apache/Voodoo/Debug/'.$_.'.pm';

		require $f;

		my $p = $m->new();

		$self->{handlers}->{$_} = [$p,'handle'];
	}
}

sub setup_static_files {
	my $self = shift;

	$self->{static_files} = { 
		"debug.css"        => "text/css",
		"debug.js"         => "application/x-javascript",
		"i/debug.png"      => "image/png",
		"i/error.png"      => "image/png",
		"i/exception.png"  => "image/png",
		"i/info.png"       => "image/png",
		"i/minus.png"      => "image/png",
		"i/plus.png"       => "image/png",
		"i/spinner.gif"    => "image/gif",
		"i/table.png"      => "image/png",
		"i/trace.png"      => "image/png",
		"i/warn.png"       => "image/png",
	};
}

sub handler {
	my $self = shift;
	my $r    = shift;

	$self->{mp}->set_request($r);

	# holds all vars associated with this page processing request
	my $run = {};

	$run->{uri} = $self->{mp}->uri();
	$run->{uri} =~ s/^$self->{debug_root}//;
	$run->{uri} =~ s/^\///;

	if (defined($self->{static_files}->{$run->{'uri'}})) {
		# request for one of the static files.

		my $file = File::Spec->catfile($self->{template_dir},$run->{'uri'});
		my $mtime = (stat($file))[9];

		# Handle "if not modified since" requests.
		$r->update_mtime($mtime);
		$r->set_last_modified;
		$r->meets_conditions;
		my $rc = $self->{mp}->if_modified_since($mtime); 
		return $rc unless $rc == $self->{mp}->ok;

		# set the content type
		$self->{mp}->content_type($self->{static_files}->{$run->{'uri'}});

		# tell apache to send the underlying file
		$r->sendfile($file);

		return $self->{mp}->ok;
	}
	elsif (defined($self->{handlers}->{$run->{'uri'}})) {
		# request for an operation

		# parse the params
		$run->{'input_params'} = $self->{mp}->parse_params(1);
		unless (ref($run->{'input_params'})) {
			# something went boom
			return $self->display_host_error($run->{'input_params'});
		}

		# connect to the debugging database
		my $dbh = DBI->connect_cached(@{$self->{constants}->debug_dbd()});
		unless ($dbh) {
			return $self->display_host_error("Can't connect to debugging database: ".DBI->errstr);
		}

		$run->{dbh} = $dbh;

		return $self->generate_content($run);
	}

	# not a request we handle
	return $self->{mp}->declined;
}

sub generate_content {
	my $self = shift;
	my $run  = shift;

	my $return;
	eval {
		my ($obj,$method) = @{$self->{handlers}->{$run->{uri}}};

		$return = $obj->$method(
			{
				"dbh"    => $run->{'dbh'},
				"params" => $run->{'input_params'},
				"mp"     => $self->{mp},
			}
		);
	};

	if ($@) {
		return $self->display_host_error("Module: $run->{uri}\n$@");
	}

	if (ref($return) eq "ARRAY") {
		if    ($return->[0] eq "REDIRECTED") {
			if ($self->{'debug_root'} ne "/" && $return->[1] =~ /^\//o) {
				$return->[1] =~ s/^\//$self->{'debug_root'}/;
			}
			return $self->{mp}->redirect($return->[1]);
		}
		elsif ($return->[0] eq "DISPLAY_ERROR") {     
			my $ts = Time::HiRes::time;
			$run->{'session'}->{"er_$ts"}->{'error'}  = $return->[1];
			$run->{'session'}->{"er_$ts"}->{'return'} = $return->[2];

			# internal redirects have always been touchy, removing for now until I can
			# figure out why it's being a pain now.
			#$run->{'session_handler'}->disconnect();
			#return $self->{mp}->redirect($app->{'debug_root'}."display_error?error=$ts",1);

			return $self->{mp}->redirect($self->{'debug_root'}."display_error?error=$ts");
		}
		elsif ($return->[0] eq "ACCESS_DENIED") {
			if (defined($return->[2])) {
				# using the user supplied destination page
				if ($return->[2] =~ /^\//o) {
					$return->[2] =~ s/^/$self->{'debug_root'}/;
				}

				if (defined($return->[1])) {
					$return->[2] .= "?error=".$return->[1];
				}
				return $self->{mp}->redirect($return->[2]);
			}
			elsif (-e $self->{'template_dir'}."/access_denied.tmpl") {
				# using the default destination page
				if (defined($return->[1])) {
					return $self->{mp}->redirect($self->{'debug_root'}."access_denied?error=".$return->[1]);
				}
				else {
					return $self->{mp}->redirect($self->{'debug_root'}."access_denied");
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
			$self->{mp}->flush();
			return $self->{mp}->ok;
		}
		else {
			return $self->display_host_error("Module: $self->{uri}\n$return->[0] is not a supported command");
		}
	}
	elsif (ref($return) ne "HASH") {
		return $self->display_host_error("Module: $self->{uri} didn't return a hash ref");
	}

	eval {
		# load the template
		$self->{'template_engine'}->template($run->{'uri'});

		$return->{'debug_root'} = $self->{'debug_root'};

		# pack up the params
		$self->{'template_engine'}->params($return);

		# generate the main body contents
		$return->{'_MAIN_BODY_'} = $self->{'template_engine'}->output();
		
		# load the skeleton template
		$self->{'template_engine'}->template("skeleton");

		# pack everything into the skeleton
		$self->{'template_engine'}->params($return);
	};
	if ($@) {
		# caught a runtime error from perl
		return $self->display_host_error($@);
	}

	$self->{mp}->content_type("text/html");

	$self->{mp}->print($self->{'template_engine'}->output());

	$self->{'template_engine'}->finish();

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