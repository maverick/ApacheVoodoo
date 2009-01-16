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
package Apache::Voodoo::Debug;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;

require "Apache/Voodoo/SIPC.pm";
use Time::HiRes;
use IO::Socket::UNIX;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

sub new {
	my $class = shift;

	my $self = {};
	$self->{ac} = shift;

	bless($self,$class);

	$self->{flags} = [ qw(debug profile params template_conf return_data session) ];

	return $self;
}

sub init {
	my $self = shift;

	$self->{id}->{app_id}     = shift;
	$self->{id}->{request_id} = shift;

	$self->{enabled} = 0;
	my $debug = shift;
	if ($debug eq "1" || (ref($debug) eq "HASH" && $debug->{all})) {
		foreach (@{$self->{flags}}) {
			$self->{enable}->{$_} = 1;
		}
		$self->{enabled} = 1;
	}
	elsif (ref($debug) eq "HASH") {
		foreach (@{$self->{flags}}) {
			if ($debug->{$_}) {
				$self->{enable}->{$_} = 1;
				$self->{enabled} = 1;
			}
		}
	}

	return unless $self->{enabled};

	$self->{'socket'} = SIPC->new(
		socket_handler => 'IO::Socket::UNIX'
	);

	my $ok;
	eval {
		$ok = $self->{'socket'}->connect(
			Type => SOCK_STREAM,
			Peer => $self->{ac}->socket_file()
		);
	};

	if ($@ || !$ok) {
		print STDERR "Failed to open socket.  Debug info will be lost. $!\n";
		$self->{enable}  = undef;
		$self->{enabled} = 0;
		return;
	}

	# we always send this since is fundamental to identifying the request chain
	# regardless of what other info we log
	$self->{'enable'}->{'url'}        = 1;
	$self->{'enable'}->{'result'}     = 1;
	$self->{'enable'}->{'session_id'} = 1;

	$self->{'socket'}->send({
		type => 'request',
		id   => $self->{'id'}
	});
}

sub enabled {
	return $_[0]->{enabled};
}

sub shutdown {
	my $self = shift;

	undef $self->{'enable'};

	if (ref($self->{'socket'})) {
		$self->{'socket'}->disconnect();
	}
}

sub debug {
	my $self = shift;

	return unless $self->{'enable'}->{'debug'};

	# trace the execution stack.
	# caller($i+1)[3] has the method that called
	# caller($i)[2]   has the line number that method was called from
	my $i=0;
	my @stack;
	while (my $method = (caller($i+1))[3]) {
		if ($method =~ /^Apache\:\:Voodoo/) {
			# skip Apache::Voodoo functions
			$i++;
			if ((caller($i+1))[3] eq "(eval)") {
				# also skip AV's internal evals
				$i++;
			}
			next;
		}

		my $line = (caller($i++))[2];
		push(@stack,[$method,$line]) unless $line == 0;
	}

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

	$self->{'socket'}->send({
		type  => 'debug',
		id    => $self->{id},
		stack => [reverse @stack],
		data  => $data
	});
}

sub mark {
	my $self = shift;

	return unless $self->{'enable'}->{'profile'};

	$self->{'socket'}->send({
		type      => 'profile',
		id        => $self->{id},
		timestamp => Time::HiRes::time,
		data      => shift
	});
}

sub return_data {
	my $self = shift;

	return unless $self->{'enable'}->{'return_data'};

	$self->{'socket'}->send({
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

	$self->{'socket'}->send({
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
