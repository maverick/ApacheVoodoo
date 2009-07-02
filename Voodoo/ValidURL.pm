package Apache::Voodoo::ValidURL;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

#
# I saw this code fragment somewhere ages ago, I can't remember where.
# So, I can't attribute it to the proper author.  sorry!
#
# I've stripped out everthing not pertaining to HTTP URLs.  That
# was the part I really needed.
#

use strict;
use warnings;

# Be paranoid about using grouping!
my $digits         =  '(?:\d+)';
my $dot            =  '\.';
my $qm             =  '\?';
my $hex            =  '[a-fA-F\d]';
my $alpha          =  '[a-zA-Z]';     # No, no locale.
my $alphas         =  "(?:${alpha}+)";
my $alphanum       =  '[a-zA-Z\d]';   # Letter or digit.
my $xalphanum      =  "(?:${alphanum}|%(?:3\\d|[46]$hex|[57][Aa\\d]))";
                       # Letter or digit, or hex escaped letter/digit.
my $alphanums      =  "(?:${alphanum}+)";
my $escape         =  "(?:%$hex\{2})";
my $safe           =  '[$\-_.+]';
my $extra          =  "[!*'(),]";
my $reserved       =  '[;/?:@&=]';
my $uchar          =  "(?:${alphanum}|${safe}|${extra}|${escape})";
   $uchar          =~ s/\Q]|[\E//g;  # Make string smaller, and speed up regex.

# URL schemeparts for ip based protocols:
my $user           =  "(?:(?:${uchar}|[;?&=])*)";
my $password       =  "(?:(?:${uchar}|[;?&=])*)";
my $hostnumber     =  "(?:${digits}(?:${dot}${digits}){3})";
my $toplabel       =  "(?:${alpha}(?:(?:${alphanum}|-)*${alphanum})?)";
my $domainlabel    =  "(?:${alphanum}(?:(?:${alphanum}|-)*${alphanum})?)";
my $hostname       =  "(?:(?:${domainlabel}${dot})*${toplabel})";
my $host           =  "(?:${hostname}|${hostnumber})";
my $hostport       =  "(?:${host}(?::${digits})?)";
my $login          =  "(?:(?:${user}(?::${password})?\@)?${hostport})";

# The predefined schemes:

## FTP (see also RFC959)
#my $fsegment       =  "(?:(?:${uchar}|[?:\@&=])*)";
#my $fpath          =  "(?:${fsegment}(?:/${fsegment})*)";
#my $ftpurl         =  "(?:ftp://${login}(?:/${fpath}(?:;type=[AIDaid])?)?)";


# HTTP
my $hsegment       =  "(?:(?:${uchar}|[;:\@&=])*)";
my $search         =  "(?:(?:${uchar}|[;:\@&=])*)";
my $hpath          =  "(?:${hsegment}(?:/${hsegment})*)";
my $httpurl        =  "(?:http(s)?://${hostport}(?:/${hpath}(?:${qm}${search})?)?)";

sub valid_url {
	my $test = shift;

	return ($test =~ /^$httpurl$/o)?1:0;
}

1;
