package Apache::Voodoo::Debug::FirePHP;
  
use strict;
use warnings;

use Carp;
use Data::Dumper;
use JSON;

use constant VERSION     => '0.2.1';
use constant LOG         => 'LOG';
use constant INFO        => 'INFO';
use constant WARN        => 'WARN';
use constant ERROR       => 'ERROR';
use constant DUMP        => 'DUMP';
use constant TRACE       => 'TRACE';
use constant EXCEPTION   => 'EXCEPTION';
use constant TABLE       => 'TABLE';
use constant GROUP_START => 'GROUP_START';
use constant GROUP_END   => 'GROUP_END';
  
sub new {
	my $class = shift;
	my %options = @_;

  	my $self = {};
	bless $self,$class;

	$self->{json} = new JSON;
	$self->{json}->allow_nonref(1);
	$self->{json}->utf8(1);

	$self->{setHeader} = $options{'setHeader'};
	$self->{userAgent} = $options{'userAgent'};

	$self->{'messageIndex'} = 1;
	$self->{'enabled'} = 1;

    $self->{'options'}->{'maxObjectDepth'} = 10;
    $self->{'options'}->{'maxArrayDepth'}  = 20;
    $self->{'options'}->{'useNativeJsonEncode'} = 1;
    $self->{'options'}->{'includeLineNumbers'}  = 1;

  	return $self;
}

sub setEnabled {
    $_[0]->{'enabled'} = ($_[1])?1:0;
}

sub getEnabled {
	return $_[0]->{'enabled'};
}
  
sub setOptions {
	my $self = shift;
	my %options = @_;

	foreach (keys %options) {
    	$self->{'options'}->{$_} = $options{$_};
	}
}
  
=pod
  /**
   * Register FirePHP as your error handler
   * 
   * Will throw exceptions for each php error.
   */
  public function registerErrorHandler()
  {
    //NOTE: The following errors will not be caught by this error handler:
    //      E_ERROR, E_PARSE, E_CORE_ERROR,
    //      E_CORE_WARNING, E_COMPILE_ERROR,
    //      E_COMPILE_WARNING, E_STRICT
    
    set_error_handler(array($this,'errorHandler'));     
  }

  /**
   * FirePHP's error handler
   * 
   * Throws exception for each php error that will occur.
   *
   * @param int $errno
   * @param string $errstr
   * @param string $errfile
   * @param int $errline
   * @param array $errcontext
   */
  public function errorHandler($errno, $errstr, $errfile, $errline, $errcontext)
  {
    // Don't throw exception if error reporting is switched off
    if (error_reporting() == 0) {
      return;
    }
    // Only throw exceptions for errors we are asking for
    if (error_reporting() & $errno) {
      throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
    }
  }
  
  /**
   * Register FirePHP as your exception handler
   */
  public function registerExceptionHandler()
  {
    set_exception_handler(array($this,'exceptionHandler'));     
  }
  
  /**
   * FirePHP's exception handler
   * 
   * Logs all exceptions to your firebug console and then stops the script.
   *
   * @param Exception $Exception
   * @throws Exception
   */
  function exceptionHandler($Exception) {
    $this->fb($Exception);
  }
  
  /**
   * Set custom processor url for FirePHP
   *
   * @param string $URL
   */    
=cut

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
  
sub group    { return $_[0]->fb(undef, $_[1], GROUP_START); }
sub groupEnd { return $_[0]->fb(undef, undef, GROUP_END);   }

sub log   { return $_[0]->fb($_[1], $_[2], LOG);   } 
sub info  { return $_[0]->fb($_[1], $_[2], INFO);  } 
sub warn  { return $_[0]->fb($_[1], $_[2], WARN);  } 
sub error { return $_[0]->fb($_[1], $_[2], ERROR); } 
sub dump  { return $_[0]->fb($_[1], $_[2], DUMP);  } 

sub table { return $_[0]->fb($_[2], $_[1], TABLE); } 
  
sub trace { return $_[0]->fb($_[1], undef, TRACE); } 
  
#
# Relies on having a callback setup in the constructor that returns the user agent
#
sub detectClientExtension {
	my $self = shift;
	my $useragent = $self->{'userAgent'}->();

	if ($useragent =~ /\bFirePHP\/([.\d]+)/ && $self->_compare_version($1,'0.0.6')) {
		return 1;
	}
	else {
		return 0;
	}
}  

sub _compare_version {
	my $self   = shift;

	my @f = split(/\./,shift);
	my @s = split(/\./,shift);

	my $c = (scalar(@f) > scalar(@s))?scalar(@f):scalar(@s);

	for (my $i=0; $i < $c; $i++) {
		if ($f[$i] < $s[$i] || (!defined($f[$i]) && defined($s[$i]))) {
			return 0;
		}
	}
	return 1;
}
 
sub fb {
	my $self = shift;
  
    unless ($self->{'enabled'}) {
		return 0;
    }

	$self->{'_headers'} = [];
  
	if (scalar(@_) != 1 && scalar(@_) != 3) {
		die 'Wrong number of arguments to fb() function!';
	}

	my $Object = shift;
    my $Label  = shift;
    my $Type   = shift;

	if (!$self->detectClientExtension()) {
		return 0;
	}
  
    my %meta = ();
    my $skipFinalObjectEncode = 0;
  
=cut
    if ($Object instanceof Exception) {

		$meta['file'] = $this->_escapeTraceFile($Object->getFile());
		$meta['line'] = $Object->getLine();
      
		$trace = $Object->getTrace();
		if ($Object instanceof ErrorException
			&& isset($trace[0]['function'])
			&& $trace[0]['function']=='errorHandler'
			&& isset($trace[0]['class'])
			&& $trace[0]['class']=='FirePHP') {
           
			$severity = false;
			switch($Object->getSeverity()) {
				case E_WARNING:           $severity = 'E_WARNING';           break;
				case E_NOTICE:            $severity = 'E_NOTICE';            break;
				case E_USER_ERROR:        $severity = 'E_USER_ERROR';        break;
				case E_USER_WARNING:      $severity = 'E_USER_WARNING';      break;
				case E_USER_NOTICE:       $severity = 'E_USER_NOTICE';       break;
				case E_STRICT:            $severity = 'E_STRICT';            break;
				case E_RECOVERABLE_ERROR: $severity = 'E_RECOVERABLE_ERROR'; break;
				case E_DEPRECATED:        $severity = 'E_DEPRECATED';        break;
				case E_USER_DEPRECATED:   $severity = 'E_USER_DEPRECATED';   break;
			}
           
        	$Object = array('Class'=>get_class($Object),
			                'Message'=>$severity.': '.$Object->getMessage(),
			                'File'=>$this->_escapeTraceFile($Object->getFile()),
			                'Line'=>$Object->getLine(),
			                'Type'=>'trigger',
			                'Trace'=>$this->_escapeTrace(array_splice($trace,2)));
			$skipFinalObjectEncode = true;
		}
		else {
			$Object = array('Class'=>get_class($Object),
							'Message'=>$Object->getMessage(),
							'File'=>$this->_escapeTraceFile($Object->getFile()),
							'Line'=>$Object->getLine(),
							'Type'=>'throw',
							'Trace'=>$this->_escapeTrace($trace));
			$skipFinalObjectEncode = true;
		}
		$Type = self::EXCEPTION;
    }
	if ($Type eq TRACE) {
      
		$trace = debug_backtrace();
		if (!$trace) return false;

		for ( $i=0 ; $i<sizeof($trace) ; $i++ ) {

			if (isset($trace[$i]['class'])
				&& isset($trace[$i]['file'])
				&& ($trace[$i]['class']=='FirePHP'
					|| $trace[$i]['class']=='FB')
				&& (substr($this->_standardizePath($trace[$i]['file']),-18,18)=='FirePHPCore/fb.php'
					|| substr($this->_standardizePath($trace[$i]['file']),-29,29)=='FirePHPCore/FirePHP.class.php')) {

					# Skip - FB::trace(), FB::send(), $firephp->trace(), $firephp->fb()
			}
			elsif(isset($trace[$i]['class'])
				&& isset($trace[$i+1]['file'])
				&& $trace[$i]['class']=='FirePHP'
				&& substr($this->_standardizePath($trace[$i+1]['file']),-18,18)=='FirePHPCore/fb.php') {

					# Skip fb()
			}
			elsif($trace[$i]['function']=='fb'
				|| $trace[$i]['function']=='trace'
				|| $trace[$i]['function']=='send') {

				$Object = array('Class'=>isset($trace[$i]['class'])?$trace[$i]['class']:'',
                          'Type'=>isset($trace[$i]['type'])?$trace[$i]['type']:'',
                          'Function'=>isset($trace[$i]['function'])?$trace[$i]['function']:'',
                          'Message'=>$trace[$i]['args'][0],
                          'File'=>isset($trace[$i]['file'])?$this->_escapeTraceFile($trace[$i]['file']):'',
                          'Line'=>isset($trace[$i]['line'])?$trace[$i]['line']:'',
                          'Args'=>isset($trace[$i]['args'])?$this->encodeObject($trace[$i]['args']):'',
                          'Trace'=>$this->_escapeTrace(array_splice($trace,$i+1)));

				$skipFinalObjectEncode = true;
				$meta['file'] = isset($trace[$i]['file'])?$this->_escapeTraceFile($trace[$i]['file']):'';
				$meta['line'] = isset($trace[$i]['line'])?$trace[$i]['line']:'';

				break;
			}
		}
	}
=cut
	if ($Type eq TABLE) {
      
		if (ref($Object) eq "ARRAY" && ref($Object->[0]) ne "ARRAY") {
			$Object->[1] = $self->encodeTable($Object->[1]);
		}
		else {
			$Object = $self->encodeTable($Object);
		}

		$skipFinalObjectEncode = 1;
	}
	elsif (!defined($Type)) {
		$Type = LOG;
    }
    
=pod
	if ($this->options['includeLineNumbers']) {
		if(!isset($meta['file']) || !isset($meta['line'])) {

			my $trace = debug_backtrace();
			for( $i=0 ; $trace && $i<sizeof($trace) ; $i++ ) {
	
				if(isset($trace[$i]['class'])
					&& isset($trace[$i]['file'])
					&& ($trace[$i]['class']=='FirePHP'
						|| $trace[$i]['class']=='FB')
					&& (substr($this->_standardizePath($trace[$i]['file']),-18,18)=='FirePHPCore/fb.php'
						|| substr($this->_standardizePath($trace[$i]['file']),-29,29)=='FirePHPCore/FirePHP.class.php')) {

					# Skip - FB::trace(), FB::send(), $firephp->trace(), $firephp->fb()
				}
				elsif(isset($trace[$i]['class'])
					&& isset($trace[$i+1]['file'])
					&& $trace[$i]['class']=='FirePHP'
					&& substr($this->_standardizePath($trace[$i+1]['file']),-18,18)=='FirePHPCore/fb.php') {

					# Skip fb()
				}
				elsif(isset($trace[$i]['file'])
					&& substr($this->_standardizePath($trace[$i]['file']),-18,18)=='FirePHPCore/fb.php') {

					# Skip FB::fb()
				}
				else {
					$meta['file'] = isset($trace[$i]['file'])?$this->_escapeTraceFile($trace[$i]['file']):'';
					$meta['line'] = isset($trace[$i]['line'])?$trace[$i]['line']:'';
					break;
				}
			}      
		}
	}
	else {
		unset($meta['file']);
		unset($meta['line']);
	}
=cut

	$self->setHeader('X-Wf-Protocol-1','http://meta.wildfirehq.org/Protocol/JsonStream/0.2');
	$self->setHeader('X-Wf-1-Plugin-1','http://meta.firephp.org/Wildfire/Plugin/FirePHP/Library-FirePHPCore/'.VERSION);
 
	my $structure_index = 1;
	if ($Type eq DUMP) {
		$structure_index = 2;
		$self->setHeader('X-Wf-1-Structure-2','http://meta.firephp.org/Wildfire/Structure/FirePHP/Dump/0.1');
	}
	else {
		$self->setHeader('X-Wf-1-Structure-1','http://meta.firephp.org/Wildfire/Structure/FirePHP/FirebugConsole/0.1');
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

	my $h = $self->{'_headers'};
	$self->{'_headers'} = [];
	return $h;
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

	push(@{$self->{'_headers'}},[$name,$value]);
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
			if (ref($Table->{$i}) eq "ARRAY") {
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

	return {key => $object};
	return Dumper($object);
}

1;
