# $Id$
package Apache::Voodoo::Loader::Dynamic;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use base("Apache::Voodoo::Loader");

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;

	$self->{'module'} = shift;

	$self->{'bootstrapping'} = 1;
	$self->refresh;
	$self->{'bootstrapping'} = 0;

	$self->{'parents'} = {};
	foreach (eval '@{'.$self->{'module'}.'::ISA}') {
		$self->{'parents'}->{$_} = $self->get_mtime($_);
	}

	return $self;
}

sub get_mtime {
	my $self = shift;
	my $file = shift || $self->{'module'};

	$file =~ s/::/\//go;
	$file .= ".pm";

	my $mtime = (stat($INC{$file}))[9];

	return $mtime;
}

sub refresh {
	my $self = shift;

	$self->{'object'} = $self->load_module;
	$self->{'mtime'}  = $self->get_mtime;

	# zap our created closures.
	foreach my $method (keys %{$self->{'provides'}}) {
		# a little help from the Cookbook 10.14
		no strict 'refs';
		*$method = undef;
	}
	$self->{'provides'} = {};
}

# 
# Override the built in 'can' to allow:
#   a) trigger dynamically reloading the module as needed
#   b) dynamically create closures to link Apache::Voodoo::Handler with userland modules
# 
# This has some nice side effects.  
#   Static vs Dynamic loading is totally transparent to the interaction between Voodoo and userland modules.  
#
sub can {
	my $self = shift;
	my $method = shift;

	# find out if this thing has changed
	if ($self->{'mtime'} != $self->get_mtime) {
		$self->refresh;
	}

	if (defined $self->{'provides'}->{$method}) {
		return 1;
	}
	elsif ($self->{'object'}->isa("Apache::Voodoo::Zombie") || $self->{'object'}->can($method)) {
		# either we have a dead module and we map whatever was requested or
		# we have a live one and it can do the requested method

		# cache the existance of this method
		$self->{'provides'}->{$method} = 1;

		# create a closeure for this method (a little help from the Cookbook 10.14)
		no strict 'refs';
		*$method = sub { my $self = shift; return $self->_handle($method,@_); };
		return 1;
	}

	return 0;
}

sub _handle {
	my $self = shift;
	my $method = shift;
	my @params = @_;

	# check parent modules for change
	foreach my $module (eval '@{'.$self->{'module'}.'::ISA}') {
		my $t = $self->get_mtime($module);
		if ($self->{'parents'}->{$module} != $t) {
			$self->{'parents'}->{$module} = $t;

			my $file = $module;
			$file =~ s/::/\//go;
			$file .= ".pm";
			delete $INC{$file};
			eval {
				require $file;
			};
			if ($@) {
				my $error = "<pre>\n";
				$error .= "There was an error loading one of the base classes for this page ($_):\n\n";
				$error .= "$@\n";
				$error .= "</pre>";

				my $link = $self->{'module'};
				
				$link =~ s/::/\//g;
				unless ($method eq "handle") {
					$link =~ s/([^\/]+)$/$method."_".$1/e;
				}

				#FIXME replace with a instance of Apache::Voodoo::Zombie
				$self->debug("ZOMBIE: $self->{'module'} $method");
				return $self->display_error($error,"/$link");
			}
		}	
	}

	return $self->{'object'}->$method(@params);
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file include
in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
of the Artistic License :)

=cut ################################################################################
