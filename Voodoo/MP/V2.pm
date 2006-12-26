package Apache::Voodoo::MP::V2;

use strict;
use warnings;

require Apache2::Const;
require Apache2::RequestRec;
require Apache2::RequestIO;
require Apache2::Request;

Apache2::Const->import(-compile => qw(OK REDIRECT DECLINED FORBIDDEN SERVER_ERROR M_GET));

sub new {
	my $class = shift;
	my $self = {};

	warn("Mod_perl V2 API detected");

	bless $self,$class;
	return $self;
}

sub set_request {
	my $self = shift;
	$self->{'r'} = shift;
}

sub DECLINED     { return Apache2::Const::DECLINED();     }
sub FORBIDDEN    { return Apache2::Const::FORBIDDEN();    }
sub OK           { return Apache2::Const::OK();           }
sub REDIRECT     { return Apache2::Const::REDIRECT();     }
sub SERVER_ERROR { return Apache2::Const::SERVER_ERROR(); }

sub content_type   { shift()->{'r'}->content_type(@_); }
sub dir_config     { shift()->{'r'}->dir_config(@_); }
sub err_header_out { shift()->{'r'}->err_headers_out->add(@_); }
sub filename       { shift()->{'r'}->filename(); }
sub flush          { shift()->{'r'}->rflush(); }
sub header_in      { shift()->{'r'}->headers_in->{shift()}; }
sub header_out     { shift()->{'r'}->headers_out->add(@_); }
sub internal_redirect { shift()->{'r'}->internal_redirect(@_); }
sub print { shift()->{'r'}->print(@_); }
sub uri            { shift()->{'r'}->uri(); }
sub method         { shift()->{'r'}->method(@_); }

sub redirect {
	my $self = shift;
	my $loc  = shift;
	my $internal = shift;

	my $r = $self->{'r'};
	if ($r->method eq "POST") {
		$r->method_number(Apache2::Const::M_GET());
		$r->method('GET');
		$r->headers_in->unset('Content-length');

		$r->headers_out->add("Location" => $loc);
		$r->status(Apache2::Const::REDIRECT());
		$r->content_type;
		return Apache2::Const::REDIRECT();
	}
	elsif ($internal) {
		$r->internal_redirect($loc);
		return Apache2::Const::OK();
	}
	else {
		$r->headers_out->add("Location" => $loc);
		return Apache2::Const::REDIRECT();
	}
}

sub get_app_id { return $_[0]->{r}->dir_config("ID"); }

sub is_get { return ($_[0]->{r}->method eq "GET"); }

sub site_root { return $_[0]->{r}->dir_config("SiteRoot") || "/"; }

sub parse_params {
	my $self       = shift;
	my $upload_max = shift;

	my $apr  = Apache2::Request->new($self->{r}, POST_MAX => $upload_max);

# FIXME uploading has changed in apache2
#	if ($apr->parse()) {
#		return "File upload has returned the following error:\n"; # .$apr->notes('error-notes');
#  	}

	my %params;
	foreach ($apr->param) {
		my @value = $apr->param($_);
		$params{$_} = @value > 1 ? [@value] : $value[0];
   	}

# FIXME uploading has changed in apache2
#   	my @uploads = $apr->upload;
#   	if (@uploads) {
#		$params{'__voodoo_file_upload__'} = @uploads > 1 ? [@uploads] : $uploads[0];
#   	}

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
#		$r = Apache2->server;
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
