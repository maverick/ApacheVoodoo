package Apache::Voodoo::Driver;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]);

use strict;
use warnings;

use DBI;
use Apache::Voodoo::Application;
use Apache::Voodoo::Constants;

sub new {
	my $class = shift;
	my $self = {};

	bless $self,$class;

	$self->{id} = shift;

	$self->{constants} = Apache::Voodoo::Constants->new();
	
	my $conf = join("/",
		$self->{constants}->install_path(),
		$self->{id},
		$self->{constants}->conf_file()
	);

	$self->{application} = Apache::Voodoo::Application->new($self->{id},$conf);

	return $self;
}

sub dbh {
	my $self = shift;

	$self->_db_connect();

	return $self->{dbh};
}

sub make_call_hash {
	my $self = shift;

	return {
		"dbh"           => $self->dbh(),
		"document_root" => join('/',$self->{constants}->install_path(),$self->{id},$self->{constants}->tmpl_path()),
		"params"        => {},
		"session"       => {},
		"template_conf" => $self->{'application'}->{'template_conf'},
		"themes"        => $self->{'application'}->{'themes'}
	};
}

sub _db_connect {
	my $self = shift;

	return if ($self->{'dbh'});

	foreach (@{$self->{'application'}->{'dbs'}}) {
		$self->{'dbh'} = DBI->connect(@{$_});
		last if $self->{'dbh'};
			
		print STDERR "========================================================\n";
		print STDERR "DB CONNECT FAILED\n";
		print STDERR "$DBI::errstr\n";
		print STDERR "========================================================\n";
	}
}

sub DESTROY {
	my $self = shift;

	if (defined($self->{dbh})) {
		$self->{dbh}->disconnect;
	}
}

1;
