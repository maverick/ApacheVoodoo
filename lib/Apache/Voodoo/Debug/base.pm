package Apache::Voodoo::Debug::base;

use base("Apache::Voodoo");
use strict;
use warnings;

use JSON::DWIW;

sub get_request_id {
    my $self = shift;
    my $dbh  = shift;
    my $id   = shift;

	unless ($id->{request_id} =~ /^\d+(\.\d*)?$/) {
		return "invalid request id";
	}

	unless ($id->{app_id} =~ /^[a-z]\w*$/i) {
		return "invalid application id";
	}

	unless ($id->{session_id} =~ /^[0-9a-z]+$/i) {
		return "invalid session id";
	}


    my $res = $dbh->selectcol_arrayref("
        SELECT
            id
        FROM
            request
        WHERE
            request_timestamp = ? AND
            application       = ? AND
			session_id        = ?",undef,
        $id->{request_id},
        $id->{app_id},
		$id->{session_id}) || $self->db_error();

	unless ($res->[0] > 0) {
		return "no such id";
	}

    return $res->[0];
}

sub json_true {
	return $JSON::DWIW->true;
}

sub json_false {
	return $JSON::DWIW->false;
}

sub json_data {
	my $self = shift;
	my $type = shift;
	my $data = shift;

	if (ref($data)) {
		my $json = JSON::DWIW->new({bad_char_policy => 'convert', pretty => 1});;
		$data = $json->to_json($data);
	}
	elsif ($data !~ /^\s*[\[\{\"]/) {
		$data = '"'.$data.'"';
	}

    return $self->raw_mode("text/plain",'{"key":"'.$type.'","value":'.$data.'}');
}

sub json_return {
	my $self = shift;
	my $data = shift;

	my $json = JSON::DWIW->new({bad_char_policy => 'convert', pretty => 1});;

	return $self->raw_mode('text/plain',$json->to_json($data));
}

sub json_error {
	my $self   = shift;
	my $errors = shift;

	my $return = {
		'success' => 'false',
		'errors'  => []
	};

	if (ref($errors) eq "HASH") {
		foreach my $key (keys %{$errors}) {
			push(@{$return->{errors}},{id => $key, msg => $errors->{$key}});
		}
	}
	else {
		push(@{$return->{errors}},{id => 'error', msg => $errors});
	}

	my $json = JSON::DWIW->new({bad_char_policy => 'convert', pretty => 1});;
	
	return $self->raw_mode('text/plain',$json->to_json($return));
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
