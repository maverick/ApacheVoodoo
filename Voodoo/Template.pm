=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Template

=head1 VERSION

$Id$

=head1 SYNOPSIS

This modules is used internally by Voodoo for interfacing to HTML::Template.
Eventually this will be turned into a base wrapper class so that we can use multiple
templating engines (Template::Toolkit, Text::Template, etc)

=cut ################################################################################
package Apache::Voodoo::Template;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use strict;
use warnings;

use File::Spec;
use HTML::Template;

sub new {
	my $class  = shift;
	my $config = shift;

	my $self = {};

	$self->{'template_dir'}  = $config->{'template_dir'};
	$self->{'template_opts'} = $config->{'template_opts'};

	$self->{'template_opts'}->{'die_on_bad_params'} = 0;
	$self->{'template_opts'}->{'global_vars'}       = 1;
	$self->{'template_opts'}->{'loop_context_vars'} = 1;

	$self->{'template_opts'}->{'path'} = [ $config->{'template_dir'} ];

	bless ($self,$class);

	return $self;
}

sub template {
	my $self     = shift;
	my $template = shift;

	$self->{template} = HTML::Template->new(
		'filename' => File::Spec->catfile($self->{'template_dir'},$template.".tmpl"),
		%{$self->{'template_opts'}}
	);
}

sub params {
	my $self = shift;

	$self->{template}->param(@_);
}

sub output {
	my $self = shift;

	$self->{template}->output();
}

sub finish {
	my $self = shift;

	$self->{template} = undef;
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
