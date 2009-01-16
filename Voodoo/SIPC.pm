=head1 NAME

IO::Socket::SIPC - Serialize perl structures for inter process communication.

=head1 SYNOPSIS

    use IO::Socket::SIPC;

    my $sipc = IO::Socket::SIPC->new(
       socket_handler => 'IO::Socket::INET',
       use_check_sum  => 1,
       read_max_bytes => '512k',
       send_max_bytes => '512k'
    );

    $sipc->connect(
       LocalAddr       => $address,
       LocalPort       => $port,
       Proto           => $proto,
       Listen          => $listen,
       ReuseAddr       => $reuse,
    ) or die $sipc->errstr;

    my $client = $sipc->accept($timeout);

    my %perl_struct = (
       hash  => { foo => 'bar' },
       array => [ 'foo', 'bar' ],
    );

    $client->send( \%perl_struct );

=head1 DESCRIPTION

This module makes it possible to transport perl structures between processes. It wraps
your IO::Socket handler and controls the amount of data and verifies it with a checksum.

The default serializer is Storable with C<nfreeze()> and C<thaw()> and the default checksum generator
is Digest::MD5 with C<md5()> but you can choose any other serializer or checksum generator you wish
to use, there are just some restrictions that you have to comply with and you only need to adjust a
few lines of code by yourself.

=head1 METHODS

=head2 new()

The C<new()> constructor method creates a new IO::Socket::SIPC object. A list of parameters may be
passed to it as a hash or hash reference.

    socket_handler  Set your socket handler - IO::Socket::(INET|INET6|UNIX|SSL).
    deflate         Pass your own sub reference for serializion.
    inflate         Pass your own sub reference for deserializion.
    read_max_bytes  Set the maximum allowed bytes to read from the socket.
    send_max_bytes  Set the maximum allowed bytes to send over the socket.
    use_check_sum   Check each transport with a MD5 sum.
    gen_check_sum   Set up your own checksum generator.

The defaults are:

    socket_handler  IO::Socket::INET
    deflate         nfreeze() of Storable
    inflate         thaw() of Storable (in a Safe compartment)
    read_max_bytes  unlimited
    send_max_bytes  unlimited
    use_check_sum   disabled (enable it with 1)
    gen_check_sum   md5() of Digest::MD5 if use_check_sum is enabled

=over 4

=item socket_handler

Set your socket handler - IO::Socket::INET, IO::Socket::INET6, IO::Socket::UNIX or IO::Socket::SSL.

    use IO::Socket::SIPC;

    my $sipc = IO::Socket::SIPC->new( socket_handler => 'IO::Socket::SSL' );
    
=item deflate, inflate

Set your own serializer:

    use IO::Socket::SIPC;
    use Convert::Bencode_XS;

    my $sipc = IO::Socket::SIPC->new(
        deflate => sub { Convert::Bencode_XS::bencode($_[0]) },
        inflate => sub { Convert::Bencode_XS::bdecode($_[0]) },
    );

    # or maybe

    use IO::Socket::SIPC;
    use JSON::PC;

    my $sipc = IO::Socket::SIPC->new(
        deflate => sub { JSON::PC::convert($_[0]) },
        inflate => sub { JSON::PC::parse($_[0])   },
    );

NOTE that the code that you handoff to deflate and inflate is embedded in an eval block for executions
and if an error occurs you can get the error string by calling C<errstr()>. If you use the default
deserializer of Storable then the data is deserialized in a Safe compartment. If you use another
deserializer you have to build your own Safe compartment!

=item use_check_sum

Turn it on (1) or off (0). If you turn it on then a checksum is generated for any packet that is transportet.

The default checksum generator is C<md5()> of Digest::MD5.

=item gen_check_sum

Use your own checksum generator:

    use Digest::SHA2;

    my $sha2obj = new Digest::SHA2;

    my $sipc = IO::Socket::SIPC->new(
        gen_check_sum => sub { $sha2obj->digest($_[0]) }
    );

But I think Digest::MD5 is very well and it does it's job.

=item read_max_bytes, send_max_bytes

Increase or decrease the maximum size of bytes that a peer is allowed to send or read.
Possible sizes are KB, MB and GB or just a number for bytes. It's not case sensitiv and
you can use C<KB> or C<kb> or just C<k>. Notation examples:

    # 1 MB
    read_max_bytes => 1048576
    read_max_bytes => '1024k'
    read_max_bytes => '1MB'

    # unlimited
    read_max_bytes => 0
    read_max_bytes => unlimited

NOTE that the readable and sendable size is computed by the serialized data or on the raw data
if you use C<read_raw()> or C<send_raw()>.

=back

=head2 connect()

Call C<connect()> to connect to the socket. C<connect()> just call C<new()> of your socket handler
and passes all parameters to it. Example:

    my $sipc = IO::Socket::SIPC->new( socket_handler => 'IO::Socket::INET' );

    $sipc->connect(
        PeerAddr => 'localhost',
        PeerPort => '50010',
        Proto    => 'tcp',
    );

    # would call intern

    IO::Socket::INET->new(@_);

You can pass all parameters that are allowed of your socket handler. I don't check it.

=head2 accept()

If a Listen socket is defined then you can wait for connections with C<accept()>. C<accept()> is
just a wrapper to the original C<accept()> method of your socket handler. If a connection is accepted
then a new object is created related to the peer. The new object will be returned on success,
undef on error and 0 on a timeout.

You can set a timeout value in seconds.

    my $c = $sipc->accept(10)
    warn "accept: timeout" if defined $c;

=head2 is_timeout()

Another check if you want to know if a timeout happends.

    while ( 1 ) {
       while ( my $c = $sipc->accept(10) ) {
          # processing
       }
       warn "accept: timeout" if $sipc->is_timeout;
    }

=head2 disconnect()

Call C<disconnect()> to disconnect the current connection. C<disconnect()> calls C<close()> on
the socket that is referenced by the object.

    my $c = $sipc->accept();
    $c->disconnect;    # would close $c
    $sipc->disconnect; # would close $sipc

=head2 sock()

Call C<sock()> to access the raw object of your socket handler.

IO::Socket::INET examples:

    $sipc->sock->timeout(10);
    # or
    $peerhost = $sipc->sock->peerhost;
    # or
    $peerport = $sipc->sock->peerport;
    # or
    $sock = $sipc->sock;
    $peerhost = $sock->peerhost;

NOTE that if you use

    while ( my $c = $sipc->sock->accept ) { ... }

that $c is the unwrapped IO::Socket::* object and not a IO::Socket::SIPC object.

=head2 send()

Call C<send()> to send data over the socket to the peer. The data will be serialized
and packed before it sends to the peer. If you use the default serializer then you
must handoff a reference, otherwise an error occurs because C<nfreeze()> of Storable
just works with references.

    $sipc->send("Hello World!");  # this would fail
    $sipc->send(\"Hello World!"); # this not

If you use your own serializer then consult the documentation for what the serializer expect.

C<send()> returns undef on errors or if send_max_bytes is overtaken.

=head2 read()

Call C<read()> to read data from the socket. The data will be unpacked and deserialized
before it's returned. If the maximum bytes is overtaken or an error occured then
C<read()> returns undef and aborts to read from the socket.

=head2 read_raw() and send_raw()

If you want to read or send a raw string and disable the serializer for a single transport then
you can call C<read_raw()> or C<send_raw()>. Note that C<read_raw()> and C<send_raw()> doesn't
work with references!

=head2 errstr()

Call C<errstr()> to get the current error message if a method returns FALSE. C<errstr()> is not
useable with C<new()> because C<new()> croaks with incorrect arguments.

NOTE that C<errstr()> returns the current error message and contain C<$!> if necessary. If you use
IO::Socket::SSL then the message from IO::Socket::SSL->errstr is appended as well.

=head2 debug()

You can turn on a little debugger if you like

    $sipc->debug(1);

It you use IO::Socket::SSL then C<$IO::Socket::SSL::DEBUG> is set to that level that you passed with C<debug()>.

=head1 EXAMPLES

Take a look to the examples directory.

=head2 Server example

    use strict;
    use warnings;
    use IO::Socket::SIPC;

    my $sipc = IO::Socket::SIPC->new(
       socket_handler => 'IO::Socket::INET',
       use_check_sum  => 1,
    );

    $sipc->connect(
       LocalAddr  => 'localhost',
       LocalPort  => 50010,
       Proto      => 'tcp',
       Listen     => 10, 
       Reuse      => 1,
    ) or die $sipc->errstr;

    $sipc->debug(1);

    while ( 1 ) { 
       my $client;
       while ( $client = $sipc->accept(10) ) { 
          print "connect from client: ", $client->sock->peerhost, "\n";
          my $request = $client->read_raw or die $client->errstr;
          next unless $request;
          chomp($request);
          warn "client says: $request\n";
          $client->send({ foo => 'is foo', bar => 'is bar', baz => 'is baz'}) or die $client->errstr;
          $client->disconnect or die $client->errstr;
       }   
       die $sipc->errstr unless defined $client;
       warn "server runs on a timeout, re-listen on socket\n";
    }

    $sipc->disconnect or die $sipc->errstr;

=head2 Client example

    use strict;
    use warnings;
    use Data::Dumper;
    use IO::Socket::SIPC;

    my $sipc = IO::Socket::SIPC->new(
       socket_handler => 'IO::Socket::INET',
       use_check_sum  => 1,
    );

    $sipc->connect(
       PeerAddr => 'localhost',
       PeerPort => 50010,
       Proto    => 'tcp',
    ) or die $sipc->errstr;

    $sipc->debug(1);

    $sipc->send_raw("Hello server, gimme some data :-)\n") or die $sipc->errstr;
    my $answer = $sipc->read or die $sipc->errstr;
    warn "server data: \n";
    warn Dumper($answer);
    $sipc->disconnect or die $sipc->errstr;

=head1 PREREQUISITES

    UNIVERSAL::require  -  to post load modules
    IO::Socket::INET    -  the default socket handler
    Digest::MD5         -  to check the data before and after transports
    Storable            -  the default serializer and deserializer
    Safe                -  deserialize (Storable::thaw) in a safe compartment

=head1 EXPORTS

No exports.

=head1 REPORT BUGS

Please report all bugs to <jschulz.cpan(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <jschulz.cpan(at)bloonix.de>.

=head1 QUESTIONS

Do you have any questions or ideas?

MAIL: <jschulz.cpan(at)bloonix.de>

IRC: irc.perl.org#perlde

=head1 TODO AND IDEAS

    * do you have any ideas?
    * maybe another implementations of check sum generators
    * do you like to have another wrapper as accept()? Tell me!
    * auto authentification

=head1 COPYRIGHT

Copyright (C) 2007 by Jonny Schulz. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

package SIPC;
our $VERSION = '0.07';

use strict;
use warnings;
use UNIVERSAL::require;
use Carp qw/croak/;

# globals
use vars qw/$ERRSTR $MAXBUF $DEBUG/;
$ERRSTR = defined;
$MAXBUF = 16384;

sub new {
   my $class = shift;
   my $args  = ref($_[0]) eq 'HASH' ? shift : {@_};
   my $self  = bless {}, $class;

   $self->{read_max_bytes} = $class->_cal_bytes($args->{read_max_bytes} || 0);
   $self->{send_max_bytes} = $class->_cal_bytes($args->{send_max_bytes} || 0);

   $self->{use_check_sum}  =
      defined $args->{use_check_sum}
         ? $args->{use_check_sum} =~ /^[10]*\z/
              ? $args->{use_check_sum}
              : croak "$class: invalid value for use_check_sum"
         : 0;

   $self->_load_digest($args->{gen_check_sum});
   $self->_load_serializer($args->{deflate}, $args->{inflate});
   $self->_load_socket_handler($args->{socket_handler} || $args->{favorite} || 'IO::Socket::INET');

   return $self;
}

sub connect {
   my $self = shift;
   my $socket_handler = $self->{socket_handler};
   warn "create a new $self->{socket_handler} object" if $DEBUG;
   $self->{sock} = $socket_handler->new(@_)
      or return $self->_raise_sock_error("unable to create socket");
   return 1;
}

sub accept {
   my ($self, $timeout) = @_; 
   my $class = ref($self);
   my $sock = $self->{sock} or return $self->_raise_error("there is no socket defined");
   my %options = %{$self};

   if (defined $timeout) {
      croak "$class: timeout isn't numeric" unless $timeout =~ /^\d+\z/;
      warn "set timeout to '$timeout'" if $DEBUG;
      $sock->timeout($timeout);
   }   

   warn "waiting for connection" if $DEBUG;

   my $new_sock = $sock->accept or do {
      if ($! == &Errno::ETIMEDOUT) {
         warn $@ if $DEBUG;
         $ERRSTR = $@; return 0;
      } else {
         return $self->_raise_sock_error("accept() error");
      }
   };  

   warn "incoming request" if $DEBUG;

   # create and return a new object
   warn "create a new IO::Socket::SIPC object" if $DEBUG;
   my %new = %{$self};
   $new{sock} = $new_sock;
   return bless \%new, $class;
}

sub is_timeout { $! == &Errno::ETIMEDOUT }

sub disconnect {
   my $self = shift;
   my $sock = $self->{sock} || return 1;
   warn "disconnecting" if $DEBUG;
   close($sock) or return $self->_raise_error("unable to close socket: $!");
   undef $self->{sock};
   return 1;
}

sub send_raw {
   warn "send raw data" if $DEBUG;
   return $_[0]->send($_[1], 1)
}

sub read_raw {
   warn "read raw data" if $DEBUG;
   return $_[0]->read(1)
}

sub send {
   my ($self, $data, $no_deflate) = @_;
   my $maxbyt = $self->{send_max_bytes};
   my $sock   = $self->{sock};

   warn "send data" if !$no_deflate && $DEBUG;

   unless ($no_deflate) {
      $data = $self->_deflate($data)
         or return undef;
   }

   my $length = length($data);

   return $self->_raise_error("the data length ($length bytes) exceeds send_max_bytes")
      if $maxbyt && $length > $maxbyt;

   if ($self->{use_check_sum}) {
      my $checksum = $self->_gen_check_sum($data) or return undef;
      $checksum    = pack("n/a*", $checksum); # 2 bytes
      $self->_send(\$checksum) or return undef;
   }

   $data = pack("N/a*", $data);
   return $self->_send(\$data);
}

sub read {
   my ($self, $no_inflate) = @_;
   my $maxbyt  = $self->{read_max_bytes};
   my $sock    = $self->{sock};
   my $recvsum = ();

   warn "read data" if !$no_inflate && $DEBUG;

   if ($self->{use_check_sum}) {
      warn "read checksum" if $DEBUG;
      my $packet = $self->_read(2) or return undef;
      my $sumlen = unpack("n", $$packet);
      $recvsum   = $self->_read($sumlen) or return undef;
   }

   my $buffer = $self->_read(4) or return undef;
   my $length = unpack("N", $$buffer)
      or return $self->_raise_error("no data in buffer");

   return $self->_raise_error("the buffer length ($length bytes) exceeds read_max_bytes")
      if $maxbyt && $length > $maxbyt;

   warn "read data packet" if $DEBUG;
   my $packet = $self->_read($length);

   if ($self->{use_check_sum}) {
      my $checksum = $self->_gen_check_sum($$packet) or return undef;
      warn "compare checksums" if $DEBUG;
      return $self->_raise_error("the checksums are not identical")
         unless $$recvsum eq $checksum;
   }

   return $no_inflate ? $$packet : $self->_inflate($$packet);
}

sub sock {
   # return object || class
   warn "access sock object" if $DEBUG;
   return $_[0]->{sock} || $_[0]->{socket_handler};
}

sub errstr { return $ERRSTR }

sub debug {
   my $self;
   ($self, $DEBUG) = @_;
   if ($self->{socket_handler} eq 'IO::Socket::SSL') {
      warn "set IO::Socket::SSL::DEBUG to level $DEBUG" if $DEBUG;
      $IO::Socket::SSL::DEBUG = $DEBUG;
   }
}

# -------------
# private stuff
# -------------

sub _send {
   my ($self, $packet) = @_;
   my $sock = $self->{sock};
   my $length = length($$packet);
   my $rest   = $length;
   my ($offset, $written) = (0, undef);

   while ( $rest ) {
      $written = syswrite $sock, $$packet, $rest, $offset;
      return $self->_raise_error("system write error: $!")
         unless defined $written;
      $rest   -= $written;
      $offset += $written;
      warn "send $offset/$length bytes" if $DEBUG;
   }

   return 1;
}

sub _read {
   my ($self, $length) = @_;
   my $sock = $self->{sock};
   my $rest = $length;
   my $rdsz = $length < $MAXBUF ? $length : $MAXBUF;
   my ($packet, $rlen);

   while ( my $len = sysread $sock, my $buf, $rdsz ) {
      if (!defined $len) {
         next if $! =~ /^Interrupted/;
         return $self->_raise_error("system read error: $!");
      }
      $packet .= $buf;  # concat the data pieces
      $rest   -= $len;  # this is the rest we have to read
      $rlen   += $len;  # to compare later how much we read and what we expected to read
      warn "read $rlen/$length bytes" if $DEBUG;
      $rest   || last;  # jump out if we read all data
      $rdsz    = $rest  # otherwise sysread() hangs if we wants to read to much
         if $rest < $MAXBUF;
   }

   return $self->_raise_error("read only $rlen/$length bytes from socket")
      if $rest;

   return \$packet;
}

sub _deflate {
   my ($self, $data) = @_;
   warn "deflate data" if $DEBUG;
   eval { $data = $self->{deflate}($data) };
   return $@ ? $self->_raise_error("unable to deflate data: ".$@) : $data;
}

sub _inflate {
   my ($self, $data) = @_;
   warn "inflate data" if $DEBUG;
   eval { $data = $self->{inflate}($data) };
   return $@ ? $self->_raise_error("unable to inflate data: ".$@) : $data;
}

sub _gen_check_sum {
   my ($self, $data) = @_;
   warn "generate checksum" if $DEBUG;
   eval { $data = $self->{gen_check_sum}($data) };
   return $@ ? $self->_raise_error("unable to generate checksum: ".$@) : $data;
}

sub _load_serializer {
   my ($self, $deflate, $inflate) = @_;
   my $class = ref($self);

   if ($deflate || $inflate) {
      croak "$class: deflate and inflate must be a code ref"
         unless ref($deflate) eq 'CODE' || ref($inflate) eq 'CODE';
      $self->{deflate} = $deflate;
      $self->{inflate} = $inflate;
   } else {
      'Storable'->require;
      'Safe'->require;

      my $safe = Safe->new;
      $safe->permit(qw/:default require/);

      {  # no warnings 'once' block
          no warnings 'once';
          $Storable::Deparse = 1;
          $Storable::Eval = sub { $safe->reval($_[0]) };
      }

      $self->{deflate} = sub { Storable::nfreeze($_[0]) };
      $self->{inflate} = sub { Storable::thaw($_[0]) };
   }
}

sub _load_socket_handler {
   my ($self, $socket_handler) = @_;
   my $class = ref($self);
   $socket_handler =~ /^IO::Socket::(?:INET[6]{0,1}|UNIX|SSL)\z/
      or croak "$class: invalid socket_handler '$socket_handler'";
   $socket_handler->require
      or croak "$class: unable to require $socket_handler";
   $self->{socket_handler} = $socket_handler;
}

sub _cal_bytes {
   my ($class, $bytes) = @_;
   return
      !$bytes || $bytes =~ /^unlimited\z/i
         ? 0
         : $bytes =~ /^\d+\z/
            ? $bytes
            : $bytes =~ /^(\d+)\s*kb{0,1}\z/i
               ? $1 * 1024
               : $bytes =~ /^(\d+)\s*mb{0,1}\z/i
                  ? $1 * 1048576
                  : $bytes =~ /^(\d+)\s*gb{0,1}\z/i
                     ? $1 * 1073741824
                     : croak "$class: invalid bytes specification for " . (caller(0))[3];
}

sub _load_digest {
   my ($self, $code) = @_;
   my $class = ref($self);
   if ($code) {
      croak "$class: gen_check_sum is not a code ref"
         unless ref($code) eq 'CODE';
      $self->{gen_check_sum} = $code;
   } else {
      'Digest::MD5'->require or croak "unable to require Digest::MD5: $!";
      $self->{gen_check_sum} = \&Digest::MD5::md5;
   }
}

sub _raise_error {
   $ERRSTR = $_[1];
   warn $ERRSTR if $DEBUG;
   return undef;
}

sub _raise_sock_error {
   my $self = $_[0];
   $ERRSTR = $_[1];

   $ERRSTR .= " - $!" if $!;

   if ($self->{socket_handler} eq 'IO::Socket::SSL') {
      my $sslerr = $self->{sock} ? $self->{sock}->errstr : IO::Socket::SSL->errstr;
      $ERRSTR .= " - $sslerr" if $sslerr;
   }

   warn $ERRSTR if $DEBUG;
   return undef;
}

1;
