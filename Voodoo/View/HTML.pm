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
		use Data::Dumper;
		if ($e->isa("Exception::Class::DBI")) {
			$self->_load_internal_template("db_error");
			$self->params(
				'time' => scalar (localtime($e->time)),
				'package' => $e->package,
				'file' => $e->file,
				'line' => $e->line,
				'error' => $e->errstr,
				'query' => $e->statement
			);
		}
		else {
			$self->_load_internal_template("exception");
			$self->params("exception" => Dumper $e);
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
	my $self  = shift;

	$self->content_type("text/html");

	$self->{internal_error} = 1;
	$self->{error_msg} = shift;
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
