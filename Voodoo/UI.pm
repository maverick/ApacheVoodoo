=pod ###########################################################################
Factory that creates the requested form ui driver type.
=cut ###########################################################################
package Apache::Voodoo::Data::UI;

use strict;
use warnings;

sub new {
	my $class  = shift;
	my $config = shift;

	my $obj = "Apache::Voodoo::Data::UI::".$config->get_ui();
	my $file = $obj;

	$file =~ s/::/\//g;
	$file .= ".pm";

	require $file;
	return $obj->new($config);
}

1;
