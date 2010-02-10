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
		Apache::Voodoo::Table
		Apache::Voodoo::Table::Probe
		Apache::Voodoo::Table::Probe::MySQL
		Apache::Voodoo::Test
		Apache::Voodoo::Validate
		Apache::Voodoo::Validate::Plugin
		Apache::Voodoo::Validate::bit
		Apache::Voodoo::Validate::date
		Apache::Voodoo::Validate::datetime
		Apache::Voodoo::Validate::signed_decimal
		Apache::Voodoo::Validate::signed_int
		Apache::Voodoo::Validate::text
		Apache::Voodoo::Validate::time
		Apache::Voodoo::Validate::unsigned_decimal
		Apache::Voodoo::Validate::unsigned_int
		Apache::Voodoo::Validate::varchar
		Apache::Voodoo::View
		Apache::Voodoo::View::HTML
	);

	# .pm => prerequsite
	%optional = (
		'Apache::Voodoo::MP::V1'          => 'Apache::Request',
		'Apache::Voodoo::MP::V2'          => 'Apache2::Request',
		'Apache::Voodoo::Debug::Log4perl' => 'Log::Log4perl',
		'Apache::Voodoo::Soap'            => 'SOAP::Lite'
	);
		
};

use Test::More tests => scalar @list + keys %optional;

foreach (@list) {
	use_ok($_);
}

foreach (keys %optional) {
	SKIP: {
		eval {
			$f = $optional{$_};
			$f =~ s/::/\//g;
			$f .= ".pm";
			require $f;
		};
		skip "$optional{$_} not installed", 1 if ($@);
		use_ok($_);
	};
}
