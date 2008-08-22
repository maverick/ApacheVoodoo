=pod ###########################################################################
Factory that creates the requested form ui driver type.
=cut ###########################################################################
package Apache::Voodoo::Data::UI;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]);

use strict;
use warnings;

sub new {
	my $class  = shift;
	my $config = shift;

	my $obj = "Apache::Voodoo::Data::UI::".$config->ui();
	my $file = $obj;

	$file =~ s/::/\//g;
	$file .= ".pm";

	require $file;
	return $obj->new($config);
}

1;
