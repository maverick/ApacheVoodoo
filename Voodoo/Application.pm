=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Application

=head1 VERSION

$Id: Application.pm 12906 2009-02-20 23:08:10Z medwards $

=head1 SYNOPSIS

This modules is used internally by Voodoo for application setup and module loading/reloading.

=cut ################################################################################
package Apache::Voodoo::Application;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Apache::Voodoo::Constants;
use Apache::Voodoo::Session;
use Apache::Voodoo::Debug;

use Apache::Voodoo::Exception;
use Exception::Class::DBI;

use Apache::Voodoo::View::HtmlTemplate;

use Config::General;
use Data::Dumper;

sub new {
	my $class = shift;
   	my $self = {};

	bless $self, $class;

#	$self->{'debug'} = 1;

	$self->{'id'}        = shift;
	$self->{'constants'} = shift || Apache::Voodoo::Constants->new();

	$self->{'conf_mtime'} = 0;

	$self->{'mmodules'} = {};
	$self->{'vmodules'} = {};
	$self->{'cmodules'} = {};
	$self->{'includes'} = {};

	if (defined($self->{'id'})) {
		$self->{'conf_file'} = File::Spec->catfile(
			$self->{constants}->install_path(),
			$self->{'id'},
			$self->{constants}->conf_file()
		);

		$self->refresh(1);
	}
	else {
		$self->{'errors'} = "ID is a requried parameter.";
	}

	return $self;
}

sub _reload_modules {
	my $self = shift;
	my $ns   = shift;
	my $old  = shift;
	my $new  = shift;

	# check the new list of modules against the old list
	foreach (sort keys %{$new}) {
		unless (exists($old->{$_})) {
			# new module (wasn't in the old list).
			$self->debug("Adding new $ns module: $_");
			$self->_prep_module($ns,$_);
		}

		# still a valid module, so remove it from this list.
		delete $old->{$_};
	}

	# whatever is left in old are ones that weren't in the new list.
	foreach (keys %{$old}) {
		$self->debug("Removing old module: $_");
		$_ =~ s/::/\//g;
		delete $self->{'controllers'}->{$_};
	}
}

sub refresh {
	my $self    = shift;
	my $initial = shift;

	# Do nothing if this isn't the initial load, and we're not doing dynamic loading
	unless ($initial || $self->{'dynamic_loading'}) {
		return;
	}

	# check to see if we need to refresh the config.
	if ($self->{'conf_mtime'} != (stat($self->{'conf_file'}))[9]) {
		$self->debug("loading $self->{'conf_file'}");

		my %old_m = %{$self->{'mmodules'}};
		my %old_v = %{$self->{'vmodules'}};
		my %old_c = %{$self->{'cmodules'}};
		my %old_i = %{$self->{'includes'}};

		$self->_load_config();

		$self->_reload_modules('m',\%old_m,$self->{'mmodules'});
		$self->_reload_modules('v',\%old_v,$self->{'vmodules'});
		$self->_reload_modules('c',\%old_i,$self->{'includes'});

		# now we do exactly the same thing for the includes
		foreach (sort keys %{$self->{'cmodules'}}) {
			unless (exists($old_c{$_})) {
				# new module
				$self->debug("Adding new module: $_");
				$self->_prep_page_module($_);
			}
			delete $old_c{$_};
		}

		foreach (keys %old_c) {
			$self->debug("Removing old module: $_");
			delete $self->{'controllers'}->{$_};
		}

		foreach (values %{$self->{'models'}}, 
		         values %{$self->{'views'}},
		         values %{$self->{'controllers'}} ) {

			eval {
				$_->init($self->{config});
			};
			if ($@) {
				warn "$@\n";
				$self->{'errors'}++;
			}
		}

		$self->_prep_template_engine();
	}

	unless($self->{'dynamic_loading'}) {
		delete $self->{'mmodules'};
		delete $self->{'vmodules'};
		delete $self->{'cmodules'};
		delete $self->{'includes'};
	}
}

sub _load_config {
	my $self = shift;

	my $conf = Config::General->new(
		'-ConfigFile' => $self->{'conf_file'},
		'-IncludeRelative' => 1,
		'-UseApacheInclude' => 1
	);

	my %conf = $conf->getall();

	$conf{id} = $self->{id};

	$self->{'base_package'} = $conf{'base_package'} || $self->{'id'};

	$self->{'session_timeout'} = $conf{'session_timeout'} || 0;
	$self->{'upload_size_max'} = $conf{'upload_size_max'} || 5242880;

	$self->{'cookie_name'}   = $conf{'cookie_name'}     || uc($self->{'id'}). "_SID";
	$self->{'https_cookies'} = ($conf{'https_cookies'})?1:0;

	$self->{'template_conf'} = $conf{'template_conf'} || {};
	$self->{'template_opts'} = $conf{'template_opts'} || {};

	$self->{'logout_target'} = $conf{'logout_target'} || "/index";

	if (defined($conf{'devel_mode'})) {
		if ($conf{'devel_mode'}) {
			$self->{'devel_mode'}      = 1;
			$self->{'dynamic_loading'} = 1;
			$self->{'halt_on_errors'}  = 0;
		}
		else {
			$self->{'devel_mode'}      = 0;
			$self->{'dynamic_loading'} = 0;
			$self->{'halt_on_errors'}  = 1;
		}
	}
	else {
		$self->{'devel_mode'}      = 0;
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
				unless (ref ($_->{'extra'}) eq "HASH") {
					$_->{'extra'} = {};
				}
				$_->{'extra'}->{PrintError}  = 0;
				$_->{'extra'}->{RaiseError}  = 0;
				$_->{'extra'}->{HandleError} = Exception::Class::DBI->handler;

				[ 
					$_->{'connect'},
					$_->{'username'},
					$_->{'password'},
					$_->{'extra'}
				]
			} @{$db} 
		];
	}

	eval {
		$self->{'session_handler'} = Apache::Voodoo::Session->new(\%conf);
	};
	if ($@) {
		warn "$@\n";
		$self->{'errors'}++;
	}

	eval {
		$self->{'debug_handler'} = Apache::Voodoo::Debug->new(\%conf);
	};
	if ($@) {
		warn "$@\n";
		$self->{'errors'}++;
	}

	$self->{'mmodules'} = $conf{'models'} || {};
	$self->{'vmodules'} = $conf{'views'}  || {};

	$self->{'cmodules'} = {};
	if ($conf{'controllers'}) {
		$self->{'cmodules'} = $conf{'controllers'};
		$self->{'old_ns'} = 0;
	}
	elsif ($conf{'modules'}) {
		$self->{'cmodules'} = $conf{'modules'};
		$self->{'old_ns'} = 1;
	}

	$self->{'includes'}  = $conf{'includes'} || {};

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
			warn "You must define at least one theme block\n";
		}
	}

	# remove pre/post includes from display error...if one of them had 
	# the error you'd have an infinite redirect loop :)
	$self->{'template_conf'}->{'display_error'}->{'pre_include'}  = "";
	$self->{'template_conf'}->{'display_error'}->{'post_include'} = "";
}

sub _prep_module {
	my $self   = shift;
	my $ns     = shift;
	my $module = shift;

	my $obj = $self->_load_module($ns,$module);

	my $n = ($ns eq "m")?"models":
	        ($ns eq "v")?"views":"controllers";

	$self->{$ns}->{$module} = $obj;
}

sub _prep_page_module {
	my $self   = shift;
	my $module = shift;

	my $obj = $self->_load_module('c',$module);
	$module =~ s/::/\//g;

	$self->{'controllers'}->{$module} = $obj;
}

sub _load_module {
	my $self   = shift;
	my $ns     = shift;
	my $module = shift;

	unless ($ns eq "c" and $self->{old_ns}) {
		$module = uc($ns)."::".$module;
	}

	$module = $self->{'base_package'}."::".$module;

	return $self->_load_module_abs($module);
}

sub _load_module_abs {
	my $self   = shift;
	my $module = shift;

	my $obj;
	if ($self->{'dynamic_loading'}) {
		require "Apache/Voodoo/Loader/Dynamic.pm";

		$obj = Apache::Voodoo::Loader::Dynamic->new($module);
	}
	else {
		require "Apache/Voodoo/Loader/Static.pm";

		$obj = Apache::Voodoo::Loader::Static->new($module);
		if (ref($obj) eq "Apache::Voodoo::Zombie") {
			# doh! the module went boom
			$self->{'errors'}++;
		}
	}

	return $obj;
}

sub _prep_template_engine { 
	my $self = shift;

	$self->{'template_engine'} = Apache::Voodoo::View::HtmlTemplate->new({
		template_dir  => File::Spec->catfile(
			$self->{'constants'}->install_path(),
			$self->{'id'},
			$self->{'constants'}->tmpl_path()
		),
		template_opts => $self->{'template_opts'},
		use_themes    => $self->{'use_themes'},
		themes        => $self->{'themes'},
		site_root     => $self->{'site_root'}
	});
}

sub map_uri {
	my $self = shift;
	my $uri  = shift;

	if (defined($self->{'controllers'}->{$uri})) {
		return [$uri,"handle"];
	}
	else {
		my $p='';
		my $m='';
		my $o='';
		($p,$m,$o) = ($uri =~ /^(.*?)([a-z]+)_(\w+)$/);
		return ["$p$o",$m];
	}
}

sub debug { 
	my $self = shift;

	return unless $self->{'debug'};

	if (ref($_[0])) {
		warn Dumper(@_);
	}
	else {
		warn join("\n",@_),"\n";
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
