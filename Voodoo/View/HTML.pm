=pod #####################################################################################

=head1 NAME

Apache::Voodoo::View::HTML

=head1 VERSION

$Id$

=head1 SYNOPSIS

This modules is used internally by Voodoo for interfacing to HTML::Template.

=cut ################################################################################
package Apache::Voodoo::View::HTML;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use File::Spec;
use HTML::Template;
use Apache::Voodoo::Exception;

use Exception::Class::DBI;

use base ("Apache::Voodoo::View");

sub init {
	my $self   = shift;
	my $config = shift;

	$self->{'template_dir'}  = $config->{'template_dir'};
	$self->{'template_opts'} = $config->{'template_opts'};

	$self->{'template_opts'}->{'die_on_bad_params'} = 0;
	$self->{'template_opts'}->{'global_vars'}       = 1;
	$self->{'template_opts'}->{'loop_context_vars'} = 1;

	$self->{'template_opts'}->{'path'} = [ $config->{'template_dir'} ];

	$self->{'site_root'}  = $config->{'site_root'};
	$self->{'use_themes'} = $config->{'themes'}->{'use_themes'};

	if ($self->{'use_themes'}) {
		require Apache::Voodoo::View::HTML::Theme;
		$self->{'theme_handler'} = Apache::Voodoo::View::HTML::Theme->new($config->{'themes'});
	}

	$self->content_type('text/html');
}

sub begin {
	my $self = shift;
	my $p    = shift;

	$self->content_type($p->{"template_conf"}->{"content-type"} || 'text/html');

	my $skeleton;
	eval {
		my $return;
		if ($self->{'use_themes'}) {
			# time to do the theme processing stuff.
			$return = $self->{'theme_handler'}->handle(
				{
					"document_root" => $self->{'template_dir'},
					"session"       => $p->{'session'},
					"uri"           => $p->{'uri'},
				}
			);

			$skeleton = $self->{'theme_handler'}->get_skeleton();
		}
		else {
			$skeleton = $p->{'template_conf'}->{'skeleton'} || 'skeleton';
		}

		$self->_load_skeleton($skeleton);
		$self->_load_template($p->{'uri'});

		$self->params(SITE_ROOT => $self->{site_root});

		$self->params($return) if ($return);
	};
	if ($@) {
		$self->_internal_error($@);
	}
}

sub _load_skeleton {
	my $self = shift;
	my $s    = shift;

	$self->{skeleton_template} = HTML::Template->new(
		'filename' => File::Spec->catfile($self->{'template_dir'},$s.".tmpl"),
		%{$self->{'template_opts'}}
	);
}

sub _load_template {
	my $self = shift;
	my $u    = shift;

	$self->{template} = HTML::Template->new(
		'filename' => File::Spec->catfile($self->{'template_dir'},$u.".tmpl"),
		%{$self->{'template_opts'}}
	);
}

sub _load_internal_template {
	my $self = shift;
	my $u    = shift;

	my $path = $INC{'Apache/Voodoo/View/HTML.pm'};
	$path =~ s/\.pm/\//o;

	$self->{template} = HTML::Template->new(
		'filename' => $path.$u.'.tmpl',
		%{$self->{'template_opts'}}
	);
}

sub params {
	my $self = shift;

	return if ($self->{internal_error});

	eval {
		$self->{skeleton_template}->param(@_);
		$self->{template}->param(@_);
	};
	if ($@) {
		$self->_internal_error($@);
	}
}

sub exception {
	my $self = shift;
	my $e    = shift;

	return if ($self->{internal_error});

	eval {
		if ($e->isa("Exception::Class::DBI")) {
			$self->_load_internal_template("db_error");
			$self->params(
				"description" => "Database Error",
				"message"     => $e->errstr,
				"package"     => $e->package,
				"line"        => $e->line,
				"query"       => $self->_format_query($e->statement)
			);
		}
		elsif ($e->isa("Apache::Voodoo::Exception::Application::DisplayError")) {
			if (-e $self->{'template_dir'}."display_error.tmpl") {
				$self->_load_template("display_error");
			}
			else {
				$self->_load_internal_template("display_error");
			}

			$self->params('error_url' => $e->target);
			if (ref($e->message) eq "HASH") {
				$self->params($e->message);
			}
			else {
				$self->params('error_string' => $e->message);
			}
		}
		elsif ($e->isa("Apache::Voodoo::Exception")) {
			$self->_load_internal_template("exception");
			$self->params(
				"description" => $e->description,
				"message"     => $e->message
			);
			if ($e->isa("Apache::Voodoo::Exception::RunTime")) {
				$self->params("stack" => $self->_stack_trace($e->trace()));
			}
		}
		else {
			$self->_load_internal_template("exception");
			$self->params("message" => "$e");
		}
	};
	if ($@) {
		$self->_internal_error($@);
	}
}

sub output {
	my $self = shift;

	if ($self->{internal_error}) {
		return 
			"<html><body>".
			"<h2>The following error was encountered while processing this request:</h2>".
			"<pre>".$self->{error_msg}."</pre>".
			"</body></html>";
	}
	else {
		$self->{skeleton_template}->param('_MAIN_BODY_' => $self->{template}->output());
		return $self->{skeleton_template}->output();
	}
}

sub finish {
	my $self = shift;

	$self->{template} = undef;
	$self->{skeletong_template} = undef;
	$self->{internal_error} = 0;
	$self->{error_msg} = undef;
}

sub _internal_error {
	my $self = shift;

	$self->content_type("text/html");

	$self->{internal_error} = 1;
	$self->{error_msg} = shift;
}

sub _stack_trace {
	my $self  = shift;
	my $trace = shift;

	unless (ref($trace) eq "Devel::StackTrace") {
		return [];
	}

	my @trace;
	my $i = 1;
    while (my $frame = $trace->frame($i++)) {
		last if ($frame->package =~ /^Apache::Voodoo::Engine/);
        next if ($frame->package =~ /^Apache::Voodoo/);
        next if ($frame->package =~ /(eval)/);

		my $f = {
			'class'    => $frame->package,
			'function' => $trace->frame($i)->subroutine,
			'file'     => $frame->filename,
			'line'     => $frame->line,
		};
		$f->{'function'} =~ s/^$f->{'class'}:://;

		my @a = $trace->frame($i)->args;
		# if the first item is a reference to same class, then this was a method call
		if (ref($a[0]) eq $f->{'class'}) {
			shift @a;
			$f->{'type'} = '->';
		}
		else {
			$f->{'type'} = '::';
		}
		$f->{'args'} = join(",",@a);

		push(@trace,$f);

    }
	return \@trace;
}

sub _format_query {
	my $self  = shift;
	my $query = shift;

	my $leading = undef;
	my @lines; 
	foreach my $line (split(/\n/,$query)) {
		$line =~ s/[\r\n]//g;
		$line =~ s/(?<![ \S])\t/    /g;    # negative look-behind assertion.  replaces only leading tabs

		if (!defined($leading)) {
			next if $line =~ /^\s*$/;
			my $l = $line;
			$l =~ s/\S.*$//;
			if (length($l)) {
				$leading = length($l);
			}
		}
		else {
			my $l = $line;
			$l =~ s/\S.*$//;
			if (length($l) and length($l) < $leading) {
				$leading = length($l);
			}
		}
		push (@lines,$line);
	}

	return join(
		"\n",
		map {
			$_ =~ s/^ {$leading}//;
			$_;
		} @lines
	);
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file 
include in this package or L<Apache::Voodoo::license>.  The summary is it's a 
legalese version of the Artistic License :)

=cut ################################################################################
