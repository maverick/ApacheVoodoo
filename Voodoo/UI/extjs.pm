package Apache::Voodoo::Data::UI::extjs;

use strict;
use warnings;

use JSON;
use Data::Dumper;

sub new {
	my $class = shift;
	my $opts  = shift;

	my $self = {};

	$self->{json} = new JSON;
	$self->{json}->pretty(1);

	$self->{handlers} = {
		'DEFAULT'  => \&DEFAULT,
		'varchar'  => \&varchar,
		'combobox' => \&combobox,
	};

	bless $self,$class;

	if ($opts) {
		$self->set_config($opts);
	}

	return $self;
}

sub set_config {
	my $self = shift;

	$self->{config} = shift;
}

sub handle {
	my $self = shift;
	my $p    = shift;

	$self->{dbh} = $p->{dbh};

	my $columns = $self->{config}->{columns};
	my @columns;
	if (ref($columns) eq "ARRAY") {
		@columns = @{$columns};
	}
	else {
		@columns = map {
			$columns->{$_}->{'id'} = $_;
			$columns->{$_};
		}
		sort { 
			$columns->{$a}->{seq} <=> $columns->{$b}->{seq} || 
			$a cmp $b 
		} 
		keys %{$columns};
	}

	my @items;

	#
	# Add the hidden param that controls the let's us know it's the post
	#
	push(@items,{
		'xtype' => 'hidden',
		'name'  => 'cm',
		'value' => 'go'
	});

	foreach my $c (@columns) {
		next if ($c->{id} eq $self->{config}->{primary_key});

		unless (defined($c->{label})) {
			$c->{label} = $self->_label_gen($c->{id});
		}

		my $h = 'DEFAULT';
		if ($c->{references}) {
			$h = 'combobox';
		}
		elsif (defined($self->{handlers}->{$c->{type}})) {
			$h = $c->{type};
		}

		my $field = $self->{handlers}->{$h}->($self,$c);

		push(@items,$field) if $field;
	}

	my $form;
	$form->{frame} = $self->json_true;

	if ($self->{config}->{title}) {
		$form->{title} = $self->{config}->{title};
	}
	else {
		$form->{title} = $self->_label_gen($self->{config}->{table});
	}

	$form->{items} = \@items;

	return {form_config => $self->{json}->encode($form)};
}

sub DEFAULT() {
	my $self = shift;
	my $c = shift;

	return {
		'xtype' => "label",
		'text'  => Dumper $c,
	};
}

sub _label_gen {
	my $self = shift;
	my $l    = shift;

	$l =  lc($l);
	$l =~ s/_/ /g;
	$l =~ s/\b(.)/\U$1\E/g;

	return $l;
}

sub varchar() {
	my $self = shift;
	my $c = shift;

	my $f = {};
	if ($c->{'length'} > 0) {
		$f->{'xtype'}     = 'textfield';
		$f->{'maxLength'} = $c->{'length'};
	}
	else {
#		$f->{'xtype'}   = 'textarea';
#		$f->{'grow'}    = $self->json_true;
#		$f->{'width'}   = 640;
#		$f->{'growMax'} = 640;

		$f->{xtype}   = 'htmleditor';
		$f->{enableFont} = $self->json_false;
		$f->{enableFontSize} = $self->json_false;
		$f->{enableSourceEdit} = $self->json_false;
	}

	$f->{'name'}       = $c->{id};
	$f->{'fieldLabel'} = $c->{label};

	if ($c->{'required'}) {
		$f->{'minLength'}  = 1;
		$f->{'allowBlank'} = $self->json_false;
	}

	return $f;
}

sub combobox() {
	my $self = shift;
	my $c = shift;

	my $f = {};
	$f->{'xtype'} = 'combo';

	$f->{'hiddenName'} = $c->{id};
	$f->{'fieldLabel'} = $c->{label};

	$f->{'typeAhead'}      = $self->json_true;
	$f->{'forceSelection'} = $self->json_true;

	if ($c->{required}) {
		$f->{'allowBlank'} = $self->json_false;
	}

	my $ref = $c->{references};

	my $q = 'SELECT ' . $ref->{primary_key} . ",";
	if (ref($ref->{columns}) eq "ARRAY") {
		$q .= join(",",@{$ref->{columns}});
	}
	else {
		$q .= $ref->{columns};
	}

	$q .= " FROM ".$ref->{table};
	$q .= " ".$ref->{select_extra};

	my $res = $self->{dbh}->selectall_arrayref($q) || $self->db_error;	

	$f->{store} = $res;

	return $f;
}

1;
