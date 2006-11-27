=pod ###########################################################################

=head1 NAME

Apache::Voodoo::MyConfig

=head1 SYNOPSIS

Installation specific settings for Apache Voodoo are stored here.  Do not edit this file
directly; use the supplied "voodoo-control" program instead.

=cut ###########################################################################
package Apache::Voodoo::MyConfig;

$CONFIG = {
  'SESSION_PATH' => '/data/apache/session',
  'INSTALL_PATH' => '/data/apache/sites',
  'TMPL_PATH' => 'html',
  'APACHE_UID' => 81,
  'PREFIX' => '/data/apache',
  'APACHE_GID' => 81,
  'UPDATES_PATH' => 'etc/updates',
  'CONF_PATH' => 'etc',
  'CONF_FILE' => 'etc/voodoo.conf',
  'CODE_PATH' => 'code'
}
;

1;

=pod ###########################################################################

=head1 AUTHOR

Maverick, /\/\averick@smurfbaneDOTorg

=head1 COPYRIGHT

Copyright (c) 2005 Steven Edwards.  All rights reserved.

You may use and distribute Voodoo under the terms described in the LICENSE
file include in this package or L<Apache::Voodoo::license>.  The summary is
it's a legalese version of the Artistic License :)

=cut ###########################################################################
