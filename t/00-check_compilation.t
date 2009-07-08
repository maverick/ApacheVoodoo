BEGIN {
	@list = qw(
		Apache::Voodoo::Zombie
		Apache::Voodoo::Loader::Static
		Apache::Voodoo::Loader::Dynamic
		Apache::Voodoo::Engine
		Apache::Voodoo::Validate
		Apache::Voodoo::Application
		Apache::Voodoo::Session::Instance
		Apache::Voodoo::Session::File
		Apache::Voodoo::Session::MySQL
		Apache::Voodoo::Debug
		Apache::Voodoo::Install
		Apache::Voodoo::Soap
		Apache::Voodoo::Exception
		Apache::Voodoo::MP::Common
		Apache::Voodoo::Application::ConfigParser
		Apache::Voodoo::Session
		Apache::Voodoo::Handler
		Apache::Voodoo::MP
		Apache::Voodoo::View
		Apache::Voodoo::View::HTML
		Apache::Voodoo::View::HTML::Theme
		Apache::Voodoo::View::JSON
		Apache::Voodoo::Validate::URL
		Apache::Voodoo::Validate::Config
		Apache::Voodoo::Debug::base
		Apache::Voodoo::Debug::return_data
		Apache::Voodoo::Debug::Native
		Apache::Voodoo::Debug::Handler
		Apache::Voodoo::Debug::Native::SQLite
		Apache::Voodoo::Debug::Native::common
		Apache::Voodoo::Debug::request
		Apache::Voodoo::Debug::debug
		Apache::Voodoo::Debug::Log4perl
		Apache::Voodoo::Debug::profile
		Apache::Voodoo::Debug::session
		Apache::Voodoo::Debug::template_conf
		Apache::Voodoo::Debug::index
		Apache::Voodoo::Debug::parameters
		Apache::Voodoo::Debug::FirePHP
		Apache::Voodoo::Debug::Common
		Apache::Voodoo::Debug::Multiplex
		Apache::Voodoo::Loader
		Apache::Voodoo::Pager
		Apache::Voodoo::Constants
		Apache::Voodoo::Table
		Apache::Voodoo::Table::Probe
		Apache::Voodoo::Table::Probe::MySQL
		Apache::Voodoo::Install::Post
		Apache::Voodoo::Install::Updater
		Apache::Voodoo::Install::Pid
		Apache::Voodoo::Install::Config
		Apache::Voodoo::Install::Distribution
		Apache::Voodoo::MyConfig
		Apache::Voodoo
	);
};

use Test::More tests => scalar @list;

foreach (@list) {
	use_ok($_);
}

