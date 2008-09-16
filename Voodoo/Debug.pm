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

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use strict;

use Time::HiRes;
use IO::Socket::SIPC;
use IO::Socket::UNIX;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

sub new {
	my $class = shift;

	my $self = {};
	$self->{ac} = shift;

	bless($self,$class);

	$self->{flags} = [ qw(debug profile params template_conf return_data headers session) ];

	return $self;
}

sub init {
	my $self = shift;

	$self->{id}->{app_id}     = shift;
	$self->{id}->{request_id} = shift;

	my $on = 0;
	my $debug = shift;
	if ($debug == 1 || (ref($debug) eq "HASH" && $debug->{all})) {
		foreach (@{$self->{flags}}) {
			$self->{enable}->{$_} = 1;
		}
		$on = 1;
	}
	elsif (ref($debug) eq "HASH") {
		foreach (@{$self->{flags}}) {
			if ($debug->{$_}) {
				$self->{enable}->{$_} = 1;
				$on = 1;
			}
		}
	}

	return unless $on;

	$self->{'socket'} = IO::Socket::SIPC->new(
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
		delete $self->{enable};
		return;
	}

	# we always send this since is fundamental to identifying the request chain
	# regardless of what other info we log
	$self->{'enable'}->{'url'}        = 1;
	$self->{'enable'}->{'session_id'} = 1;

	$self->{'socket'}->send({
		type => 'request',
		id   => $self->{'id'}
	});
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
			$i++;
			next;
		}

		my $line = (caller($i++))[2];
		push(@stack,[$method,$line]) unless $line == 0;
	}

	$self->{'socket'}->send({
		type  => 'debug',
		id    => $self->{id},
		stack => \@stack,
		data  => Dumper(@_)
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
		data    => Dumper(shift)
	});
}


# these all behave the same way.
sub session_id    { my $self = shift; $self->_log('session_id',    @_);  }
sub url           { my $self = shift; $self->_log('url',           @_);  }
sub params        { my $self = shift; $self->_log('params',        @_);  }
sub template_conf { my $self = shift; $self->_log('template_conf', @_);  }
sub headers       { my $self = shift; $self->_log('headers',       @_);  }
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

sub report {
	my $self = shift;
	my %data = @_;

	push(@{$self->{'timer'}},[Time::HiRes::time,"end"]);

	my $last = $#{$self->{'timer'}};
	my $total_time = $self->{'timer'}->[$last]->[0] - $self->{'timer'}->[0]->[0];

	$self->{'template'}->param('generate_time' => $total_time);

	if ($self->{'enabled'}) {
		$self->{'template'}->param('debug' => 1);

		my $times = $self->{'timer'};
		$self->{'template'}->param('vd_timing' => [
			map {
				{
					'time'    => sprintf("%.5f",    $times->[$_]->[0] - $times->[$_-1]->[0]),
					'percent' => sprintf("%5.2f%%",($times->[$_]->[0] - $times->[$_-1]->[0])/$total_time*100),
					'message' => $times->[$_]->[1]
				}
			} (1 .. $last)
		]
		);


		# either dumper, or the param passing to template is a little weird.
		# if you inline the calls to dumper, it doesn't work.
		my %h;
		$h{'vd_debug'}    = $self->_process_debug();
		$h{'vd_template'} = Dumper($data{'params'});
		$h{'vd_session'}  = Dumper($data{'session'});
		$h{'vd_conf'}     = Dumper($data{'conf'});

		$self->{'template'}->param(%h);
	}

	return $self->{'template'}->output;
}

sub _process_debug {
	my $self = shift;

	my @debug = ();
	my @last  = ();
	foreach (@{$self->{'debug'}}) {
		my ($stack,$mesg) = @{$_};

		my $i=0;
		my $match = 1;
		my ($x,$y,@stack) = split(/~/,$stack);
		foreach (@stack) {
			unless ($match && $_ eq $last[$i]) {
				$match=1;
				push(@debug,{
					'depth' => $i,
					'name'  => $_
				});
			}
			$i++;
		}

		@last = @stack;

		push(@debug, {
				'depth' => ($#stack+1),
				'name'  => $mesg
		});
	}
	return \@debug;
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
