package Apache::Voodoo::Driver;

use strict;
use warnings;

use DBI;
use Apache::Voodoo::ServerConfig;
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

	$self->{serverconfig} = Apache::Voodoo::ServerConfig->new($self->{id},$conf);

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
		"template_conf" => $self->{'serverconfig'}->{'template_conf'},
		"themes"        => $self->{'serverconfig'}->{'themes'}
	};
}

sub _db_connect {
	my $self = shift;

	return if ($self->{'dbh'});

	foreach (@{$self->{'serverconfig'}->{'dbs'}}) {
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
