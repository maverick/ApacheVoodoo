=pod #####################################################################################

=head1 Apache::Voodoo::Theme

$Id$

=head1 Initial Coding: Maverick

This implements a post_include module that handles all the theme processing.

( And is going to be removed since you can do this sort of thing in CSS much better)

=cut ################################################################################

package Apache::Voodoo::Theme;

$VERSION = '1.11';

use strict;

use Data::Dumper;
use Config::General;
use IPC::SharedCache;
use HTML::Template;

use base("Apache::Voodoo");

sub handle {
	my $self = shift;
	my $p    = shift;

	my $themes = $p->{'themes'};

	my $chosen_theme = $self->choose_theme($p);

	my $return;

	# URL relative
	$return->{'THEME_DIR'} = $themes->{$chosen_theme};
	
	# FILE system relative
	my $theme_dir = $p->{'document_root'}."/".$themes->{$chosen_theme};

	my %cache;
	tie(%cache, 'IPC::SharedCache', ipc_key => 'VTHM', load_callback => \&load_cache, validate_callback => \&validate_cache);

	my $conf = $cache{"$theme_dir/theme.conf"};

	# find which style section this page is under
	my $style = $conf->{'pages'}->{$p->{'uri'}}->{'__style__'};
	$self->{'skeleton'} = $themes->{$chosen_theme}."/";

	unless (defined($style)) {
		# not listed.  no theme for you!

		# assume default skeleton.
		$self->{'skeleton'} .= "skeleton";
		return $return;
	}

	$self->{'skeleton'} .= $conf->{'style'}->{$style}->{'skeleton'} || 'skeleton';

	if (defined($conf->{'style'}->{$style}->{'includes'})) {
		while (my ($k,$v) = each %{$conf->{'style'}->{$style}->{'includes'}}) {
			my $template = HTML::Template->new('filename'          => "$theme_dir/$v.tmpl",
			                                   'shared_cache'      => 1,
			                                   'die_on_bad_params' => 0
			                                  );
			$template->param($conf->{'pages'}->{$p->{'uri'}});

			$return->{$k} = $template->output();
		}
	}
	else {
		while (my ($k,$v) = each %{$conf->{'pages'}->{$p->{'uri'}}}) {
			$return->{$k} = $v;
		}
	}

	return $return;
}

sub choose_theme {
	my $self = shift;
	my $p    = shift;

	my $session = $p->{'session'};
	my $themes  = $p->{'themes'};

	# check for an override of what's in the template conf file.
	my $sys_override = $p->{'document_root'}."/.theme_conf";

	my $chosen_theme = $themes->{'__default__'};

	if (-e $sys_override && -s $sys_override) {
		my $mtime = (stat($sys_override))[9];

		if ($self->{'sys_theme'}->{'mtime'} ne $mtime) {
			unless(open(T,$sys_override)) {
				return $self->display_error("Can't open $sys_override: $!");
			}
			my $t = <T>;
			chomp($t);
			close(T);
			
			if ($t ne "__default__" && defined($themes->{$t})) {
				$chosen_theme = $t;
				$self->{'sys_theme'}->{'name'} = $t;
			}

			$self->{'sys_theme'}->{'mtime'} = (stat($sys_override))[9];
		}
		else {
			$chosen_theme = $self->{'sys_theme'}->{'name'};
		}
	}

	if ($themes->{'user_can_choose'}) {
		my $user_theme = $session->{'user_theme'};
		if (defined($user_theme) && $user_theme ne "__default__") {
			if (defined($themes->{$user_theme})) {
				$self->{'chosen_theme'} = $user_theme;
			}
			else {
				delete ($session->{'user_theme'});
			}
		}
	}

	return $chosen_theme;
}

sub load_cache {
	my $file = shift;

	my $record;

	my $config_general = Config::General->new($file);
	my %conf = $config_general->getall;

	$record->{'mtime'} = (stat($file))[9];
	foreach my $style (keys %{$conf{'style'}}) {
		$record->{'style'}->{$style}->{'skeleton'} = $conf{'style'}->{$style}->{'skeleton'};
		$record->{'style'}->{$style}->{'includes'} = $conf{'style'}->{$style}->{'includes'};
		foreach my $page (keys %{$conf{'style'}->{$style}->{'pages'}}) {
			$record->{'pages'}->{$page} = $conf{'style'}->{$style}->{'pages'}->{$page};
			$record->{'pages'}->{$page}->{'__style__'} = $style;
		}
	}
		
	return $record;
}

sub validate_cache {
	my $file   = shift;
	my $record = shift;

	return ($record->{'mtime'} == (stat($file))[9]);
}

sub get_skeleton {
	return shift->{'skeleton'};
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
