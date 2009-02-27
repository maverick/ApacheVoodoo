package Apache::Voodoo::Debug::FirePHP;
  
$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Devel::StackTrace;
use JSON;

use constant {
	DEBUG     => 'LOG',
	INFO      => 'INFO',
	WARN      => 'WARN',
	ERROR     => 'ERROR',
	DUMP      => 'DUMP',
	TRACE     => 'TRACE',
	EXCEPTION => 'EXCEPTION',
	TABLE     => 'TABLE'
};

use constant GROUP_START => 'GROUP_START';
use constant GROUP_END   => 'GROUP_END';

use constant WF_VERSION    => '0.2.1';
use constant WF_PROTOCOL   => 'http://meta.wildfirehq.org/Protocol/JsonStream/0.2';
use constant WF_PLUGIN     => 'http://meta.firephp.org/Wildfire/Plugin/FirePHP/Library-FirePHPCore/'.WF_VERSION;
use constant WF_STRUCTURE1 => 'http://meta.firephp.org/Wildfire/Structure/FirePHP/FirebugConsole/0.1';
use constant WF_STRUCTURE2 => 'http://meta.firephp.org/Wildfire/Structure/FirePHP/Dump/0.1';
  
sub new {
	my $class = shift;
	my $id    = shift;
	my $conf  = shift;

  	my $self = {};
	bless $self,$class;

	$self->{json} = new JSON;
	$self->{json}->allow_nonref(1);
	$self->{json}->allow_blessed(1);
	$self->{json}->convert_blessed(1);
	$self->{json}->utf8(1);

	$self->{setHeader} = sub { return; };
	$self->{userAgent} = sub { return; };

	my @flags = qw(debug info warn error exception table trace);

	$self->{enabled} = 0;
	if ($conf eq "1" || (ref($conf) eq "HASH" && $conf->{all})) {
		$self->{conf}->{LOG}       = 1;
		$self->{conf}->{INFO}      = 1;
		$self->{conf}->{WARN}      = 1;
		$self->{conf}->{ERROR}     = 1;
		$self->{conf}->{DUMP}      = 1;
		$self->{conf}->{TRACE}     = 1;
		$self->{conf}->{EXCEPTION} = 1;
		$self->{conf}->{TABLE}     = 1;
		$self->{conf}->{GROUP_START} = 1;
		$self->{conf}->{GROUP_END}   = 1;

		$self->{enabled} = 1;
	}
	elsif (ref($conf) eq "HASH") {
		$self->{conf}->{LOG}       = 1 if $conf->{debug};
		$self->{conf}->{INFO}      = 1 if $conf->{info};
		$self->{conf}->{WARN}      = 1 if $conf->{warn};
		$self->{conf}->{ERROR}     = 1 if $conf->{error};
		$self->{conf}->{DUMP}      = 1 if $conf->{dump};
		$self->{conf}->{TRACE}     = 1 if $conf->{trace};
		$self->{conf}->{EXCEPTION} = 1 if $conf->{exception};
		$self->{conf}->{TABLE}     = 1 if $conf->{table};

		if (scalar keys %{$self->{'conf'}}) {
			$self->{enabled} = 1;
			$self->{conf}->{GROUP_START} = 1;
			$self->{conf}->{GROUP_END}   = 1;
		}
	}

  	return $self;
}

sub init {
	my $self = shift;

	$self->{mp} = shift;

	$self->{enabled} = 0;

	return unless $self->_detectClientExtension();

	$self->{enable} = $self->{conf};
	$self->{messageIndex} = 1;
}

sub shutdown { return; }

sub setProcessorUrl {
	my $self = shift;
	my $URL  = shift;

	$self->setHeader('X-FirePHP-ProcessorURL' => $URL);
}

sub setRendererUrl {
	my $self = shift;
	my $URL  = shift;

	$self->setHeader('X-FirePHP-RendererURL' => $URL);
}
  
sub debug     { return $_[0]->_fb($_[1], $_[2], DEBUG);     } 
sub info      { return $_[0]->_fb($_[1], $_[2], INFO);      } 
sub warn      { return $_[0]->_fb($_[1], $_[2], WARN);      } 
sub error     { return $_[0]->_fb($_[1], $_[2], ERROR);     } 
sub exception { return $_[0]->_fb($_[1], $_[2], EXCEPTION); } 
sub trace     { return $_[0]->_fb($_[1], undef, TRACE);     } 
sub table     { return $_[0]->_fb($_[1], $_[2], TABLE);     } 
  
sub _group    { return $_[0]->_fb($_[1], undef, GROUP_START); }
sub _groupEnd { return $_[0]->_fb(undef, undef, GROUP_END);   }
  
#
# At some point in the future we might push this info out 
# through FirePHP, but not right now.
#
sub mark          { return; }
sub return_data   { return; }
sub session_id    { return; }
sub url           { return; }
sub result        { return; }
sub params        { return; }
sub template_conf { return; }
sub session       { return; }

# This is here for API compliance.
# FirePHP has no finalize step
sub finalize { return (); }

#
# Relies on having a callback setup in the constructor that returns the user agent
#
sub _detectClientExtension {
	my $self = shift;

	my $useragent = $self->{mp}->header_in('User-Agent');

	if ($useragent =~ /\bFirePHP\/([.\d]+)/ && $self->_compareVersion($1,'0.0.6')) {
		return 1;
	}
	else {
		return 0;
	}
}  

sub _compareVersion {
	my $self   = shift;

	my @f = split(/\./,shift);
	my @s = split(/\./,shift);

	my $c = (scalar(@f) > scalar(@s))?scalar(@f):scalar(@s);

	for (my $i=0; $i < $c; $i++) {
		if ($f[$i] < $s[$i] || (!defined($f[$i]) && defined($s[$i]))) {
			return 0;
		}
		elsif ($f[$i] > $s[$i] || (defined($f[$i]) && !defined($s[$i]))) {
			return 1;
		}
	}
	return 1;
}
 
sub _fb {
	my $self = shift;

	my $Label  = shift;
	my $Object = shift;
	my $Type   = shift;
  
	return unless $self->{enable}->{$Type};

	unless (defined($Object) || $Type eq GROUP_START) {
		$Object = $Label;
		$Label = undef;
	}

	my %meta = ();
  
    if ($Type eq EXCEPTION || $Type eq TRACE) {
		my @trace = $self->_stack_trace(1);

		my $t = shift @trace;

		$meta{'File'} = $t->{class}.$t->{type}.$t->{function};
		$meta{'Line'} = $t->{line};

		$Object = {
			'Class'   => $t->{class},
			'Type'    => $t->{type},
			'Function'=> $t->{function},
			'Message' => $Object,
			'File'    => $t->{file},
			'Line'    => $t->{line},
			'Args'    => $t->{args},
			'Trace'   => \@trace
		};
    }
	else {
		my @trace = $self->_stack_trace(1);
		
		$meta{'File'} = $trace[0]->{class}.$trace[0]->{type}.$trace[0]->{function};
		$meta{'Line'} = $trace[0]->{line};
	}

	my $structure_index = 1;
	if ($self->{messageIndex} == 1) {
		$self->setHeader('X-Wf-Protocol-1',WF_PROTOCOL);
		$self->setHeader('X-Wf-1-Plugin-1',WF_PLUGIN);
 
		if ($Type eq DUMP) {
			$structure_index = 2;
			$self->setHeader('X-Wf-1-Structure-2',WF_STRUCTURE2);
		}
		else {
			$self->setHeader('X-Wf-1-Structure-1',WF_STRUCTURE1);
		}
	}
  
	my $msg;
	if ($Type eq DUMP) {
		$msg = '{"'.$Label.'":'.$self->jsonEncode($Object).'}';
	}
	else {
		$meta{'Type'}  = $Type;
		$meta{'Label'} = $Label;

		$msg = '['.$self->jsonEncode(\%meta).','.$self->jsonEncode($Object).']';
	}
    
	#
	# Ugh, this could be handled so much better.
	# oh well...this is how the php version does it.
	#
	$msg =~ s/(.{5000})/$1\n/g;
	my @parts = split(/\n/,$msg);
	my $c_parts = scalar(@parts);

	foreach (my $i=0; $i < $c_parts; $i++) {
		my $part = $parts[$i];
		if ($part) {
			if ($c_parts > 2) {
				# Message needs to be split into multiple parts
				$self->setHeader('X-Wf-1-'.$structure_index.'-'.'1-'.$self->{'messageIndex'},
					(($i==0)?length($msg):'')
					. '|' . $part . '|'
					. ($i<($c_parts-2)?'\\':''));
			}
			else {
				$self->setHeader('X-Wf-1-'.$structure_index.'-'.'1-'.$self->{'messageIndex'},
					length($part) . '|' . $part . '|');
			}
            
			$self->{'messageIndex'}++;
            
			if ($self->{'messageIndex'} > 99999) {
				#throw new Exception('Maximum number (99,999) of messages reached!');             
			}
		}
	}

  	$self->setHeader('X-Wf-1-Index',$self->{'messageIndex'}-1);

	return 1;
}
  
sub setHeader() {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	$self->{mp}->header_out($name,$value);
}

sub jsonEncode {
	my $self   = shift;
	my $Object = shift;

	return $self->{'json'}->encode($Object);
}
  
sub _stack_trace {
	my $self = shift;
	my $full = shift;

	my @trace;
	my $i = 1;

	my $st = Devel::StackTrace->new();
    while (my $frame = $st->frame($i++)) {
		last if ($frame->package =~ /^Apache::Voodoo::Handler/);
        next if ($frame->package =~ /^Apache::Voodoo/);
        next if ($frame->package =~ /(eval)/);

		my $f = {
			'class'    => $frame->package,
			'function' => $st->frame($i)->subroutine,
			'file'     => $frame->filename,
			'line'     => $frame->line,
		};
		$f->{'function'} =~ s/^$f->{'class'}:://;

		my @a = $st->frame($i)->args;

		# if the first item is a reference to same class, then this was a method call
		if (ref($a[0]) eq $f->{'class'}) {
			shift @a;
			$f->{'type'} = '->';
		}
		else {
			$f->{'type'} = '::';
		}

		push(@trace,$f);

		if ($full) {
			$f->{'args'} = \@a;
		}
		else {
			last;
		}
    }
	return @trace;
}

1;
