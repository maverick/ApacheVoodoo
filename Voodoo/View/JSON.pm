=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Template::JSON

=head1 VERSION

$Id$

=head1 SYNOPSIS


=cut ################################################################################
package Apache::Voodoo::View::JSON;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use JSON::DWIW;

use base("Apache::Voodoo::View");

sub init {
	my $self   = shift;
	my $config = shift;

	$self->content_type('application/javascript');

	$self->{json} = JSON::DWIW->new({
		'bad_char_policy' => 'convert',
		'pretty' => ($config->{dynamic_loading})?1:0
	});
}

sub params {
	my $self = shift;

	if (defined($_[0])) {
		$self->{data} = shift;
	}
} 

sub exception {

}

sub output {
	my $self = shift;

	return scalar($self->{json}->to_json($self->{data}));
}

sub finish {
	my $self = shift;

	$self->{data} = {};
}

1;

=pod ################################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE file 
include in this package or L<Apache::Voodoo::license>.  The summary is it's a 
legalese version of the Artistic License :)

=cut ################################################################################
