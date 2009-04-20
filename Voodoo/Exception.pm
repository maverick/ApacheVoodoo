=pod ###########################################################################
Exception class definitions for Apache Voodoo.
=cut ###########################################################################
package Apache::Voodoo::Exception;

$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/MP.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

#
# Setup exception classes.  The subclassing of the various DBI classes is taken from
# the example in the Exception::Class::DBI docs.
#
use Exception::Class::DBI;

use Exception::Class (
	'Apache::Voodoo::Exception',
	
	'Apache::Voodoo::Exception::RunTime' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Run time exception from perl'
	},
	'Apache::Voodoo::Exception::DBI' => {
		isa => ['Apache::Voodoo::Exception','Exception::Class::DBI'],
		fields => ['error','err','errstr','handle','retval','state']
	},
	'Apache::Voodoo::Exception::DBI::H' => {
		isa => ['Apache::Voodoo::Exception::DBI','Exception::Class::DBI::H'],
		fields => ['warn','active','kids','active_kids','compat_mode','inactive_destroy','trace_level','fetch_hash_key_name','chop_blanks','long_read_len','long_trunc_ok','taint']
	},
	'Apache::Voodoo::Exception::DBI::DRH' => {
		isa => ['Apache::Voodoo::Exception::DBI','Exception::Class::DBI::DRH']
	},
	'Apache::Voodoo::Exception::DBI::DBH' => {
		isa => ['Apache::Voodoo::Exception::DBI','Exception::Class::DBI::DBH'],
		fields => ['auto_commit','db_name','statement','row_cache_size']
	},
	'Apache::Voodoo::Exception::DBI::STH' => {
		isa => ['Apache::Voodoo::Exception::DBI','Exception::Class::DBI::STH'],
		fields => ['num_of_fields','num_of_params','field_names','type','precision','scale','nullable','cursor_name','param_values','statement','rows_in_cache']
	},
	'Apache::Voodoo::Exception::DBI::Unknown' => {
		isa => ['Apache::Voodoo::Exception::DBI','Exception::Class::DBI::Unknown']
	}
);

Apache::Voodoo::Exception->Trace(1);
Apache::Voodoo::Exception->NoRefs(0);

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
