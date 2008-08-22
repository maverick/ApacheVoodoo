#####################################################################################
##
##  NAME
##
## Apache::Voodoo::Table::Probe - factory object used to create a database specific
## probing object.
##
##  VERSION
##
## $Id$
##
#####################################################################################
package Apache::Voodoo::Table::Probe;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]);

use strict;
use warnings;

use DBI;

sub new {
	my $class = shift;
	my $dbh   = shift;

	# From the DBI docs.  This will give use the database server name
	my $db_type = $dbh->get_info(17);

	my $obj  = "Apache::Voodoo::Table::Probe::$db_type";
	my $file = "Apache/Voodoo/Table/Probe/$db_type.pm";

	eval {
		require $file;
	};
	if ($@) {
		die "$db_type isn't supported\n$@\n";
	}

	return $obj->new($dbh);
}

1;

#####################################################################################
##
## AUTHOR
##
## Maverick, /\/\averick@smurfbaneDOTorg
##
## COPYRIGHT
##
## Copyright (c) 2005 Steven Edwards.  All rights reserved.
##
## You may use and distribute Voodoo under the terms described in the LICENSE file include
## in this package or L<Apache::Voodoo::license>.  The summary is it's a legalese version
## of the Artistic License :)
##
######################################################################################
