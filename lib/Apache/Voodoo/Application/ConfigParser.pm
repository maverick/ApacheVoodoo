=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Application::ConfigParser

=head1 VERSION

$Id: ConfigParser.pm 17944 2009-08-06 14:06:10Z medwards $

=cut ################################################################################
package Apache::Voodoo::Application::ConfigParser;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/trunk/Voodoo/Application/ConfigParser.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Apache::Voodoo::Constants;
use Config::General;
use File::Spec;
use Exception::Class::DBI;

sub new {
	my $class = shift;
   	my $self = {};

	bless $self, $class;

	$self->{'id'}        = shift;
	$self->{'constants'} = shift || Apache::Voodoo::Constants->new();

	$self->{'conf_mtime'} = 0;

	$self->{'config'}        = {};
	$self->{'models'}        = {};
	$self->{'views'}         = {};
	$self->{'controllers'}   = {};
	$self->{'includes'}      = {};
	$self->{'template_conf'} = {};

	if (defined($self->{'id'})) {
		$self->{'conf_file'} = File::Spec->catfile(
			$self->{constants}->install_path(),
			$self->{'id'},
			$self->{constants}->conf_file()
		);
	}
	else {
		die "ID is a requried parameter.";
	}

	return $self;
}

sub changed {
	my $self = shift;

	return $self->{'conf_mtime'} != (stat($self->{'conf_file'}))[9];
}

sub old_ns        { return $_[0]->{'old_ns'}        };
sub config        { return $_[0]->{'config'}        };
sub models        { return $_[0]->{'models'}        };
sub views         { return $_[0]->{'views'}         };
sub controllers   { return $_[0]->{'controllers'}   };
sub includes      { return $_[0]->{'includes'}      };
sub template_conf { return $_[0]->{'template_conf'} };
sub databases     { return $_[0]->{'dbs'}           };

sub parse {
	my $self = shift;

	my $conf = Config::General->new(
		'-ConfigFile' => $self->{'conf_file'},
		'-IncludeRelative' => 1,
		'-UseApacheInclude' => 1,
		'-IncludeAgain' => 1
	);

	my %conf = $conf->getall();

	$conf{'id'} = $self->{'id'};

	$conf{'base_package'} ||= $self->{'id'};

	# PCI says that sessions should expire after 15 minutes, this should be a sesable default
	$conf{'session_timeout'} ||= 900;

	$conf{'upload_size_max'} ||= 5242880;

	$conf{'cookie_name'} ||= uc($self->{'id'}). "_SID";

	$conf{'https_cookies'} = ($conf{'https_cookies'})?1:0;

	$conf{'template_opts'} ||= {};

	$conf{'template_dir'} = File::Spec->catfile(
		$self->{'constants'}->install_path(),
		$self->{'id'},
		$self->{'constants'}->tmpl_path()
	);

	$conf{'logout_target'} ||= "/index";

	if (defined($conf{'devel_mode'})) {
		if ($conf{'devel_mode'}) {
			$conf{'devel_mode'}      = 1;
			$conf{'dynamic_loading'} = 1;
			$conf{'halt_on_errors'}  = 0;
		}
		else {
			$conf{'devel_mode'}      = 0;
			$conf{'dynamic_loading'} = 0;
			$conf{'halt_on_errors'}  = 1;
		}
	}
	else {
		$conf{'devel_mode'}      = 0;
		$conf{'dynamic_loading'} = $conf{'dynamic_loading'} || 0;
		$conf{'halt_on_errors'}  = defined($conf{'halt_on_errors'})?$conf{'halt_on_errors'}:1;
	}

	if ($conf{'dynamic_loading'}) {
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
	else {
		$self->{'dbs'} = [];
	}

	$self->{'models'}   = $conf{'models'}   || {};
	$self->{'views'}    = $conf{'views'}    || {};
	$self->{'includes'} = $conf{'includes'} || {};

	if ($conf{'controllers'}) {
		$self->{'controllers'} = $conf{'controllers'};
		$self->{'old_ns'} = 0;
	}
	elsif ($conf{'modules'}) {
		$self->{'controllers'} = $conf{'modules'};
		$self->{'old_ns'} = 1;
	}
	else {
		$self->{'controllers'} = {};
	}

	delete $conf{'models'};
	delete $conf{'views'};
	delete $conf{'controllers'};
	delete $conf{'modules'};
	delete $conf{'includes'};

	$self->{'template_conf'} = $conf{'template_conf'} || {};
	delete $conf{'template_conf'};

	# make a dummy entry for default if it doesn't exists,
	# this saves an if(defined blah blah) on every page request.
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
		unless (scalar(@{$conf{'themes'}->{'theme'}})) {
			$self->{'errors'}++;
			warn "You must define at least one theme block\n";
		}
	}

	$self->{config} = \%conf;
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
