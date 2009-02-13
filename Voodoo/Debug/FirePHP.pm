package FirePHP;
  
use strict;
use warnings;

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

	$self->{setHeader} = $options{'setHeader'};
	$self->{userAgent} = $options{'userAgent'};

	$self->{'messageIndex'} = 1;
	$self->{'objectFilters'} = [];
	$self->{'objectStack'} = [];
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
  
sub setObjectFilter {
	my $self   = shift;
	my $class  = shift;
	my $filter = shift;
	
    $self->{'objectFilters'}->{$class} = $filter;
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
  
sub trace { return $_[0]->fb($_[1], TRACE); } 
  
#
# Relies on having a callback setup in the constructor that returns the user agent
#
sub detectClientExtension {
	my $self = shift;
	my $useragent = $self->{'userAgent'}->();

	if ($useragent =~ /\sFirePHP\/([.\d]+)/ && $1 ge '0.0.6') {
		return 1;
	}
	else {
		return 0;
	}
}  
 
sub fb {
	my $self   = shift;
	my $Object = shift;
  
    unless (!$self->{'enabled'}) {
		return 0;
    }

#
# FIXME here
#

    if (headers_sent($filename, $linenum)) {
		throw $this->newException('Headers already sent in '.$filename.' on line '.$linenum.'. Cannot send log data to FirePHP. You must have Output Buffering enabled via ob_start() or output_buffering ini directive.');
    }
  
    $Type = null;
    $Label = null;
  
    if (func_num_args()==1) {
    } 
	else if(func_num_args()==2) {
		switch (func_get_arg(1)) {
			case self::LOG:
			case self::INFO:
			case self::WARN:
			case self::ERROR:
			case self::DUMP:
			case self::TRACE:
			case self::EXCEPTION:
			case self::TABLE:
			case self::GROUP_START:
			case self::GROUP_END:
				$Type = func_get_arg(1);
				break;
			default:
				$Label = func_get_arg(1);
				break;
		}
	}
	else if(func_num_args()==3) {
		$Type = func_get_arg(2);
		$Label = func_get_arg(1);
    }
	else {
		throw $this->newException('Wrong number of arguments to fb() function!');
	}
  
  
	if (!$this->detectClientExtension()) {
		return false;
	}
  
    $meta = array();
    $skipFinalObjectEncode = false;
  
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
	else if($Type==self::TRACE) {
      
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
			else if(isset($trace[$i]['class'])
				&& isset($trace[$i+1]['file'])
				&& $trace[$i]['class']=='FirePHP'
				&& substr($this->_standardizePath($trace[$i+1]['file']),-18,18)=='FirePHPCore/fb.php') {

					# Skip fb()
			}
			else if($trace[$i]['function']=='fb'
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
	else if($Type==self::TABLE) {
      
		if (isset($Object[0]) && is_string($Object[0])) {
			$Object[1] = $this->encodeTable($Object[1]);
		}
		else {
			$Object = $this->encodeTable($Object);
		}

		$skipFinalObjectEncode = true;
	}
	else {
		if($Type===null) {
			$Type = self::LOG;
		}
    }
    
	if ($this->options['includeLineNumbers']) {
		if(!isset($meta['file']) || !isset($meta['line'])) {

			$trace = debug_backtrace();
			for( $i=0 ; $trace && $i<sizeof($trace) ; $i++ ) {
	
				if(isset($trace[$i]['class'])
					&& isset($trace[$i]['file'])
					&& ($trace[$i]['class']=='FirePHP'
						|| $trace[$i]['class']=='FB')
					&& (substr($this->_standardizePath($trace[$i]['file']),-18,18)=='FirePHPCore/fb.php'
						|| substr($this->_standardizePath($trace[$i]['file']),-29,29)=='FirePHPCore/FirePHP.class.php')) {

					# Skip - FB::trace(), FB::send(), $firephp->trace(), $firephp->fb()
				}
				else if(isset($trace[$i]['class'])
					&& isset($trace[$i+1]['file'])
					&& $trace[$i]['class']=='FirePHP'
					&& substr($this->_standardizePath($trace[$i+1]['file']),-18,18)=='FirePHPCore/fb.php') {

					# Skip fb()
				}
				else if(isset($trace[$i]['file'])
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

	$this->setHeader('X-Wf-Protocol-1','http://meta.wildfirehq.org/Protocol/JsonStream/0.2');
	$this->setHeader('X-Wf-1-Plugin-1','http://meta.firephp.org/Wildfire/Plugin/FirePHP/Library-FirePHPCore/'.self::VERSION);
 
	$structure_index = 1;
	if ($Type==self::DUMP) {
		$structure_index = 2;
		$this->setHeader('X-Wf-1-Structure-2','http://meta.firephp.org/Wildfire/Structure/FirePHP/Dump/0.1');
	}
	else {
		$this->setHeader('X-Wf-1-Structure-1','http://meta.firephp.org/Wildfire/Structure/FirePHP/FirebugConsole/0.1');
	}
  
    if ($Type==self::DUMP) {
		$msg = '{"'.$Label.'":'.$this->jsonEncode($Object, $skipFinalObjectEncode).'}';
	}
	else {
		$msg_meta = array('Type'=>$Type);
		if ($Label!==null) {
			$msg_meta['Label'] = $Label;
		}
		if (isset($meta['file'])) {
			$msg_meta['File'] = $meta['file'];
		}
		if (isset($meta['line'])) {
			$msg_meta['Line'] = $meta['line'];
		}
		$msg = '['.$this->jsonEncode($msg_meta).','.$this->jsonEncode($Object, $skipFinalObjectEncode).']';
    }
    
    $parts = explode("\n",chunk_split($msg, 5000, "\n"));

    for ( $i=0 ; $i<count($parts) ; $i++) {
		$part = $parts[$i];
        if ($part) {
            
            if (count($parts)>2) {
				# Message needs to be split into multiple parts
				$this->setHeader('X-Wf-1-'.$structure_index.'-'.'1-'.$this->messageIndex,
					(($i==0)?strlen($msg):'')
					. '|' . $part . '|'
					. (($i<count($parts)-2)?'\\':''));
			}
			else {
				$this->setHeader('X-Wf-1-'.$structure_index.'-'.'1-'.$this->messageIndex,
					strlen($part) . '|' . $part . '|');
            }
            
            $this->messageIndex++;
            
            if ($this->messageIndex > 99999) {
				throw new Exception('Maximum number (99,999) of messages reached!');             
            }
        }
    }

  	$this->setHeader('X-Wf-1-Index',$this->messageIndex-1);

    return 1;
}
  
sub _standardizePath {
	my $p = $_[1];
	return $p =~ s/\\/\//g;
}
  
sub _escapeTrace {
	my $self  = shift;
	my $Trace = shift;

    unless (ref($Trace) eq "ARRAY") return $Trace;

	foreach my $row (@{$Trace}) {
		if (defined($row->{'file'})) {
			$row->{'file'} = $self->_escapeTraceFile($row->{'file'});
		}
		if (defined($row->{'args'})) {
			$row->{'args'} = $this->encodeObject($row->{'args'});
		}
	}

	return $Trace;    
}
  
sub _escapeTraceFile { return $_[1]; }

#
# The calling object must pass in a reference to a method which 
# can set the outgoing http header.
#
sub setHeader() {
	my $self  = shift;
	my $name  = shift;
	my $value = shift;

    $self->{setHeader}->($name,$value);
}

sub jsonEncode {
	my $self   = shift;
	my $object = shift;
	my $skipObjectEncode = (shift)?1:0;

    unless ($skipObjectEncode) {
		$Object = $self->encodeObject($Object);
    }
    
	#
	# FIXME call json object here
	#
	return json_encode($Object);
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
  
#
# FIXME here
#
  /**
   * Encodes an object including members with
   * protected and private visibility
   * 
   * @param Object $Object The object to be encoded
   * @param int $Depth The current traversal depth
   * @return array All members of the object
   */
  protected function encodeObject($Object, $ObjectDepth = 1, $ArrayDepth = 1)
  {
    $return = array();

    if (is_resource($Object)) {

      return '** '.(string)$Object.' **';

    } else    
	if (is_object($Object)) {

        if ($ObjectDepth > $this->options['maxObjectDepth']) {
          return '** Max Object Depth ('.$this->options['maxObjectDepth'].') **';
        }
        
        foreach ($this->objectStack as $refVal) {
            if ($refVal === $Object) {
                return '** Recursion ('.get_class($Object).') **';
            }
        }
        array_push($this->objectStack, $Object);
                
        $return['__className'] = $class = get_class($Object);

        $reflectionClass = new ReflectionClass($class);  
        $properties = array();
        foreach( $reflectionClass->getProperties() as $property) {
          $properties[$property->getName()] = $property;
        }
            
        $members = (array)$Object;
            
		foreach( $properties as $raw_name => $property ) {
          
			$name = $raw_name;
			if ($property->isStatic()) {
				$name = 'static:'.$name;
			}
			if ($property->isPublic()) {
				$name = 'public:'.$name;
			}
			else if($property->isPrivate()) {
				$name = 'private:'.$name;
				$raw_name = "\0".$class."\0".$raw_name;
			}
			else if ($property->isProtected()) {
				$name = 'protected:'.$name;
				$raw_name = "\0".'*'."\0".$raw_name;
			}
          
			if (!(isset($this->objectFilters[$class])
				&& is_array($this->objectFilters[$class])
				&& in_array($raw_name,$this->objectFilters[$class]))) {

				if (array_key_exists($raw_name,$members)
					&& !$property->isStatic()) {
				
					$return[$name] = $this->encodeObject($members[$raw_name], $ObjectDepth + 1, 1);      
				
				}
				else {
					if (method_exists($property,'setAccessible')) {
						$property->setAccessible(true);
						$return[$name] = $this->encodeObject($property->getValue($Object), $ObjectDepth + 1, 1);
					}
					else if($property->isPublic()) {
						$return[$name] = $this->encodeObject($property->getValue($Object), $ObjectDepth + 1, 1);
					}
					else {
						$return[$name] = '** Need PHP 5.3 to get value **';
					}
				}
			}
			else {
				$return[$name] = '** Excluded by Filter **';
			}
		}
        
        # Include all members that are not defined in the class
        # but exist in the object
        foreach( $members as $raw_name => $value ) {
			$name = $raw_name;
          
			if ($name{0} == "\0") {
				$parts = explode("\0", $name);
				$name = $parts[2];
			}
          
			if (!isset($properties[$name])) {
				$name = 'undeclared:'.$name;
              
				if (!(isset($this->objectFilters[$class])
					&& is_array($this->objectFilters[$class])
					&& in_array($raw_name,$this->objectFilters[$class]))) {
              
					$return[$name] = $this->encodeObject($value, $ObjectDepth + 1, 1);
				}
				else {
					$return[$name] = '** Excluded by Filter **';
				}
			}
		}
        
		array_pop($this->objectStack);
        
    }
	else if (is_array($Object)) {

		if ($ArrayDepth > $this->options['maxArrayDepth']) {
			return '** Max Array Depth ('.$this->options['maxArrayDepth'].') **';
		}
      
		foreach ($Object as $key => $val) {
          
          // Encoding the $GLOBALS PHP array causes an infinite loop
          // if the recursion is not reset here as it contains
          // a reference to itself. This is the only way I have come up
          // with to stop infinite recursion in this case.
          if($key=='GLOBALS'
             && is_array($val)
             && array_key_exists('GLOBALS',$val)) {
            $val['GLOBALS'] = '** Recursion (GLOBALS) **';
          }
          
          $return[$key] = $this->encodeObject($val, 1, $ArrayDepth + 1);
        }
    } else {
      if(self::is_utf8($Object)) {
        return $Object;
      } else {
        return utf8_encode($Object);
      }
    }
    return $return;
  }

  /**
   * Returns true if $string is valid UTF-8 and false otherwise.
   *
   * @param mixed $str String to be tested
   * @return boolean
   */
  protected static function is_utf8($str) {
    $c=0; $b=0;
    $bits=0;
    $len=strlen($str);
    for($i=0; $i<$len; $i++){
        $c=ord($str[$i]);
        if($c > 128){
            if(($c >= 254)) return false;
            elseif($c >= 252) $bits=6;
            elseif($c >= 248) $bits=5;
            elseif($c >= 240) $bits=4;
            elseif($c >= 224) $bits=3;
            elseif($c >= 192) $bits=2;
            else return false;
            if(($i+$bits) > $len) return false;
            while($bits > 1){
                $i++;
                $b=ord($str[$i]);
                if($b < 128 || $b > 191) return false;
                $bits--;
            }
        }
    }
    return true;
  } 
