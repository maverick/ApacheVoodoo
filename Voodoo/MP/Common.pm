package Apache::Voodoo::MP::Common;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Time::HiRes;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {};

	bless $self,$class;
	return $self;
}

sub set_request {
	my $self = shift;

	$self->{r} = shift;

	$self->{request_id} = Time::HiRes::time;

	delete $self->{'cookiejar'};
}

sub request_id { return $_[0]->{request_id}; }

sub dir_config { shift()->{r}->dir_config(@_); }
sub filename   { shift()->{r}->filename(); }
sub flush      { shift()->{r}->rflush(); }
sub method     { shift()->{r}->method(@_); }
sub print      { shift()->{r}->print(@_); }
sub uri        { shift()->{r}->uri(); }

sub is_get     { return ($_[0]->{r}->method eq "GET"); }
sub get_app_id { return $_[0]->{r}->dir_config("ID"); }
sub site_root  { return $_[0]->{r}->dir_config("SiteRoot") || "/"; }

sub if_modified_since {
	my $self  = shift;
	my $mtime = shift;

	$self->{r}->update_mtime($mtime);
	$self->{r}->set_last_modified;
	return $self->{r}->meets_conditions;
}

sub warn  { shift()->_log('warn',@_);  }
sub error { shift()->_log('error',@_); }

sub _log {
	my $self  = shift;
	my $level = shift;

	if (defined($self->{r})) {
		foreach (@_) {
			if (ref($_)) {
				$self->{r}->log->$level(Dumper $_);
			}
			else {
				$self->{r}->log->$level($_);
			}
		}
	}
	else {
		# Neither request nor server are present.  Fall back to
		# ye olde STDERR
		foreach (@_) {
			if (ref($_)) {
				CORE::warn(Dumper($_),"\n");
			}
			else {
				CORE::warn($_."\n");
			}
		}
	}
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
