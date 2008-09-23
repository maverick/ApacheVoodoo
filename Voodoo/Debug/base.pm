package Apache::Voodoo::Debug::base;

use base("Apache::Voodoo");
use strict;
use warnings;

use JSON;

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
	return $JSON::true;
}

sub json_false {
	return $JSON::false;
}

sub json_return {
	my $self = shift;
	my $data = shift;

	my $json = new JSON;
	$json->pretty(1);

	return $self->raw_mode('text/plain',$json->encode($data));
}

sub json_success {
	my $self = shift;
	my $data = shift;

	$data->{'success'} = $self->json_true;
	$data->{'errors'}  = [];
	
	return $self->raw_mode('text/plain',to_json($data));
}

sub json_error {
	my $self   = shift;
	my $errors = shift;

	my $return = {
		'success' => 'false',
		'errors'  => []
	};

	foreach my $key (keys %{$errors}) {
		push(@{$return->{errors}},{id => $key, msg => $errors->{$key}});
	}
	
	return $self->raw_mode('text/plain',to_json($return));
}

sub json_redirect {
	my $self   = shift;
	my $target = shift;

	my $return = {
		'success'  => 'true',
		'redirect' => $target,
	};

	return $self->raw_mode('text/plain',to_json($return));
}


1;
