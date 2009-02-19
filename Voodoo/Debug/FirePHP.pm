package Apache::Voodoo::Debug::FirePHP;
  
$VERSION = sprintf("%0.4f",('$HeadURL: http://svn.nasba.dev/Voodoo/core/Voodoo/Debug.pm $' =~ m!(\d+\.\d+)!)[0]||10);

use strict;
use warnings;

use Devel::StackTrace;
use JSON;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

use constant DEBUG     => 'LOG';
use constant INFO      => 'INFO';
use constant WARN      => 'WARN';
use constant ERROR     => 'ERROR';
use constant DUMP      => 'DUMP';
use constant TRACE     => 'TRACE';
use constant EXCEPTION => 'EXCEPTION';
use constant TABLE     => 'TABLE';

use constant GROUP_START => 'GROUP_START';
use constant GROUP_END   => 'GROUP_END';

use constant WF_VERSION    => '0.2.1';
use constant WF_PROTOCOL   => 'http://meta.wildfirehq.org/Protocol/JsonStream/0.2';
use constant WF_PLUGIN     => 'http://meta.firephp.org/Wildfire/Plugin/FirePHP/Library-FirePHPCore/'.WF_VERSION;
use constant WF_STRUCTURE1 => 'http://meta.firephp.org/Wildfire/Structure/FirePHP/FirebugConsole/0.1';
use constant WF_STRUCTURE2 => 'http://meta.firephp.org/Wildfire/Structure/FirePHP/Dump/0.1';
  
sub new {
	my $class = shift;
	my %options = @_;

  	my $self = {};
	bless $self,$class;

	$self->{json} = new JSON;
	$self->{json}->allow_nonref(1);
	$self->{json}->allow_blessed(1);
	$self->{json}->convert_blessed(1);
	$self->{json}->utf8(1);

	$self->{setHeader} = $options{'setHeader'};
	$self->{userAgent} = $options{'userAgent'};

	$self->{flags} = [ qw(debug info warn error exception table trace) ];

  	return $self;
}

sub init {
	my $self = shift;

	my $app_id     = shift;
	my $request_id = shift;
	my $debug      = shift;

	$self->{enabled} = 0;

	return unless $self->_detectClientExtension();

	if ($debug eq "1" || (ref($debug) eq "HASH" && $debug->{all})) {
		foreach (@{$self->{flags}}) {
			$self->{enable}->{$_} = 1;
		}
		$self->{enabled} = 1;
	}
	elsif (ref($debug) eq "HASH") {
		foreach (@{$self->{flags}}) {
			if ($debug->{$_}) {
				$self->{enable}->{$_} = 1;
				$self->{enabled} = 1;
			}
		}
	}

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
  
sub debug     { return $_[0]->fb($_[1], $_[2], DEBUG);     } 
sub info      { return $_[0]->fb($_[1], $_[2], INFO);      } 
sub warn      { return $_[0]->fb($_[1], $_[2], WARN);      } 
sub error     { return $_[0]->fb($_[1], $_[2], ERROR);     } 
sub exception { return $_[0]->fb($_[1], $_[2], EXCEPTION); } 
sub trace     { return $_[0]->fb($_[1], undef, TRACE);     } 
sub table     { return $_[0]->fb($_[1], $_[2], TABLE);     } 
  
sub _group    { return $_[0]->fb($_[1], undef, GROUP_START); }
sub _groupEnd { return $_[0]->fb(undef, undef, GROUP_END);   }
  
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

#
# Relies on having a callback setup in the constructor that returns the user agent
#
sub _detectClientExtension {
	my $self = shift;
	my $useragent = $self->{'userAgent'}->();

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
 
sub fb {
	my $self = shift;
  
	unless ($self->{'enabled'}) {
		return 0;
	}

	if (scalar(@_) != 1 && scalar(@_) != 3) {
		die 'Wrong number of arguments to fb() function!';
	}

	my $Label  = shift;
	my $Object = shift;
	my $Type   = shift;

	unless (defined($Object) || $Type eq GROUP_START) {
		$Object = $Label;
		$Label = undef;
	}

	my %meta = ();
  
    if ($Type eq Exception) {

		$Object = {
			'Class'   => undef,
			'Type'    => (0)?'trigger':'throw',
			'Message' => undef,
			'File'    => undef,
			'Line'    => undef,
			'Trace'   => []
			# 'Args'=> [],
			# 'Function'=>
		};

		$meta['file'] = undef;
		$meta['line'] = undef;

		$skipFinalObjectEncode = 1;
    }
	elsif ($Type eq TRACE) {

		$Object = {
			'Class'   => undef,
			'Type'    => undef,
			'Function'=> undef,
			'Message' => undef,
			'File'    => undef,
			'Line'    => undef,
			'Args' => [],
			'Trace'=> []
		};

		$meta['file'] = undef;
		$meta['line'] = undef;

		$skipFinalObjectEncode = 1;
	}
	elsif ($Type eq TABLE) {
		if (ref($Object) eq "ARRAY" && ref($Object->[0]) ne "ARRAY") {
			$Object->[1] = $self->encodeTable($Object->[1]);
		}
		else {
			$Object = $self->encodeTable($Object);
		}

		$skipFinalObjectEncode = 1;
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
		$msg = '{"'.$Label.'":'.$self->jsonEncode($Object, $skipFinalObjectEncode).'}';
	}
	else {
		my %msg_meta = ('Type' => $Type);
		if (defined($Label)) {
			$msg_meta{'Label'} = $Label;
		}
		if (defined($meta{'file'})) {
			$msg_meta{'File'} = $meta{'file'};
		}
		if (defined($meta{'line'})) {
			$msg_meta{'Line'} = $meta{'line'};
		}

		$msg = '['.$self->jsonEncode(\%msg_meta).','.$self->jsonEncode($Object, $skipFinalObjectEncode).']';
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
  
sub _standardizePath {
	my $p = $_[1];
	return $p =~ s/\\/\//g;
}
  
sub _escapeTrace {
	my $self  = shift;
	my $Trace = shift;

	return $Trace unless (ref($Trace) eq "ARRAY");

	foreach my $row (@{$Trace}) {
		if (defined($row->{'file'})) {
			$row->{'file'} = $self->_escapeTraceFile($row->{'file'});
		}
		if (defined($row->{'args'})) {
			$row->{'args'} = $self->encodeObject($row->{'args'});
		}
	}

	return $Trace;    
}
  
sub _escapeTraceFile { return $_[1]; }

sub setHeader() {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

	$self->{setHeader}->($name,$value);
}

sub jsonEncode {
	my $self   = shift;
	my $Object = shift;
	my $skipObjectEncode = (shift)?1:0;

#	unless ($skipObjectEncode) {
#		$Object = $self->encodeObject($Object);
#    }
#	print "$Object\n";

	return $self->{'json'}->encode($Object);
}
  
sub encodeTable {
	my $self  = shift;
	my $Table = shift;

	if (ref($Table) eq "ARRAY") {
		for (my $i=0; $i < $#{$Table}; $i++) {
			if (ref($Table->[$i]) eq "ARRAY") {
				for (my $j=0; $j < $#{$Table->[$i]}; $j++) {
					$Table->[$i]->[$j] = $self->encodeObject($Table->[$i]->[$j]);
				}
			}
		}
	}
	return $Table;
}
  
sub encodeObject {
	my $self = shift;
	my $object = shift;

	if (ref($object)) {
		return Dumper($object);
	}
	else {
		return $object;
	}
}

sub _stack_trace {
	my $self   = shift;
	my $detail = shift;

	my @trace;

	my $st = Devel::StackTrace->new();
    $st->next_frame;
    while (my $frame = $st->next_frame()) {
        next if ($frame->subroutine =~ /^Apache::Voodoo/);
        next if ($frame->subroutine =~ /(eval)/);

		if ($detail) {
			push(@trace, {
				'package'    => $frame->package,
            	'subroutine' => $frame->subroutine,
            	'line'       => $frame->line,
            	'args'       => [ $frame->args ]
        	});
		}
		else {
			push(@trace, {
				'package'    => $frame->package,
            	'subroutine' => $frame->subroutine,
            	'line'       => $frame->line,
            	'args'       => [ $frame->args ]
        	});
		}
    }
	return \@trace;
}

1;
