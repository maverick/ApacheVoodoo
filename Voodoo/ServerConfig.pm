#####################################################################################

=head1 Apache::Voodoo::ServerConfig

$Id$

=head1 Initial Coding: Maverick

This handles all of the config file parsing and module loading.

=cut ################################################################################

package Apache::Voodoo::ServerConfig;

$VERSION = '1.10';

use strict;
use Config::General;
use Data::Dumper;

sub new {
	my $class = shift;
   	my $self = {};

	bless $self, $class;

	my $conf = shift;
	if (defined($conf)) {
		$self->load($conf);
	}

	return $self;
}

sub load {
	my $self = shift;
	my $conf_file = shift;

	$self->load_config($conf_file);

	# get the list of modules we're going to use
	foreach (keys %{$self->{'modules'}}) {
		$self->prep_module($_);
	}

	foreach (keys %{$self->{'includes'}}) {
		$self->prep_include($_);
	}

	unless($self->{'dynamic_loading'}) {
		delete $self->{'modules'};
		delete $self->{'includes'};
	}
}

sub load_config {
	my $self = shift;
	my $conf_file = shift;

	my $conf = Config::General->new($conf_file);
	my %conf = $conf->getall();

	my ($id) = ($conf_file =~ /([a-zA-Z][\w-]*)\.conf$/);
	$self->{'id'} = $id;

	$self->{'base_package'} = $conf{'base_package'} || $self->{'id'};

	$self->{'session_dir'}     = $conf{'session_dir'};
	$self->{'session_timeout'} = $conf{'session_timeout'} || 0;
	$self->{'cookie_name'}     = $conf{'cookie_name'}     || uc($self->{'id'}). "_SID";
	$self->{'shared_cache'}    = $conf{'shared_cache'}    || 0;
	$self->{'context_vars'}    = $conf{'context_vars'}    || 0;
	$self->{'template_conf'}   = $conf{'template_conf'}   || {};

	if (defined($conf{'devel_mode'})) {
		if ($conf{'devel_mode'}) {
			$self->{'debug'} = 1;
			$self->{'dynamic_loading'} = 1;
			$self->{'halt_on_errors'}  = 0;
		}
		else {
			$self->{'debug'} = 0;
			$self->{'dynamic_loading'} = 0;
			$self->{'halt_on_errors'}  = 1;
		}
	}
	else {
		$self->{'debug'}           = $conf{'debug'} || 0;
		$self->{'dynamic_loading'} = $conf{'dynamic_loading'} || 0;
		$self->{'halt_on_errors'}  = defined($conf{'halt_on_errors'})?$conf{'halt_on_errors'}:1;
	}

	if ($self->{'dynamic_loading'}) {
		$self->{'conf_mtime'}  = (stat($conf_file))[9];
		$self->{'conf_file'}   = $conf_file;
	}

	$self->debug($conf{'database'});
	if (defined($conf{'database'})) {
		my $db;
		if (ref($conf{'database'}) eq "ARRAY") {
			$db = $conf{'database'};
		}
		else {
			$db = [ $conf{'database'} ];
		} 

		# make the connect string a perl array ref
		$self->{'dbs'} = [ 
						  map {
								[ 
								   $_->{'connect'},
								   $_->{'username'},
								   $_->{'password'},
								   $_->{'extra'}
								]
							  } @{$db} 
						 ];
	}

	$self->{'modules'}  = $conf{'modules'}  || {};
	$self->{'includes'} = $conf{'includes'} || {};

	# make a dummy entry for default if it doesn't exists.
	# save an if(defined blah blah) on every page request.
	unless (defined($self->{'template_conf'}->{'default'})) {
		$self->{'template_conf'}->{'default'} = {};
	}

	#
	# Theme support
	#
	if (defined($conf{'themes'}) && $conf{'themes'}->{'use_themes'} == 1) {
		$self->{'use_themes'} = 1;
		$self->{'themes'}->{'__default__'} = $conf{'themes'}->{'default'};
		my $has_one = 0;
		foreach (@{$conf{'themes'}->{'theme'}}) {
			$self->{'themes'}->{$_->{'name'}} = $_->{'dir'};
			$has_one = 1;
		}
		
		unless($has_one) {
			$self->{'errors'}++;
			print STDERR "You must define at least one theme block\n";
		}
	}

	# remove pre/post includes from display error...if one of them had 
	# the error you'd have an infinite redirect loop :)
	$self->{'template_conf'}->{'display_error'}->{'pre_include'}  = "";
	$self->{'template_conf'}->{'display_error'}->{'post_include'} = "";
}

sub prep_module {
	my $self = shift;
	my $module = shift;

	my $obj = $self->load_module($module);
	$module =~ s/::/\//g;
	$self->{'handlers'}->{$module} = $obj;
}

sub prep_include {
	my $self = shift;
	my $module = shift;

	my $obj = $self->load_module($module);

	$self->{'handlers'}->{$module} = $obj;
}

sub map_uri {
	my $self = shift;
	my $uri  = shift;

	if (defined($self->{'handlers'}->{$uri})) {
		return [$uri,"handle"];
	}
	else {
		my ($p,$m,$o) = ($uri =~ /^(.*?)([a-z]+)_(\w+)$/);
		return ["$p$o",$m];
	}
}

sub refresh {
	my $self = shift;
	my $page = shift;

	# bypass if we're not doing dynamic loading
	return unless $self->{'dynamic_loading'};

	# check to see if we need to refresh the config.
	if ($self->{'conf_mtime'} != (stat($self->{'conf_file'}))[9]) {
		$self->debug("refreshing $self->{'conf_file'}");

		my %old_module  = %{$self->{'modules'}};
		my %old_include = %{$self->{'includes'}};

		$self->load_config($self->{'conf_file'});

		# check the new list of modules against the old list
		foreach (keys %{$self->{'modules'}}) {
			unless (exists($old_module{$_})) {
				# new module (wasn't in the old list.
				$self->debug("Adding new module: $_");
				$self->prep_module($_);
			}

			# still a valid module, so remove it from this list.
			delete $old_module{$_};
		}

		# whatever is left in old_modules are ones that weren't in the new list.
		foreach (keys %old_module) {
			$self->debug("Removing old module: $_");
			$_ =~ s/::/\//g;
			delete $self->{'handlers'}->{$_};
		}

		# now we do exactly the same thing for the includes
		foreach (keys %{$self->{'includes'}}) {
			unless (exists($old_include{$_})) {
				# new module
				$self->debug("Adding new include: $_");
				$self->prep_include($_);
			}
			delete $old_include{$_};
		}

		foreach (keys %old_include) {
			$self->debug("Removing old include: $_");
			delete $self->{'handlers'}->{$_};
		}
	}
}

sub load_module {
	my $self   = shift;
	my $module = shift;

	if ($self->{'dynamic_loading'}) {
		require "Apache/Voodoo/Loader/Dynamic.pm";

		return Apache::Voodoo::Loader::Dynamic->new($self->{'base_package'}."::$module");
	}
	else {
		require "Apache/Voodoo/Loader/Static.pm";

		my $obj = Apache::Voodoo::Loader::Static->new($self->{'base_package'}."::$module");
		if (ref($obj) eq "Apache::Voodoo::Zombie") {
			# doh! the module went boom
			$self->{'errors'}++;
		}

		return $obj;
	}
}

sub debug { 
	my $self = shift;
	return;
	return unless $self->{'debug'};

	if (ref($_[0])) {
		print STDERR Dumper(@_);
	}
	else {
		print STDERR join("\n",@_),"\n";
	}
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
