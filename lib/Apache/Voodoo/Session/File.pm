package Apache::Voodoo::Session::File;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Session/File.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Apache::Session::File;

use Apache::Voodoo::Session::Instance;

sub new {
	my $class = shift;
	my $conf  = shift;

	my $self = {};

	bless $self,$class;

	$self->{session_dir} = $conf->{'session_dir'};

	return $self;
}

sub attach {
	my $self = shift;
	my $id   = shift;
	my $dbh  = shift;

	my %opts = @_;

	my %session;
	my $obj;

	$opts{'Directory'}     = $self->{'session_dir'};
	$opts{'LockDirectory'} = $self->{'session_dir'};

	# Apache::Session probably validates this internally, making this check pointless.
	# But why take that for granted?
	if (defined($id) && $id !~ /^([0-9a-z]+)$/) {
		$id = undef;
	}

	eval {
		$obj = tie(%session,'Apache::Session::File',$id, \%opts) || die "Tieing to session failed: $!";	
	};
	if ($@) {
		undef $id;
		$obj = tie(%session,'Apache::Session::File',$id, \%opts) || die "Tieing to session failed: $!";	
	}

	$self->{connected} = 1;

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
