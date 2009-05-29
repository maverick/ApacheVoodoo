=pod ################################################################################

=head1 NAME

Apache::Voodoo::Debug::Common

=head1 VERSION

$Id$

=head1 SYNOPSIS

Does nothing gracefully

=cut ###########################################################################
package Apache::Voodoo::Debug::Common;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Devel::StackTrace;

sub new {
	my $class = shift;

	my $self = {};

	bless($self,$class);

	return $self;
}

sub init      { return; }
sub shutdown  { return; }
sub debug     { return; }
sub info      { return; }
sub warn      { return; }
sub error     { return; }
sub exception { return; }
sub trace     { return; }
sub table     { return; }

sub mark          { return; }
sub return_data   { return; }
sub session_id    { return; }
sub url           { return; }
sub status        { return; }
sub params        { return; }
sub template_conf { return; }
sub session       { return; }

sub finalize { return (); }

sub stack_trace {
	my $self = shift;
	my $full = shift;

	my @trace;
	my $i = 1;

	my $st = Devel::StackTrace->new();
    while (my $frame = $st->frame($i++)) {
		last if ($frame->package =~ /^Apache::Voodoo::Engine/);
        next if ($frame->package =~ /^Apache::Voodoo/);
        next if ($frame->package =~ /(eval)/);

		my $f = {
			'class'    => $frame->package,
			'function' => $st->frame($i)->subroutine,
			'file'     => $frame->filename,
			'line'     => $frame->line,
		};
		$f->{'function'} =~ s/^$f->{'class'}:://;

		my @a = $st->frame($i)->args;

		# if the first item is a reference to same class, then this was a method call
		if (ref($a[0]) eq $f->{'class'}) {
			shift @a;
			$f->{'type'} = '->';
		}
		else {
			$f->{'type'} = '::';
		}

		push(@trace,$f);

		if ($full) {
			$f->{'args'} = \@a;
		}
		else {
			last;
		}
    }
	return @trace;
}

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
