=pod #####################################################################################

=head1 Apache::Voodoo::Log

$Id$

=head1 Initial Coding: Maverick

Wrapper object to simplify access to apache's logging facilities.

=cut ################################################################################

package Apache::Voodoo::Log;

$VERSION = '1.20';

use strict;
use Apache;
use Data::Dumper;

sub new {
	my $class = shift;
	
	my $self = {};

	bless($self,$class);

	return $self;
}

sub warn {
	my $self = shift;

	$self->_log('warn',@_);
}

sub error {
	my $self = shift;

	$self->_log('error',@_);
}

sub _log {
	my $self  = shift;
	my $level = shift;

	my $r = Apache->request || Apache->server;

	if (0 && $r) {
		foreach (@_) {
			if (ref($_)) {
				$r->log->$level(Dumper $_);
			}
			else {
				$r->log->$level($_);
			}
		}
	}
	else {
		# Neither request nor server are present.  Fall back to
		# ye olde STDERR
		foreach (@_) {
			if (ref($_)) {
				print STDERR Dumper $_,"\n";
			}
			else {
				print STDERR $_,"\n";
			}
		}
	}
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
