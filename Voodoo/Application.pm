=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Application

=head1 VERSION

$Id$

=head1 SYNOPSIS

This modules is used internally by Voodoo for application setup and module loading/reloading.

=cut ################################################################################
package Apache::Voodoo::Application;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Config::General;

use Apache::Voodoo::Constants;
use Apache::Voodoo::Template;
use Apache::Voodoo::Session;

use Data::Dumper;

sub new {
	my $class = shift;
   	my $self = {};

	bless $self, $class;

	$self->{'id'}        = shift;
	$self->{'constants'} = shift || Apache::Voodoo::Constants->new();

	if (defined($self->{'id'})) {
		$self->{'conf_file'} = File::Spec->catfile(
			$self->{constants}->install_path(),
			$self->{'id'},
			$self->{constants}->conf_file()
		);

		$self->load_config();
	}
	else {
		$self->{'errors'} = "ID and configuration file paths are requried parameters";
	}

	return $self;
}

sub setup {
	my $self = shift;

	# get the list of modules we're going to use
	foreach (keys %{$self->{'modules'}}) {
		$self->prep_module($_);
	}

	foreach (keys %{$self->{'includes'}}) {
		$self->prep_include($_);
	}

	$self->prep_template_engine();

	unless($self->{'dynamic_loading'}) {
		delete $self->{'modules'};
		delete $self->{'includes'};
	}
}

sub load_config {
	my $self = shift;

	my $conf = Config::General->new(
		'-ConfigFile' => $self->{'conf_file'},
		'-IncludeRelative' => 1,
		'-UseApacheInclude' => 1
	);

	my %conf = $conf->getall();

	$self->{'base_package'} = $conf{'base_package'} || $self->{'id'};


	$self->{'session_timeout'} = $conf{'session_timeout'} || 0;
	$self->{'upload_size_max'} = $conf{'upload_size_max'} || 5242880;
	$self->{'shared_cache'}    = $conf{'shared_cache'}    || 0;
	$self->{'ipc_max_size'}    = $conf{'ipc_max_size'}    || 0;

	$self->{'cookie_name'}   = $conf{'cookie_name'}     || uc($self->{'id'}). "_SID";
	$self->{'https_cookies'} = ($conf{'https_cookies'})?1:0;

	$self->{'template_conf'} = $conf{'template_conf'} || {};
	$self->{'template_opts'} = $conf{'template_opts'} || {};

	$self->{'logout_target'} = $conf{'logout_target'} || "/index";

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
		$self->{'conf_mtime'}  = (stat($self->{'conf_file'}))[9];
	}

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

	if (defined($conf{'session_table'})) {
		if ($self->{'dbs'}) {
			$self->{'session_handler'} = Apache::Voodoo::Session->new('MySQL',$conf{'session_table'});
		}
		else {
			print STDERR "You have sessions configured to be stored in the database but no database configuration.\n";
			$self->{'errors'}++;
		}
	}
	elsif (defined($conf{'session_dir'})) {
		$self->{'session_handler'} = Apache::Voodoo::Session->new('File',$conf{'session_dir'});
	}
	else {
		print STDERR "You do not have a session storage mechanism defined.\n";
		$self->{'errors'}++;
	}


	$self->{'modules'}  = $conf{'modules'}  || {};
	$self->{'includes'} = $conf{'includes'} || {};

	# make a dummy entry for default if it doesn't exists.
	# save an if(defined blah blah) on every page request.
	unless (defined($self->{'template_conf'}->{'default'})) {
		$self->{'template_conf'}->{'default'} = {};
	}

	# merge in the default block to each of the others now so that we don't have to
	# do it at page request time.
	foreach my $key (grep {$_ ne 'default'} keys %{$self->{'template_conf'}}) {
		$self->{'template_conf'}->{$key} = { 
			%{$self->{'template_conf'}->{'default'}},
			%{$self->{'template_conf'}->{$key}}
		};
	}

	#
	# Theme support
	#
	if (defined($conf{'themes'}) && $conf{'themes'}->{'use_themes'} == 1) {
		$self->{'use_themes'} = 1;
		$self->{'themes'}->{'__default__'} = $conf{'themes'}->{'default'};
		$self->{'themes'}->{'__userset__'} = $conf{'themes'}->{'user_can_choose'};
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

sub prep_template_engine { 
	my $self = shift;

	$self->{'template_engine'} = Apache::Voodoo::Template->new({
		template_dir  => File::Spec->catfile(
			$self->{'constants'}->install_path(),
			$self->{'id'},
			$self->{'constants'}->tmpl_path()
		),
		template_opts => $self->{'template_opts'}
	});
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

		$self->prep_template_engine();
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
