################################################################################
#
# Apache::Voodoo::MyConfig - Config settings for Apache::Voodoo
# 
# Installation specific settings for Apache Voodoo are stored here.  Do not 
# edit this file directly; use the supplied "voodoo-control" program instead.
#
################################################################################
package Apache::Voodoo::MyConfig;

$CONFIG = {
  'APACHE_GID' => 81,
  'APACHE_UID' => 81,
  'CODE_PATH' => 'code',
  'CONF_FILE' => 'etc/voodoo.conf',
  'CONF_PATH' => 'etc',
  'DEBUG_DBD' => [
    'dbi:SQLite:dbname=/tmp/apachevoodoo.db',
    '',
    ''
  ],
  'DEBUG_PATH' => '/debug',
  'INSTALL_PATH' => '/data/apache/sites',
  'PREFIX' => '/data/apache',
  'SESSION_PATH' => '/data/apache/session',
  'TMPL_PATH' => 'html',
  'UPDATES_PATH' => 'etc/updates'
}
;

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
