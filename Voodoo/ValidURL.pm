package Apache::Voodoo::ValidURL;

$VERSION = sprintf("%0.4f",('$HeadURL$' =~ m!(\d+\.\d+)!)[0]||10);

#
# I saw this code fragment somewhere ages ago, I can't remember where.
# So, I can't attribute it to the proper author.  sorry!
#
# I've commented out everthing not pertaining to HTTP URLs.  That
# was the part I really needed.
#

use strict;

# Be paranoid about using grouping!
my $nz_digit       =  '[1-9]';
my $nz_digits      =  "(?:$nz_digit\\d*)";
my $digits         =  '(?:\d+)';
my $space          =  '(?:%20)';
my $nl             =  '(?:%0[Aa])';
my $dot            =  '\.';
my $plus           =  '\+';
my $qm             =  '\?';
my $ast            =  '\*';
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
my $national       =  '[{}|\\^~[\]`]';
my $punctuation    =  '[<>#%"]';
my $reserved       =  '[;/?:@&=]';
my $uchar          =  "(?:${alphanum}|${safe}|${extra}|${escape})";
my $xchar          =  "(?:${alphanum}|${safe}|${extra}|${reserved}|${escape})";
   $uchar          =~ s/\Q]|[\E//g;  # Make string smaller, and speed up regex.
   $xchar          =~ s/\Q]|[\E//g;  # Make string smaller, and speed up regex.

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
#
## FILE
#my $fileurl        =  "(?:file://(?:${host}|localhost)?/${fpath})";

# HTTP
my $hsegment       =  "(?:(?:${uchar}|[;:\@&=])*)";
my $search         =  "(?:(?:${uchar}|[;:\@&=])*)";
my $hpath          =  "(?:${hsegment}(?:/${hsegment})*)";
my $httpurl        =  "(?:http(s)?://${hostport}(?:/${hpath}(?:${qm}${search})?)?)";

## GOPHER (see also RFC1436)
#my $gopher_plus    =  "(?:${xchar}*)";
#my $selector       =  "(?:${xchar}*)";
#my $gtype          =      ${xchar};     # Omitted parens!
#my $gopherurl      =  "(?:gopher://${hostport}(?:/${gtype}(?:${selector}" .
#                      "(?:%09${search}(?:%09${gopher_plus})?)?)?)?)";
#
## MAILTO (see also RFC822)
#my $encoded822addr =  "(?:$xchar+)";
#my $mailtourl      =  "(?:mailto:$encoded822addr)";
#
## NEWS (see also RFC1036)
#my $article        =  "(?:(?:${uchar}|[;/?:&=])+\@${host})";
#my $group          =  "(?:${alpha}(?:${alphanum}|[_.+-])*)";
#my $grouppart      =  "(?:${article}|${group}|${ast})";
#my $newsurl        =  "(?:news:${grouppart})";
#
## NNTP (see also RFC977)
#my $nntpurl        =  "(?:nntp://${hostport}/${group}(?:/${digits})?)";
#
## TELNET
#my $telneturl      =  "(?:telnet://${login}/?)";
#
## WAIS (see also RFC1625)
#my $wpath          =  "(?:${uchar}*)";
#my $wtype          =  "(?:${uchar}*)";
#my $database       =  "(?:${uchar}*)";
#my $waisdoc        =  "(?:wais://${hostport}/${database}/${wtype}/${wpath})";
#my $waisindex      =  "(?:wais://${hostport}/${database}${qm}${search})";
#my $waisdatabase   =  "(?:wais://${hostport}/${database})";
## my $waisurl        =  "(?:${waisdatabase}|${waisindex}|${waisdoc})";
## Speed up: the 3 types share a common prefix.
#my $waisurl        =  "(?:wais://${hostport}/${database}" .
#                      "(?:(?:/${wtype}/${wpath})|${qm}${search})?)";
#
## PROSPERO
#my $fieldvalue     =  "(?:(?:${uchar}|[?:\@&])*)";
#my $fieldname      =  "(?:(?:${uchar}|[?:\@&])*)";
#my $fieldspec      =  "(?:;${fieldname}=${fieldvalue})";
#my $psegment       =  "(?:(?:${uchar}|[?:\@&=])*)";
#my $ppath          =  "(?:${psegment}(?:/${psegment})*)";
#my $prosperourl    =  "(?:prospero://${hostport}/${ppath}(?:${fieldspec})*)";
#
## LDAP (see also RFC1959)
## First. import stuff from RFC 1779 (Distinguished Names).
## We've modified things a bit.
#my $dn_separator        =  "(?:[;,])";
#my $dn_optional_space   =  "(?:${nl}?${space}*)";
#my $dn_spaced_separator =  "(?:${dn_optional_space}${dn_separator}" .
#                           "${dn_optional_space})";
#my $dn_oid              =  "(?:${digits}(?:${dot}${digits})*)";
#my $dn_keychar          =  "(?:${xalphanum}|${space})";
#my $dn_key              =  "(?:${dn_keychar}+|(?:OID|oid)${dot}${dn_oid})";
#my $dn_string           =  "(?:${uchar}*)";
#my $dn_attribute        =  "(?:(?:${dn_key}${dn_optional_space}=" .
#                           "${dn_optional_space})?${dn_string})";
#my $dn_name_component   =  "(?:${dn_attribute}(?:${dn_optional_space}" .
#                           "${plus}${dn_optional_space}${dn_attribute})*)";
#my $dn_name             =  "(?:${dn_name_component}" .
#                           "(?:${dn_spaced_separator}${dn_name_component})*" .
#                           "${dn_spaced_separator}?)";
#
## RFC 1558 defines the filter syntax, but that requires a PDA to recognize.
## Since that's too powerful for Perl's REs, we allow any char between the
## parenthesis (which have to be there.)
#my $ldap_filter         =  "(?:\(${xchar}+\))";
#
## This is from RFC 1777. It defines an attributetype as an 'OCTET STRING',
## whatever that is.
#my $ldap_attr_type      =  "(?:${uchar}+)";  # I'm just guessing here.
#                                              # The RFCs aren't clear.
#
## Now we are at the grammar of RFC 1959.
#my $ldap_attr_list =  "(?:${ldap_attr_type}(?:,${ldap_attr_type})*)";
#my $ldap_attrs     =  "(?:${ldap_attr_list}?)";
#
#my $ldap_scope     =  "(?:base|one|sub)";
#my $ldapurl        =  "(?:ldap://(?:${hostport})?/${dn_name}" .
#                      "(?:${qm}${ldap_attrs}" .
#                      "(?:${qm}${ldap_scope}(?:${qm}${ldap_filter})?)?)?)";
#
#
## RFC 2056 defines the format of URLs for the Z39.50 protocol.
#my $z_database     =  "(?:${uchar}+)";
#my $z_docid        =  "(?:${uchar}+)";
#my $z_elementset   =  "(?:${uchar}+)";
#my $z_recordsyntax =  "(?:${uchar}+)";
#my $z_scheme       =  "(?:z39${dot}50[rs])";
#my $z39_50url      =  "(?:${z_scheme}://${hostport}" .
#                           "(?:/(?:${z_database}(?:${plus}${z_database})*" .
#                                   "(?:${qm}${z_docid})?)?" .
#                               "(?:;esn=${z_elementset})?" .
#                               "(?:;rs=${z_recordsyntax}" .
#                                    "(?:${plus}${z_recordsyntax})*)?))";
#
#
## RFC 2111 defines the format for cid/mid URLs.
#my $url_addr_spec  =  "(?:(?:${uchar}|[;?:@&=])*)";
#my $message_id     =  $url_addr_spec;
#my $content_id     =  $url_addr_spec;
#my $cidurl         =  "(?:cid:${content_id})";
#my $midurl         =  "(?:mid:${message_id}(?:/${content_id})?)";
#
#
## RFC 2122 defines the Vemmi URLs.
#my $vemmi_attr     =  "(?:(?:${uchar}|[/?:@&])*)";
#my $vemmi_value    =  "(?:(?:${uchar}|[/?:@&])*)";
#my $vemmi_service  =  "(?:(?:${uchar}|[/?:@&=])*)";
#my $vemmi_param    =  "(?:;${vemmi_attr}=${vemmi_value})";
#my $vemmiurl       =  "(?:vemmi://${hostport}" . 
#                          "(?:/${vemmi_service}(?:${vemmi_param}*))?)";
#
## RFC 2192 for IMAP URLs.
## Import from RFC 2060.
## my $imap4_astring       =  "";
## my $imap4_search_key    =  "";
## my $imap4_section_text  =  "";
#my $imap4_nz_number     =  $nz_digits;
#my $achar          =  "(?:${uchar}|[&=~])";
#my $bchar          =  "(?:${uchar}|[&=~:\@/])";
#my $enc_auth_type  =  "(?:${achar}+)";
#my $enc_list_mbox  =  "(?:${bchar}+)";
#my $enc_mailbox    =  "(?:${bchar}+)";
#my $enc_search     =  "(?:${bchar}+)";
#my $enc_section    =  "(?:${bchar}+)";
#my $enc_user       =  "(?:${achar}+)";
#my $i_auth         =  "(?:;[Aa][Uu][Tt][Hh]=(?:${ast}|${enc_auth_type}))";
#my $i_list_type    =  "(?:[Ll](?:[Ii][Ss][Tt]|[Ss][Uu][Bb]))";
#my $i_mailboxlist  =  "(?:${enc_list_mbox}?;[Tt][Yy][Pp][Ee]=${i_list_type})";
#my $i_uidvalidity  =  "(?:;[Uu][Ii][Dd][Vv][Aa][Ll][Ii][Dd][Ii][Tt][Yy]=" .
#                          "${imap4_nz_number})";
#my $i_messagelist  =  "(?:${enc_mailbox}(?:${qm}${enc_search})?" .
#                                       "(?:${i_uidvalidity})?)";
#my $i_section      =  "(?:/;[Ss][Ee][Cc][Tt][Ii][Oo][Nn]=${enc_section})";
#my $i_uid          =  "(?:/;[Uu][Ii][Dd]=${imap4_nz_number})";
#my $i_messagepart  =  "(?:${enc_mailbox}(?:${i_uidvalidity})?${i_uid}" .
#                                       "(?:${i_section})?)";
#my $i_command      =  "(?:${i_mailboxlist}|${i_messagelist}|${i_messagepart})";
#my $i_userauth     =  "(?:(?:${enc_user}(?:${i_auth})?)|" .
#                         "(?:${i_auth}(?:${enc_user})?))";
#my $i_server       =  "(?:(?:${i_userauth}\@)?${hostport})";
#my $imapurl        =  "(?:imap://${i_server}/(?:$i_command)?)";
#
## RFC 2224 for NFS.
#my $nfs_mark       =  '[\$\-_.!~*\'(),]';
#my $nfs_unreserved =  "(?:${alphanum}|${nfs_mark})";
#   $nfs_unreserved =~ s/\Q]|[//g;
#my $nfs_pchar      =  "(?:${nfs_unreserved}|${escape}|[:\@&=+])";
#my $nfs_segment    =  "(?:${nfs_pchar}*)";
#my $nfs_path_segs  =  "(?:${nfs_segment}(?:/${nfs_segment})*)";
#my $nfs_url_path   =  "(?:/?${nfs_path_segs})";
#my $nfs_rel_path   =  "(?:${nfs_path_segs}?)";
#my $nfs_abs_path   =  "(?:/${nfs_rel_path})";
#my $nfs_net_path   =  "(?://${hostport}(?:${nfs_abs_path})?)";
#my $nfs_rel_url    =  "(?:${nfs_net_path}|${nfs_abs_path}|${nfs_rel_path})";
#my $nfsurl         =  "(?:nfs:${nfs_rel_url})";


# Combining all the different URL formats into a single regex.

# The only one's we're interested in are http urls

#my $url            =  join "|", $httpurl,   $ftpurl,      $newsurl,  $nntpurl,
#                                $telneturl, $gopherurl,   $waisurl,  $mailtourl,
#                                $fileurl,   $prosperourl, $ldapurl,  $z39_50url,
#                                $cidurl,    $midurl,      $vemmiurl, $imapurl,
#                                $nfsurl;

my $url = $httpurl;


sub valid_url {
	my $test = shift;

	return ($test =~ /^$url$/o)?1:0;
}

1;
