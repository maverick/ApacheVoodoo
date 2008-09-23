BEGIN {
	@list = qw(
	Apache::Voodoo
	Apache::Voodoo::Application
	Apache::Voodoo::Config
	Apache::Voodoo::Constants
	Apache::Voodoo::Debug
	Apache::Voodoo::Debug::SQLite
	Apache::Voodoo::Debug::common
	Apache::Voodoo::Debug::index
	Apache::Voodoo::Debug::request
	Apache::Voodoo::DisplayError
	Apache::Voodoo::Driver
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
	Apache::Voodoo::Pager
	Apache::Voodoo::ParamValidate
	Apache::Voodoo::Session
	Apache::Voodoo::Session::File
	Apache::Voodoo::Session::Instance
	Apache::Voodoo::Session::MySQL
	Apache::Voodoo::Storage::Table
	Apache::Voodoo::Table
	Apache::Voodoo::Table::Probe
	Apache::Voodoo::Table::Probe::MySQL
	Apache::Voodoo::Template
	Apache::Voodoo::Theme
	Apache::Voodoo::UI
	Apache::Voodoo::UI::extjs
	Apache::Voodoo::ValidURL
	Apache::Voodoo::Zombie
	);
};

use Test::More tests => scalar @list;

foreach (@list) {
	use_ok($_);
}

