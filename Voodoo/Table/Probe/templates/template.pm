=pod ################################################################################

=head1 %%PACKAGE%%::%%TABLE%%

$Id: template.pm,v 1.2 2001/09/08 17:30:26 maverick Exp $

=head1 Autogenerated for Apache;;Voodoo::Table

=cut ################################################################################

package %%PACKAGE%%::%%TABLE%%;

$VERSION = '1.20';

use base ("Apache::Voodoo");
use strict;

use Apache::Voodoo::Table;

my $CONFIGURATION = %%CONFIGURATION%%;

sub init {
	my $self = shift;

	$self->{'vt'} = Apache::Voodoo::Table->new($CONFIGURATION);
}

sub add {
	my $self = shift;
	my $p    = shift;

	my $result = $self->{'vt'}->add($p);

	if ($result == 1) {
		return $self->redirect("%%TEMPLATE_URL%%list_%%TABLE%%");
	}
	else {
		return $result;
	}
}

sub edit {
	my $self = shift;
	my $p = shift;
	
	my $result = $self->{'vt'}->edit($p);

	if ($result == 1) {
		return $self->redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
	}
	else {
		return $result;
	}
}

sub view {
	my $self = shift;
	my $p = shift;

	my $result = $self->{'vt'}->view($p);

	return $result;
}


sub list {
	my $self = shift;
	my $p = shift;

	my $return = $self->{'vt'}->list($p);

	&_freeze_list_params($p);

	return $return;
}

sub delete {
	my $self = shift;
	my $p = shift;

	my $return = $self->{'vt'}->delete($p);

	if ($return == 1) {
		return $self->redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
	}
	else {
		return $return;
	}
}

sub enable {
	my $self = shift;
	my $p = shift;

	$self->{'vt'}->enable($p);

	return $self->redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
}

sub disable {
	my $self = shift;
	my $p = shift;

	$self->{'vt'}->disable($p);

	return $self->redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
}

sub _freeze_list_params {
	my $p = shift;

	my $params  = $p->{'params'};
	my $session = $p->{'session'};

	my $url_params = $self->mkurlparams({
                                               'limit'         => $params->{'limit'},
                                               'pattern'       => $params->{'pattern'},
                                               'count'         => $params->{'count'},
                                               'sort'          => $params->{'sort'},
                                               'showall'       => $params->{'showall'},
                                               'last_sort'     => $params->{'last_sort'},
                                               'desc'          => $params->{'desc'},
                                               'page'          => $params->{'page'}
                                              });

	$session->{'list_%%TABLE%%_params'} = $url_params;
}

sub _fetch_list_params {
	my $p = shift;
	return $p->{'session'}->{'list_%%TABLE%%_params'};
}

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
