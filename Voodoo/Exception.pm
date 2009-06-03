=pod ###########################################################################
Exception class definitions for Apache Voodoo.
=cut ###########################################################################
package Apache::Voodoo::Exception;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Exception::Class (
	'Apache::Voodoo::Exception',
	
	'Apache::Voodoo::Exception::Compilation' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Module compilation failed',
		fields => ['module']
	},
	'Apache::Voodoo::Exception::RunTime' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Run time exception from perl'
	},
	'Apache::Voodoo::Exception::RunTime::Thrown' => {
		isa => 'Apache::Voodoo::Exception::RunTime',
		description => 'Module threw an exception'
	},
	'Apache::Voodoo::Exception::RunTime::BadCommand' => {
		isa => 'Apache::Voodoo::Exception::RunTime',
		description => "Controller returned an unsupported command",
		fields => ['module', 'method', 'command']
	},
	'Apache::Voodoo::Exception::RunTime::BadReturn' => {
		isa => 'Apache::Voodoo::Exception::RunTime',
		description => "Controller didn't return a hash reference",
		fields => ['module', 'method', 'data']
	},
	'Apache::Voodoo::Exception::ParamParse' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Parameters failed to parse'
	},
	'Apache::Voodoo::Exception::DBIConnect' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Failed to connect to the database'
	},
	'Apache::Voodoo::Exception::Application' => {
		isa => 'Apache::Voodoo::Exception',
		description => 'Application Error'
	},
	'Apache::Voodoo::Exception::Application::SessionTimeout' => {
		isa => 'Apache::Voodoo::Exception::Application',
		description => "Controller redirected the request to another location",
		fields => ['target','message']
	},
	'Apache::Voodoo::Exception::Application::Redirect' => {
		isa => 'Apache::Voodoo::Exception::Application',
		description => "Controller redirected the request to another location",
		fields => ['target','message']
	},
	'Apache::Voodoo::Exception::Application::DisplayError' => {
		isa => 'Apache::Voodoo::Exception::Application',
		description => "Controller request the display of an error message",
		fields => ['target','message']
	},
	'Apache::Voodoo::Exception::Application::AccessDenied' => {
		isa => 'Apache::Voodoo::Exception::Application',
		description => "Access to the requested resource has been denied",
		fields => ['target','message']
	},
	'Apache::Voodoo::Exception::Application::RawData' => {
		isa => 'Apache::Voodoo::Exception::Application',
		description => "Controller returned a raw data stream",
		fields => ['headers','content_type','data']
	},
);

Apache::Voodoo::Exception::RunTime->Trace(1);
Apache::Voodoo::Exception::RunTime->NoRefs(0);

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
