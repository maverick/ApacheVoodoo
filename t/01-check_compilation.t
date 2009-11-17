BEGIN {
	@list = qw(
		Apache::Voodoo
		Apache::Voodoo::Application
		Apache::Voodoo::Application::ConfigParser
		Apache::Voodoo::Constants
		Apache::Voodoo::Debug
		Apache::Voodoo::Debug::Common
		Apache::Voodoo::Debug::FirePHP
		Apache::Voodoo::Debug::Handler
		Apache::Voodoo::Debug::Log4perl
		Apache::Voodoo::Debug::Native
		Apache::Voodoo::Debug::Native::SQLite
		Apache::Voodoo::Debug::Native::common
		Apache::Voodoo::Debug::base
		Apache::Voodoo::Debug::debug
		Apache::Voodoo::Debug::index
		Apache::Voodoo::Debug::parameters
		Apache::Voodoo::Debug::profile
		Apache::Voodoo::Debug::request
		Apache::Voodoo::Debug::return_data
		Apache::Voodoo::Debug::session
		Apache::Voodoo::Debug::template_conf
		Apache::Voodoo::Engine
		Apache::Voodoo::Exception
		Apache::Voodoo::Handler
		Apache::Voodoo::Install
		Apache::Voodoo::Install::Config
		Apache::Voodoo::Install::Distribution
		Apache::Voodoo::Install::Pid
		Apache::Voodoo::Install::Post
		Apache::Voodoo::Install::Updater
		Apache::Voodoo::Loader
		Apache::Voodoo::Loader::Dynamic
		Apache::Voodoo::Loader::Static
		Apache::Voodoo::MP
		Apache::Voodoo::MP::Common
		Apache::Voodoo::Pager
		Apache::Voodoo::Session
		Apache::Voodoo::Session::File
		Apache::Voodoo::Session::Instance
		Apache::Voodoo::Session::MySQL
		Apache::Voodoo::Soap
		Apache::Voodoo::Table
		Apache::Voodoo::Validate
		Apache::Voodoo::Validate
		Apache::Voodoo::View
		Apache::Voodoo::View::HTML
		Apache::Voodoo::View::HTML::Theme
		Apache::Voodoo::View::JSON
		Apache::Voodoo::Zombie
	);
};

use Test::More tests => scalar @list;

foreach (@list) {
	use_ok($_);
}

