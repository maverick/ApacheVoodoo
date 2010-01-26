#!/usr/bin/perl

use strict;
use warnings;

use IO::Socket::SIPC;
use IO::Socket::UNIX;
use Time::HiRes;

my $socket = IO::Socket::SIPC->new(
	socket_handler => 'IO::Socket::UNIX'
);

$socket->connect(
	Type => SOCK_STREAM,
	Peer => "/home/medwards/socket/test.sock"
);

print STDERR "$$ opened\n";

foreach (0 .. 10) {
	my $data = {
		'pid' => $$, 
		'timestamp' => time, 
		'foo' => [ 'a','b','c','d']
	};
	$socket->send($data);
	print STDERR "$$ sent ";
	sleep(1);
}

$socket->disconnect();
print STDERR "\n$$ closed\n";
