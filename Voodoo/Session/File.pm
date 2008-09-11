package Apache::Voodoo::Session::File;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

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

	my $c = {
		Directory     => $self->{'session_dir'},
		LockDirectory => $self->{'session_dir'}
	};

	eval {
		$obj = tie(%session,'Apache::Session::File',$id, $c) || die "Global data not available: $!";	
	};
	if ($@) {
		undef $id;
		$obj = tie(%session,'Apache::Session::File',$id, $c) || die "Global data not available: $!";	
	}

	return Apache::Voodoo::Session::Instance->new($obj,\%session);
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
