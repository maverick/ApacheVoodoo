package Apache::Voodoo::MP::V1;

use strict;
use warnings;

use Apache;
use Apache::Request;
use Apache::Constants qw(OK REDIRECT DECLINED FORBIDDEN SERVER_ERROR M_GET);

sub new {
	my $class = shift;
	my $self = {};

	warn("Mod_perl V1 API detected");

	bless $self,$class;
	return $self;
}

sub set_request {
	my $self = shift;
	$self->{'r'} = shift;
}

sub DECLINED     { return Apache::Constant::DECLINED;  }
sub FORBIDDEN    { return Apache::Constant::FORBIDDEN; }
sub OK           { return Apache::Constant::OK;        }
sub REDIRECT     { return Apache::Constant::REDIRECT;  }
sub SERVER_ERROR { return Apache::Constant::FORBIDDEN; }

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

sub redirect {
        my $self = shift;
        my $loc  = shift;
        my $internal = shift;

        my $r = $self->{'r'};
        if ($r->method eq "POST") {
                $r->method_number(Apache::Constant::M_GET);
                $r->method('GET');
                $r->headers_in->unset('Content-length');

                $r->header_out("Location" => $loc);
                $r->status(Apache::Constant::REDIRECT);
                $r->send_http_header;
                return Apache::Constant::REDIRECT;
        }
        elsif ($internal) {
                $r->internal_redirect($loc);
                return Apache::Constant::OK;
        }
        else {
                $r->header_out("Location" => $loc);
                return Apache::Constant::REDIRECT;
        }
}

sub parse_params {
	my $self       = shift;
	my $upload_max = shift;

	my $apr  = Apache::Request->new($self->{r}, POST_MAX => $upload_max);
	if ($apr->parse()) {
		return "File upload has returned the following error:\n".$apr->notes('error-notes');
   	}

	my %params;
	foreach ($apr->param) {
		my @value = $apr->param($_);
		$params{$_} = @value > 1 ? [@value] : $value[0];
   	}

   	my @uploads = $apr->upload;
   	if (@uploads) {
		$params{'__voodoo_file_upload__'} = @uploads > 1 ? [@uploads] : $uploads[0];
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
		$r = Apache->server;
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
