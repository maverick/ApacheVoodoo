package Apache::Voodoo::Session::MySQL;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]);

use strict;
use warnings;

use Apache::Session::MySQL;

use Apache::Voodoo::Session::Instance;

sub new {
	my $class = shift;
	my $table = shift;

	my $self = {};

	bless $self,$class;

	$self->{session_table} = $table;

	return $self;
}

sub attach {
	my $self = shift;
	my $id   = shift;
	my $dbh  = shift;

	my %session;
	my $obj;

	my $c = {
		TableName  => $self->{'session_table'},
		Handle     => $dbh,
		LockHandle => $dbh
	};

	eval {
		$obj = tie(%session,'Apache::Session::MySQL',$id, $c) || die "Global data not available: $!";	
	};
	if ($@) {
		undef $id;
		$obj = tie(%session,'Apache::Session::MySQL',$id, $c) || die "Global data not available: $!";	
	}

	return Apache::Voodoo::Session::Instance->new($obj,\%session);
}

1;
