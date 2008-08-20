package Apache::Voodoo::Session::Instance;

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
