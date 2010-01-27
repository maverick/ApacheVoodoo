=pod ################################################################################

=head1 NAME

Apache::Voodoo::Debug - handles operations associated with debugging output.

=head1 VERSION

$Id: Native.pm 16315 2009-06-08 22:14:23Z medwards $

=head1 SYNOPSIS

This object is used by Voodoo internally to handling various types of debugging
information and to produce end user display of that information.  End users 
never interact with this module directly, instead they use the debug() and mark()
methods from L<Apache::Voodoo>.

=cut ###########################################################################
package Apache::Voodoo::Debug::Native;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Debug/Native.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo::Debug::Common");

use IO::Socket::UNIX;
use IO::Handle::Record;
use HTML::Template;

use JSON::DWIW;
use Apache::Voodoo::Constants;

sub new {
	my $class = shift;

	my $id   = shift;
	my $conf = shift;

	my $self = {};
	bless($self,$class);

	$self->{id}->{app_id} = $id;

	my $ac = Apache::Voodoo::Constants->new();
	$self->{socket_file} = $ac->socket_file();

	my @flags = qw(debug info warn error exception table trace);
	my @flag2 = qw(profile params template_conf return_data session);

	$self->{enabled} = 0;
	if ($conf eq "1" || (ref($conf) eq "HASH" && $conf->{all})) {
		foreach (@flags,@flag2) {
			$self->{conf}->{$_} = 1;
		}
		$self->{conf}->{anydebug} = 1;
		$self->{enabled} = 1;
	}
	elsif (ref($conf) eq "HASH") {
		foreach (@flags) {
			if ($conf->{$_}) {
				$self->{conf}->{$_} = 1;
				$self->{conf}->{anydebug} = 1;
				$self->{enabled} = 1;
			}
		}
		foreach (@flag2) {
			if ($conf->{$_}) {
				$self->{conf}->{$_} = 1;
				$self->{enabled} = 1;
			}
		}
	}

	if ($self->{enabled}) {
		my $file = $INC{"Apache/Voodoo/Constants.pm"};
		$file =~ s/Constants.pm$/Debug\/html\/debug.tmpl/;

		$self->{template} = HTML::Template->new(
			'filename'          => $file,
			'die_on_bad_params' => 0,
			'global_vars'       => 1,
			'loop_context_vars' => 1
		);

		$self->{template}->param(
			debug_root => $ac->debug_path(),
			app_id     => $self->{id}->{app_id}
		);

		$self->{json} = JSON::DWIW->new({bad_char_policy => 'convert', pretty => 1});
	}

	# we always send this since is fundamental to identifying the request chain
	# regardless of what other info we log
	$self->{conf}->{url}        = 1;
	$self->{conf}->{status}     = 1;
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
				Peer => $self->{socket_file}
			);
		};

		if ($@ || 
			!defined($self->{'socket'}) ||
			!$self->{'socket'}->connected) {

			CORE::warn "Failed to open socket.  Debug info will be lost. $@ $!\n";
			$self->{enable}  = undef;
			$self->{enabled} = 0;
			return;
		}
	}

	# socket looks good, enable the public facing calls.
	$self->{enable} = $self->{conf};

	$self->_write({
		type => 'request',
		id   => $self->{'id'}
	});

	$self->{template}->param(request_id => $self->{id}->{request_id});
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

sub _debug {
	my $self = shift;
	my $type = shift;

	return unless $self->{'enable'}->{$type};

	my $data;
	if (scalar(@_) > 1 || ref($_[0])) {
		# if there's more than one item, or the item we have is a reference
		# then we need to serialize it.
		$data = $self->_encode(@_);
	}
	else {
		# simple scalar can be logged as is.
		$data = $_[0];
	}

	my $full = ($type =~ /(exception|trace)/)?1:0;

	$self->_write({
		type  => 'debug',
		id    => $self->{id},
		level => $type,
		stack => $self->_encode([$self->stack_trace($full)]),
		data  => $data
	});
}

sub mark {
	my $self = shift;

	return unless $self->{'enable'}->{'profile'};

	$self->_write({
		type      => 'profile',
		id        => $self->{id},
		timestamp => shift,
		data      => shift
	});
}

sub return_data {
	my $self = shift;

	return unless $self->{'enable'}->{'return_data'};

	$self->_write({
		type    => 'return_data',
		id      => $self->{id},
		handler => shift,
		method  => shift,
		data    => $self->_encode(shift)
	});
}


# these all behave the same way.  With the execption of session_id which
# also inserts it into the underlying template.
sub url           { my $self = shift; $self->_log('url',           @_); }
sub status        { my $self = shift; $self->_log('status',        @_); }
sub params        { my $self = shift; $self->_log('params',        @_); }
sub template_conf { my $self = shift; $self->_log('template_conf', @_); }
sub session       { my $self = shift; $self->_log('session',       @_); }

sub session_id { 
	my $self = shift; 
	my $id   = shift;

	$self->{template}->param(session_id => $id);
	$self->_log('session_id',$id);
}

sub _log {
	my $self = shift;
	my $type = shift;
	
	return unless $self->{'enable'}->{$type};

	my $data;
	if (scalar(@_) > 1 || ref($_[0])) {
		# if there's more than one item, or the item we have is a reference
		# then we need to serialize it.
		$data = $self->_encode(@_);
	}
	else {
		# simple scalar can be logged as is.
		$data = $_[0];
	}

	$self->_write({
		type => $type,
		id   => $self->{id},
		data => $data
	});
}

sub _encode {
	my $self = shift;
	
	my $j;
	if (scalar(@_) > 1) {
		$j = $self->{json}->to_json(\@_);
	}
	else {
		$j = $self->{json}->to_json($_[0]);
	}

	return $j;
}


sub _write {
	my $self = shift;
	my $data = shift;

	eval {
		$self->{'socket'}->write_record($data);

		# might be unneccessary, being paranoid
		$self->{'socket'}->sync;
		$self->{'socket'}->flush;
	};
	if ($@) {
		CORE::warn "Failed to write to debug database: $@ $!\n";
	}
}

sub finalize {
	my $self = shift;

	return () unless $self->{enabled};

	foreach (keys %{$self->{'enable'}}) {
		$self->{template}->param('enable_'.$_ => $self->{'enable'}->{$_});
	}

	return (_DEBUG_ => $self->{template}->output());
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
