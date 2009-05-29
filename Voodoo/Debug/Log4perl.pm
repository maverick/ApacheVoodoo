=pod ################################################################################

=head1 NAME

Apache::Voodoo::Debug::Log4Perl

=head1 VERSION

$Id$

=head1 SYNOPSIS

=cut ###########################################################################
package Apache::Voodoo::Debug::Log4perl;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use base("Apache::Voodoo::Debug::Common");

use File::Spec;
use Log::Log4perl;
use Data::Dumper; $Data::Dumper::Terse = 1; $Data::Dumper::Indent = 1;

use Apache::Voodoo::Constants;

#
# Since log4perl wants to use one config file for the whole running perl program (one
# call to init), and # ApacheVoodo lets you define logging per application (multiple inits).
# We're using a singleton to get around that.
#
my $self;

sub new {
	my $class = shift;
	my $conf  = shift;

	if (ref($self)) {
		return $self;
	}

	$self = {};
	bless($self,$class);

	Log::Log4perl->init_and_watch($conf,10);

	return $self;
}

sub init {
	my $self = shift;
	my $mp   = shift;
}

sub enabled {
	return 1;
}


sub debug     { my $self = shift; $self->_get_logger->debug($self->_dumper(@_)); }
sub info      { my $self = shift; $self->_get_logger->info( $self->_dumper(@_)); }
sub warn      { my $self = shift; $self->_get_logger->warn( $self->_dumper(@_)); }
sub error     { my $self = shift; $self->_get_logger->error($self->_dumper(@_)); }
sub exception { my $self = shift; $self->_get_logger->fatal($self->_dumper(@_)); }

sub trace     { my $self = shift; $self->_get_logger->trace($self->_dumper(@_)); }
sub table     { my $self = shift; $self->_get_logger->debug($self->_dump_table(@_)); }

sub return_data   { my $self = shift; $self->_get_logger('ReturnData'  )->debug('return_data',   $self->_dumper(@_)); }
sub url           { my $self = shift; $self->_get_logger('Url'         )->debug('url',           $self->_dumper(@_)); }
sub status        { my $self = shift; $self->_get_logger('Status'      )->debug('status',        $self->_dumper(@_)); }
sub params        { my $self = shift; $self->_get_logger('Params'      )->debug('params',        $self->_dumper(@_)); }
sub template_conf { my $self = shift; $self->_get_logger('TemplateConf')->debug('template_conf', $self->_dumper(@_)); }
sub session       { my $self = shift; $self->_get_logger('Session'     )->debug('session',       $self->_dumper(@_)); }

sub mark { 
	my $self = shift; 

	push(@{$self->{profile}},[@_]);
}

sub shutdown {
	my $self = shift;

	my @d = $self->{profile};
	my $last = $#d;
	if ($last > 0) {
		my $total_time = $d[$last]->[0] - $d[0]->[0];

		my @return = map {
			[
				sprintf("%.5f",    $d[$_]->[0] - $d[$_-1]->[0]),
				sprintf("%5.2f%%",($d[$_]->[0] - $d[$_-1]->[0])/$total_time*100),
				$d[$_]->[1]
			]
		} (1 .. $last);

		unshift(@return, [
			sprintf("%.5f",$total_time),
			'percent', 
			'message'
		]);

		my $logger = $self->_get_logger("Profile");
		$logger->debug($self->_dump_table("Profile",\@return));
	}

	delete $self->{profile};
}

sub _dumper {
	my $self = shift;
	my @data = @_;
	return sub {
		if (scalar(@data) > 1 || ref($data[0])) {
			# if there's more than one item, or the item we have is a reference
			# then we need to serialize it.
			return Dumper \@data;
		}
		else {
			return $data[0];
		}
	};
}

sub _get_logger {
	my $self    = shift;
	my $section = shift;

	if ($section) {
		return Log::Log4perl->get_logger("Apache::Voodoo::".$section);
	}
	else {
		my @stack = $self->stack_trace();
		if (scalar(@stack)) {
			return Log::Log4perl->get_logger($stack[-1]->{class});
		}
		else {
			return Log::Log4perl->get_logger("Apache::Voodoo");
		}
	}
}

sub _dump_table {
	my $self = shift;
	my @data = @_;

	return sub {
		my $name = "Table";
		if (scalar(@data) > 1) {
			$name = shift @data;
		}

		my @return = ($name);

		my @col;
		# find the widest element in each column
		foreach my $row (@{$data[0]}) {
			for (my $i=0; $i < scalar(@{$row}); $i++) {
				if (!defined($col[$i]) || length($row->[$i]) > $col[$i]) {
					$col[$i] = length($row->[$i]);
				}
			}
		}

		my $t_width = 2;	    # "| "
		foreach (@col) {
			$t_width += $_ + 3; # " | "
		}
		$t_width -= 1;          # "| " -> "|"

		push(@return,'-' x $t_width);
		foreach my $row (@{$data[0]}) {
			my $line = "| ";
			for (my $i=0; $i < scalar(@{$row}); $i++) {
				$line .= sprintf("%-".$col[$i]."s",$row->[$i]) . " | ";
			}
			$line =~ s/ $//;
			push (@return,$line);
			push(@return,'-' x $t_width);
		}
		return "\n".join("\n",@return);
	};
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
