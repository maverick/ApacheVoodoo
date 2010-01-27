package Apache::Voodoo::Session::MySQL;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Session/MySQL.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Apache::Session::MySQL;

use Apache::Voodoo::Session::Instance;

sub new {
	my $class = shift;
	my $conf  = shift;

	my $self = {};

	bless $self,$class;

	$self->{session_table} = $conf->{'session_table'};

	return $self;
}

sub attach {
	my $self = shift;
	my $id   = shift;
	my $dbh  = shift;

	my %opts = @_;

	my %session;
	my $obj;

	$opts{'TableName'}  = $self->{'session_table'};
	$opts{'Handle'}     = $dbh;
	$opts{'LockHandle'} = $dbh;

	if (defined($id) && $id !~ /^([0-9a-z]+)$/) {
		$id = undef;
	}

	eval {
		$obj = tie(%session,'Apache::Session::MySQL',$id, \%opts) || die "Tieing to session failed: $!";	
	};
	if ($@) {
		undef $id;
		$obj = tie(%session,'Apache::Session::MySQL',$id, \%opts) || die "Tieing to session failed: $!";	
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
