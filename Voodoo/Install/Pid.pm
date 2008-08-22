=pod ###########################################################################

=head1 NAME

Apache::Voodoo::Install::Pid - Pid file handler

=head1 VERSION

$Id$

=head1 SYNOPSIS

This object is used by Voodoo internally.

=cut ###########################################################################
package Apache::Voodoo::Install::Pid;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]);

use base("Apache::Voodoo::Install");

use strict;
use File::Pid;

sub new {
	my $class = shift;
	my %params = @_;

	my $self = {};

	bless($self,$class);

	if (!$params{'pretend'} && $<) {
		print "\nSorry, only root can do this.\n\n";
		exit;
	}

	if ($self->{'pretend'}) {
		$self->mesg("== Pretending to run ==");
	}

	$self->{'pid'} = File::Pid->new({file => '/tmp/voodoo-install.pid'});
	my $id = $self->{'pid'}->running;
	if ($id) {
		print "ERROR: Already Running ($id)\n";
		exit;
	}

	unless ($self->{'pid'}->write) {
		die "ERROR: Couldn't write pid: $!";
	}

	return $self;
}

sub remove {
	my $self = shift;

	# prevent double call of File::Pid::remove in cases
	# where A::V::I::Pid was called directly
	if (defined($self->{'pid'})) {
		$self->{'pid'}->remove;
		$self->{'pid'} = undef;
	}
}

sub DESTROY {
	$_[0]->remove;
}

1;

=pod ###########################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE 
file include in this package or L<Apache::Voodoo::license>.  The summary is
it's a legalese version of the Artistic License :)

=cut ###########################################################################
