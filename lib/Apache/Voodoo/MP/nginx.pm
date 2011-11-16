package Apache::Voodoo::MP::nginx;

$VERSION = "3.0206";

use strict;
use warnings;

use nginx;

use base("Apache::Voodoo::MP::Common");

sub declined     { return DECLINED;     }
sub ok           { return OK;  }
sub unauthorized { return 401; }
sub forbidden    { return 403; }
sub not_found    { return 404; }
sub server_error { return 500; }


sub document_root  { shift()->{'r'}->variable('document_root'); }
sub content_type   { shift()->{'r'}->send_http_header(@_); }
sub err_header_out { shift()->{'r'}->header_out(@_);     }
sub header_in      { shift()->{'r'}->header_in(@_);      }
sub header_out     { shift()->{'r'}->header_out(@_);     }
sub method         { shift()->{'r'}->request_method(@_); }
sub dir_config     { shift()->{'r'}->variable(@_);       }

sub get_app_id{ 
	my $self = shift;

	my $id = $self->{'r'}->variable('document_root');
	$id =~ s/\/[^\/]+$//;
	$id =~ s/.*\///;

	return $id;
}

sub redirect {
	my $self = shift;
	my $loc  = shift;

#	if ($loc) {
#		my $r = $self->{'r'};
#		if ($r->method eq "POST") {
#			$r->method_number(Apache2::Const::M_GET);
#			$r->method('GET');
#			$r->headers_in->unset('Content-length');
#
#			$r->headers_out->add("Location" => $loc);
#			$r->status(Apache2::Const::REDIRECT);
#			$r->content_type;
#		}
#		else {
#			$r->headers_out->add("Location" => $loc);
#		}
#	}

	return 301;
}

sub parse_params {
	my $self       = shift;
	my $upload_max = shift;

=pod
	my $apr = Apache2::Request->new($self->{r}, POST_MAX => $upload_max*5);

	my %params;
	foreach ($apr->param) {
		my @value = $apr->param($_);
		$params{$_} = @value > 1 ? [@value] : $value[0];
	}

	# make sure our internal special params don't show up in the parameter list.
	delete $params{'__voodoo_file_upload__'};
	delete $params{'__voodoo_upload_error__'};

	my @uploads = $apr->upload;
	if ($#uploads == 0) {
		my $u = $apr->upload($uploads[0]);
		if ($u->size() > $upload_max) {
			$params{'__voodoo_upload_error__'} = "File size exceeds $upload_max bytes.";
		}
		else {
			$params{'__voodoo_file_upload__'} = $u;
		}
	}
	elsif ($#uploads > 0) {
		foreach (@uploads) {
			my $u = $apr->upload($_);
			if ($u->size() > $upload_max) {
				$params{'__voodoo_upload_error__'} = "File size exceeds $upload_max bytes.";
			}
			else {
				push(@{$params{'__voodoo_file_upload__'}},$u);
			}
		}
	}

	return \%params;
=cut
	return {};
}

sub set_cookie {
	my $self = shift;

	my $name    = shift;
	my $value   = shift;
	my $expires = shift;

	my $cookie = join(";",
		$value,
		"Expires=$expires",
		"Domain=".$self->{'r'}->variable('server_name'),
		"Path=/",
		"HttpOnly"
	);

	$self->{'r'}->variable("cookie_$name",$cookie);
}

sub get_cookie {
	my $self  = shift;
	my $cname = shift;

	return $self->{'r'}->variable("cookie_$cname");
}

sub register_cleanup {
	my $self = shift;
	my $obj  = shift;
	my $sub  = shift;
}

1;

################################################################################
# Copyright (c) 2005-2010 Steven Edwards (maverick@smurfbane.org).
# All rights reserved.
#
# You may use and distribute Apache::Voodoo under the terms described in the
# LICENSE file include in this package. The summary is it's a legalese version
# of the Artistic License :)
#
################################################################################
