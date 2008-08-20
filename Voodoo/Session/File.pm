package Apache::Voodoo::Session::File;

use strict;
use warnings;

use Apache::Session::File;

use Apache::Voodoo::Session::Instance;

sub new {
	my $class = shift;
	my $dir   = shift;

	my $self = {};

	bless $self,$class;

	$self->{session_dir} = $dir;

	return $self;
}

sub attach {
	my $self = shift;
	my $id   = shift;

	my %session;
	my $obj;

	eval {
		$obj = tie(%session,'Apache::Session::File',$id, 
			{
				Directory     => $self->{'session_dir'},
				LockDirectory => $self->{'session_dir'}
			}
		) || die "Global data not available: $!";	
	};
	if ($@) {
		undef $id;
		$obj = tie(%session,'Apache::Session::File',$id,
			{
				Directory     => $self->{'session_dir'},
				LockDirectory => $self->{'session_dir'}
			}
		) || die "Global data not available: $!";	
	}

	return Apache::Voodoo::Session::Instance->new($obj,\%session);
}

1;