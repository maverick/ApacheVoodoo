################################################################################

=head1 NAME

Apache::Voodoo

=head1 VERSION

$Id$

=head1 SYNOPSIS

This object is used by Voodoo internally to handling various types of debugging
information and to produce and end user display of that information.  End users 
never interact with this module directly, instead they use the debug() and mark()
methods from L<Apache::Voodoo>

=head1 OUTPUT

=cut ###########################################################################
package Apache::Voodoo::Debug;

use strict;
use Time::HiRes;
use HTML::Template;
use Data::Dumper;

sub new {
	my $class = shift;

	my $self = {};

	bless($self,$class);

	my $file = $INC{"Apache/Voodoo/Debug.pm"};

	$file =~ s/Debug.pm/Template\/debug.tmpl/;

	$self->{'template'} = HTML::Template->new(
		'filename' => $file,
		'die_on_bad_params' => 0,
		'shared_cache' => 1
	);

	$self->reset();

	return $self;
}

sub reset {
	my $self = shift;

	$self->{'enabled'} = 1;

	undef $self->{'debug'};
	undef $self->{'timer'};

	$self->{'template'}->clear_params();
}

sub enable {
	my $self = shift;

	$self->{'enabled'} = 1;
}

sub disable {
	my $self = shift;

	$self->{'enabled'} = 0;
}

sub mark {
	my $self = shift;

	return unless $self->{'enabled'};

	push(@{$self->{'timer'}},[Time::HiRes::time,shift]);
}

sub debug {
	my $self = shift;

	return unless $self->{'enabled'};

	# trace the execution stack.
	# caller($i+1)[3] has the method that called
	# caller($i)[2]   has the line number that method was called from
	my $i=0;
	my $header;
	my $stack;
	while (my $method = (caller($i+1))[3]) {
		if ($method =~ /^Voodoo/) {
			$i++;
			next;
		}

		my $line = (caller($i++))[2];

		$header ||= "$method $line";

		$stack = "$method~$line~$stack" unless $line == 0;
	}

	my $mesg;
	foreach (@_) {
		$mesg .= (ref($_))? Dumper($_) : "$_\n";
	}

	push(@{$self->{'debug'}},[$stack,$mesg]);

	print STDERR "$header\n$mesg\n";
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

		my @debug;
		my @last;
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

		# either dumper, or the param passing to template is a little weird.
		# if you inline the calls to dumper, it doesn't work.
		my %h;
		$h{'vd_debug'}    = \@debug;
		$h{'vd_template'} = Dumper($data{'params'});
		$h{'vd_session'}  = Dumper($data{'session'});
		$h{'vd_conf'}     = Dumper($data{'conf'});

		$self->{'template'}->param(%h);
	}

	return $self->{'template'}->output;
}

1;

