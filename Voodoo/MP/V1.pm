package Apache::Voodoo::MP::V1;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||0);

use strict;
use warnings;

use Apache;
use Apache::Constants qw(OK REDIRECT DECLINED FORBIDDEN SERVER_ERROR M_GET);

use Apache::Request;

sub new {
	my $class = shift;
	my $self = {};

	bless $self,$class;
	return $self;
}

sub set_request {
	my $self = shift;
	$self->{'r'} = shift;
}

sub declined     { return Apache::Constants::DECLINED;  }
sub forbidden    { return Apache::Constants::FORBIDDEN; }
sub ok           { return Apache::Constants::OK;        }
sub server_error { return Apache::Constants::FORBIDDEN; }

sub content_type     { shift()->{'r'}->send_http_header(@_); }
sub dir_config       { shift()->{'r'}->dir_config(@_); }
sub err_header_out   { shift()->{'r'}->err_header_out(@_); }
sub filename         { shift()->{'r'}->filename(); }
sub flush            { shift()->{'r'}->rflush(); }
sub header_in        { shift()->{'r'}->header_in(@_); }
sub header_out       { shift()->{'r'}->header_out(@_); }
sub method           { shift()->{'r'}->method(@_); }
sub print            { shift()->{'r'}->print(@_); }
sub uri              { shift()->{'r'}->uri(); }

sub is_get     { return $_[0]->{r}->method eq "GET"; }
sub get_app_id { return $_[0]->{r}->dir_config("ID"); }
sub site_root  { return $_[0]->{r}->dir_config("SiteRoot") || "/"; }

sub if_modified_since {
	my $self  = shift;
	my $mtime = shift;

	$self->{r}->update_mtime($mtime);
	$self->{r}->set_last_modified;
	return $self->{r}->meets_conditions;
}

sub redirect {
        my $self = shift;
        my $loc  = shift;
        my $internal = shift;

        my $r = $self->{'r'};
        if ($r->method eq "POST") {
                $r->method_number(Apache::Constants::M_GET);
                $r->method('GET');
                $r->headers_in->unset('Content-length');

                $r->header_out("Location" => $loc);
                $r->status(Apache::Constants::REDIRECT);
                $r->send_http_header;
                return Apache::Constants::REDIRECT;
        }
        elsif ($internal) {
                $r->internal_redirect($loc);
                return Apache::Constants::OK;
        }
        else {
                $r->header_out("Location" => $loc);
                return Apache::Constants::REDIRECT;
        }
}

sub parse_params {
	my $self       = shift;
	my $upload_max = shift;

	my %params;

	my $apr  = Apache::Request->new($self->{r}, POST_MAX => $upload_max);

	foreach ($apr->param) {
		my @value = $apr->param($_);
		$params{$_} = @value > 1 ? [@value] : $value[0];
   	}

	# make sure our internal special params don't show up in the parameter list.
	delete $params{'__voodoo_file_upload__'};
	delete $params{'__voodoo_upload_error__'};

	if ($apr->parse()) {
		$params{'__voodoo_upload_error__'} = $apr->notes('error-notes');
   	}
	else {
		my @uploads = $apr->upload;
		if (@uploads) {
			$params{'__voodoo_file_upload__'} = @uploads > 1 ? [@uploads] : $uploads[0];
		}
	}

   	return \%params;
}



sub warn  { shift()->_log('warn',@_);  }
sub error { shift()->_log('error',@_); }

sub _log {
	my $self  = shift;
	my $level = shift;

	my $r;
	if (defined($self->{r})) {
		$r = $self->{r};
	}
	else {
		# $r = Apache->server;
	}

	if (defined($r)) {
		foreach (@_) {
			if (ref($_)) {
				$r->log->$level(Dumper $_);
			}
			else {
				$r->log->$level($_);
			}
		}
	}
	else {
		# Neither request nor server are present.  Fall back to
		# ye olde STDERR
		foreach (@_) {
			if (ref($_)) {
				print STDERR Dumper $_,"\n";
			}
			else {
				print STDERR $_,"\n";
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
