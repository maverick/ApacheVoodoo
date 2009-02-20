=pod ################################################################################

=head1 NAME

Apache::Voodoo::Debug - handles operations associated with debugging output.

=head1 VERSION

$Id$

=head1 SYNOPSIS

This object is used by Voodoo internally to handling various types of debugging
information and to produce end user display of that information.  End users 
never interact with this module directly, instead they use the debug() and mark()
methods from L<Apache::Voodoo>.

=cut ###########################################################################
package Apache::Voodoo::Debug::Native;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/Debug/Native.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Devel::StackTrace;
use IO::Socket::UNIX;
use IO::Handle::Record;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

sub new {
	my $class = shift;

	my $id   = shift;
	my $conf = shift;

	my $self = {};

	$self->{id}->{app_id} = $id;

	bless($self,$class);

	my @flags = qw(debug info warn error exception table trace profile params template_conf return_data session);

	$self->{enabled} = 0;
	if ($conf eq "1" || (ref($conf) eq "HASH" && $conf->{all})) {
		foreach (@flags) {
			$self->{conf}->{$_} = 1;
		}
		$self->{enabled} = 1;
	}
	elsif (ref($conf) eq "HASH") {
		foreach (@flags) {
			if ($conf->{$_}) {
				$self->{conf}->{$_} = 1;
				$self->{enabled} = 1;
			}
		}
	}

	# we always send this since is fundamental to identifying the request chain
	# regardless of what other info we log
	$self->{conf}->{url}        = 1;
	$self->{conf}->{result}     = 1;
	$self->{conf}->{session_id} = 1;

	return $self;
}

sub init {
	my $self = shift;

	my $mp = shift;

	$self->{id}->{request_id} = $mp->request_id();

	return unless $self->{enabled};

	unless (defined($self->{'socket'}) && $self->{'socket'}->connected) {
		eval {
			$self->{'socket'} = IO::Socket::UNIX->new(
				Type => SOCK_STREAM,
				Peer => $self->{ac}->socket_file()
			);
		};

		if ($@ || 
			!defined($self->{'socket'}) ||
			!$self->{'socket'}->connected) {

			warn("Failed to open socket.  Debug info will be lost. $!\n");
			$self->{enable}  = undef;
			$self->{enabled} = 0;
			return;
		}
	}

	# socket looks good, enable the public facing calls.
	$self->{enable} = $self->{conf};

	$self->{'socket'}->write_record({
		type => 'request',
		id   => $self->{'id'}
	});
}

sub enabled {
	return $_[0]->{enabled};
}

sub shutdown {
	return;
}

sub debug     { my $self = shift; $self->_debug('debug',    @_); }
sub info      { my $self = shift; $self->_debug('info',     @_); }
sub warn      { my $self = shift; $self->_debug('warn',     @_); }
sub error     { my $self = shift; $self->_debug('error',    @_); }
sub exception { my $self = shift; $self->_debug('exception',@_); }
sub trace     { my $self = shift; $self->_debug('trace',    @_); }
sub table     { my $self = shift; $self->_debug('table',    @_); }

sub _stack_trace {
	my $self   = shift;
	my $detail = shift;

	my @trace;

	my $st = Devel::StackTrace->new();
    $st->next_frame;
    while (my $frame = $st->next_frame()) {
        next if ($frame->subroutine =~ /^Apache::Voodoo/);
        next if ($frame->subroutine =~ /(eval)/);

		if ($detail) {
			push(@trace, {
				'package'    => $frame->package,
            	'subroutine' => $frame->subroutine,
            	'line'       => $frame->line,
            	'args'       => [ $frame->args ]
        	});
		}
		else {
			push(@trace, {
				'package'    => $frame->package,
            	'subroutine' => $frame->subroutine,
            	'line'       => $frame->line,
            	'args'       => [ $frame->args ]
        	});
		}
    }
	return \@trace;
}

sub _debug {
	my $self = shift;
	my $type = shift;

	return unless $self->{'enable'}->{$type};

	my $data;
	if (scalar(@_) > 1 || ref($_[0])) {
		# if there's more than one item, or the item we have is a reference
		# we shove it through it Data::Dumper
		$data = Dumper(@_);
	}
	else {
		# simple scalar can be logged as is.
		$data = $_[0];
	}

	my $detail = ($type =~ /(exception|trace)/)?1:0;

	$self->{'socket'}->write_record({
		type  => 'debug',
		id    => $self->{id},
		level => $level,
		stack => $self->_stack_trace($detail),
		data  => $data
	});
}

sub mark {
	my $self = shift;

	return unless $self->{'enable'}->{'profile'};

	$self->{'socket'}->write_record({
		type      => 'profile',
		id        => $self->{id},
		timestamp => shift,
		data      => shift
	});
}

sub return_data {
	my $self = shift;

	return unless $self->{'enable'}->{'return_data'};

	$self->{'socket'}->write_record({
		type    => 'return_data',
		id      => $self->{id},
		handler => shift,
		method  => shift,
		data    => scalar(Dumper(shift))
	});
}


# these all behave the same way.
sub session_id    { my $self = shift; $self->_log('session_id',    @_);  }
sub url           { my $self = shift; $self->_log('url',           @_);  }
sub result        { my $self = shift; $self->_log('result',        @_);  }
sub params        { my $self = shift; $self->_log('params',        @_);  }
sub template_conf { my $self = shift; $self->_log('template_conf', @_);  }
sub session       { my $self = shift; $self->_log('session',Dumper(@_)); }

sub _log {
	my $self = shift;
	my $type = shift;
	
	return unless $self->{'enable'}->{$type};

	$self->{'socket'}->write_record({
		type => $type,
		id   => $self->{id},
		data => shift
	});
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
