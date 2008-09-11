package Apache::Voodoo::Session::Instance;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use strict;
use warnings;

sub new {
	my $class   = shift;
	my $obj     = shift;
	my $session = shift;

	my $self = {};

	bless $self,$class;

	$self->{obj}     = $obj;
	$self->{session} = $session;

	$self->{id} = $session->{_session_id};

	return $self;
}

sub id      { return $_[0]->{id};      }
sub session { return $_[0]->{session}; }
sub obj     { return $_[0]->{obj};     }
	
sub disconnect {
	my $self = shift;

	# this produces an unavoidable warning.
	{
		no warnings;
		untie(%{$self->{session}});
	}
}

sub destroy {
	my $self = shift;

	$self->{obj}->delete;
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
