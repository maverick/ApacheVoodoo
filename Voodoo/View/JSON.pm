=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Template::JSON

=head1 VERSION

$Id: JSON.pm 17740 2009-07-22 19:50:42Z medwards $

=head1 SYNOPSIS


=cut ################################################################################
package Apache::Voodoo::View::JSON;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/View/JSON.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use JSON::DWIW;

use base("Apache::Voodoo::View");

sub init {
	my $self   = shift;
	my $config = shift;

	$self->content_type('application/javascript');

	$self->{json} = JSON::DWIW->new({
		'bad_char_policy' => 'convert',
		'pretty' => ($config->{dynamic_loading})?1:0
	});
}

sub params {
	my $self = shift;

	if (defined($_[0])) {
		$self->{data} = shift;
	}
} 

sub exception {
	my $self = shift;
	my $e    = shift;

	my $d;
		
	if ($e->isa("Exception::Class::DBI")) {
		$d = {
			"description" => "Database Error",
			"message"     => $e->errstr,
			"package"     => $e->package,
			"line"        => $e->line,
			"query"       => $self->_format_query($e->statement)
		};
	}
	elsif ($e->isa("Apache::Voodoo::Exception::RunTime")) {
		$d = {
			"description" => $e->description,
			"message"     => $e->error,
			"stack"       => $self->_stack_trace($e->trace())
		};
	}
	else {
		$d = {
			"description" => ref($e),
			"message" => "$e"
		};
	}

	$d->{'success'} = 0;
	$d->{'error'}   = 1;

	$self->{data} = $d;
}

sub output {
	my $self = shift;

	return scalar($self->{json}->to_json($self->{data}));
}

sub finish {
	my $self = shift;

	$self->{data} = {};
}

sub _stack_trace {
	my $self  = shift;
	my $trace = shift;

	unless (ref($trace) eq "Devel::StackTrace") {
		return [];
	}

	my @trace;
	my $i = 1;
    while (my $frame = $trace->frame($i++)) {
		last if ($frame->package =~ /^Apache::Voodoo::Engine/);
        next if ($frame->package =~ /^Apache::Voodoo/);
        next if ($frame->package =~ /(eval)/);

		my $f = {
			'class'    => $frame->package,
			'function' => $trace->frame($i)->subroutine,
			'file'     => $frame->filename,
			'line'     => $frame->line,
		};
		$f->{'function'} =~ s/^$f->{'class'}:://;

		my @a = $trace->frame($i)->args;
		# if the first item is a reference to same class, then this was a method call
		if (ref($a[0]) eq $f->{'class'}) {
			shift @a;
			$f->{'type'} = '->';
		}
		else {
			$f->{'type'} = '::';
		}
		$f->{'args'} = \@a;

		push(@trace,$f);

    }
	return \@trace;
}

sub _format_query {
	my $self  = shift;
	my $query = shift;

	my $leading = undef;
	my @lines; 
	foreach my $line (split(/\n/,$query)) {
		$line =~ s/[\r\n]//g;
		$line =~ s/(?<![ \S])\t/    /g;    # negative look-behind assertion.  replaces only leading tabs

		if (!defined($leading)) {
			next if $line =~ /^\s*$/;
			my $l = $line;
			$l =~ s/\S.*$//;
			if (length($l)) {
				$leading = length($l);
			}
		}
		else {
			my $l = $line;
			$l =~ s/\S.*$//;
			if (length($l) and length($l) < $leading) {
				$leading = length($l);
			}
		}
		push (@lines,$line);
	}

	return join(
		"\n",
		map {
			$_ =~ s/^ {$leading}//;
			$_;
		} @lines
	);
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file 
include in this package or L<Apache::Voodoo::license>.  The summary is it's a 
legalese version of the Artistic License :)

=cut ################################################################################
