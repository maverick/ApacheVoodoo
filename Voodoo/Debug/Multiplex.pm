=pod ################################################################################

=head1 NAME

Apache::Voodoo::Debug - handles operations associated with debugging output.

=head1 VERSION

$Id: Multiplex.pm 12906 2009-02-20 23:08:10Z medwards $

=head1 SYNOPSIS

This object is used by Voodoo internally to handling various types of debugging
information and to produce end user display of that information.  End users 
never interact with this module directly, instead they use the debug() and mark()
methods from L<Apache::Voodoo>.

=cut ###########################################################################
package Apache::Voodoo::Debug::Multiplex;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

sub new {
	my $class = shift;

	my $self = {};

	push(@{$self->{'handlers'}},@_);

	bless($self,$class);

	return $self;
}

sub init      { my $self = shift; $_->init(@_)      foreach (@{$self->{'handlers'}}); }
sub shutdown  { my $self = shift; $_->shutdown(@_)  foreach (@{$self->{'handlers'}}); }
sub debug     { my $self = shift; $_->debug(@_)     foreach (@{$self->{'handlers'}}); }
sub info      { my $self = shift; $_->info(@_)      foreach (@{$self->{'handlers'}}); }
sub warn      { my $self = shift; $_->warn(@_)      foreach (@{$self->{'handlers'}}); }
sub error     { my $self = shift; $_->error(@_)     foreach (@{$self->{'handlers'}}); }
sub exception { my $self = shift; $_->exception(@_) foreach (@{$self->{'handlers'}}); }
sub trace     { my $self = shift; $_->trace(@_)     foreach (@{$self->{'handlers'}}); }
sub table     { my $self = shift; $_->table(@_)     foreach (@{$self->{'handlers'}}); }

sub mark          { my $self = shift; $_->mark(@_)          foreach (@{$self->{'handlers'}}); }
sub return_data   { my $self = shift; $_->return_data(@_)   foreach (@{$self->{'handlers'}}); }
sub session_id    { my $self = shift; $_->session_id(@_)    foreach (@{$self->{'handlers'}}); }
sub url           { my $self = shift; $_->url(@_)           foreach (@{$self->{'handlers'}}); }
sub result        { my $self = shift; $_->result(@_)        foreach (@{$self->{'handlers'}}); }
sub params        { my $self = shift; $_->params(@_)        foreach (@{$self->{'handlers'}}); }
sub template_conf { my $self = shift; $_->template_conf(@_) foreach (@{$self->{'handlers'}}); }
sub session       { my $self = shift; $_->session(@_)       foreach (@{$self->{'handlers'}}); }

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include in
this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version of 
the Artistic License :)

=cut ################################################################################
