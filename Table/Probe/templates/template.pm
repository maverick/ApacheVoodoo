=pod ################################################################################

=head1 %%PACKAGE%%::%%TABLE%%

$Id: template.pm,v 1.2 2001/09/08 17:30:26 maverick Exp $

Initial Coding: <FIXME>

=head1 Acymtech::Table::Voodoo Configuration

%%CONFIGURATION%%

=cut ################################################################################

package %%PACKAGE%%::%%TABLE%%;

use base ("Acymtech::page_base");
use strict;

use Acymtech::Table::Voodoo;

my $CONFIGURATION = %%CONFIGURATION%%;

sub init {
	my $self = shift;

	$self->{'tu'} = Acymtech::Table::Voodoo->new($CONFIGURATION);
}

sub add {
	my $self = shift;
	my $p    = shift;

	my $result = $self->{'tu'}->add($p);

	if ($result == 1) {
		return redirect("%%TEMPLATE_URL%%list_%%TABLE%%");
	}
	else {
		return $result;
	}
}

sub edit {
	my $self = shift;
	my $p = shift;
	
	my $result = $self->{'tu'}->edit($p);

	if ($result == 1) {
		return redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
	}
	else {
		return $result;
	}
}

sub view {
	my $self = shift;
	my $p = shift;

	my $result = $self->{'tu'}->view($p);

	return $result;
}


sub list {
	my $self = shift;
	my $p = shift;

	my $return = $self->{'tu'}->list($p);

	&_freeze_list_params($p);

	return $return;
}

sub delete {
	my $self = shift;
	my $p = shift;

	my $return = $self->{'tu'}->delete($p);

	if ($return == 1) {
		return redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
	}
	else {
		return $return;
	}
}

sub enable {
	my $self = shift;
	my $p = shift;

	$self->{'tu'}->enable($p);

	return redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
}

sub disable {
	my $self = shift;
	my $p = shift;

	$self->{'tu'}->disable($p);

	return redirect("%%TEMPLATE_URL%%list_%%TABLE%%?". &_fetch_list_params($p));
}

sub _freeze_list_params {
	my $p = shift;

	my $params  = $p->{'params'};
	my $session = $p->{'session'};

	my $url_params = Acymtech::Common::mkurlparams({
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
=head1 CVS Log

$Log: template.pm,v $
Revision 1.2  2001/09/08 17:30:26  maverick
*** empty log message ***

Revision 1.1  2001/08/15 17:57:41  maverick
Initial checking after making this part of the TLA project


=cut ################################################################################
