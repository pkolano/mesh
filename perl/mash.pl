#!/usr/bin/perl -T
#
# Copyright (C) 2006-2017 United States Government as represented by the
# Administrator of the National Aeronautics and Space Administration
# (NASA).  All Rights Reserved.
#
# This software is distributed under the NASA Open Source Agreement
# (NOSA), version 1.3.  The NOSA has been approved by the Open Source
# Initiative.  See http://www.opensource.org/licenses/nasa1.3.php
# for the complete NOSA document.
#
# THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY OF ANY
# KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT
# LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM TO
# SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
# A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT
# THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT
# DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS
# AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY
# GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING
# DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING
# FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS
# ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF
# PRESENT IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS".
#
# RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS AGAINST THE UNITED STATES
# GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR
# RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT SOFTWARE RESULTS IN ANY
# LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR LOSSES ARISING FROM SUCH USE,
# INCLUDING ANY DAMAGES FROM PRODUCTS BASED ON, OR RESULTING FROM,
# RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT SHALL INDEMNIFY AND
# HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND
# SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE EXTENT PERMITTED
# BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER SHALL BE THE
# IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.
#

# This program is a restricted shell that is invoked on the MP and MAP as
# the login shell for all users.  It will only execute commands authorized
# by the mashrc configuration.  Mash utilizes a set of Perl modules
# that process different elements of the configured policy.  Note that
# this program is called "mash.pl" in the Mesh distribution, but is
# renamed to "mash" during installation.

use strict;
use Sys::Syslog;
use Text::ParseWords;
require XML::TreePP;

our $VERSION = 0.46;

# use begin block for parsing config so mash modules can be located first
my %conf;
BEGIN {
    # suppress compilation aborted message
    local $SIG{__DIE__} = sub {warn @_; exit 1};

    # default configuration
    %conf = (
        conf_file => "/etc/mesh/mesh.conf",
        key_days => 7,
        mesh_group => "mesh",
        mp_host => undef,
        prefix_dir => "/usr/local",
    );

    # parse configuration
    open(FILE, $conf{conf_file}) or
        die "Config file $conf{conf_file} does not exist or is not readable\n";
    my $mline;
    while (my $line = <FILE>) {
        # strip whitespace and comments
        $line =~ s/^\s+|\s+$|\s*#.*//g;
        next if (!$line);
        # support line continuation operator
        $mline .= $line;
        next if ($mline =~ s/\s*\\$/ /);
        $conf{$1} = $2 if ($mline =~ /^(\S+)\s+(.*)/);
        $mline = undef;
    }
    close FILE;

    # exit if any required parameters are not defined
    foreach my $key (keys %conf) {
        die "Config parameter \"$key\" is not defined\n"
            if (!$conf{$key});
    }

    # add mash modules based on prefix
    push(@INC, "$conf{prefix_dir}/lib");
}

require Mash::Policy;

my $config = {};
my $user = getpwuid($<);
my $ip = $ENV{SSH_CONNECTION};
# strip out IPv6 info in older versions of SSH
$ip =~ s/\s.*|:\S*://g;
# invoked locally if SSH_CONNECTION does not exist in environment
$ip = "127.0.0.1" if (!$ip);

# log given message to syslog if enabled
sub mylog {
    my $msg = shift;
    return if (!exists $config->{syslog});
    my $facility = $config->{syslog}->{facility};
    $facility = 'user' if (!$facility);
    openlog("mash", 'pid', $facility);
    my $priority = $config->{syslog}->{priority};
    $priority = 'info' if (!$priority);
    syslog($priority, "$user $ip $msg");
    closelog();
}

# exit or loop with given error message
sub mydie {
    my $noexit = shift;
    my $msg = "Permission denied";
    if (defined $Mash::Policy::Error) {
        $msg .= " (" . $Mash::Policy::Error . ").";
    } else {
        $msg .= " (unauthorized command).";
    }
    print STDERR "$msg\n";
    if ($noexit) {
        # this only occurs when a prompt is configured
        mylog "LOOP '$msg'";
    } else {
        mylog "EXIT '$msg'";
        exit 1;
    }
}

# slurp mashrc file
mydie if (! -r "/etc/mesh/mashrc");
my $xml = do {local(@ARGV, $/) = "/etc/mesh/mashrc"; <>};
# dynamically replace MESHCONF_* with corresponding values in configuration
$xml =~ s/MESHCONF_(\w+)/$conf{$1}/g;
# parse mashrc file
my $treepp = XML::TreePP->new(attr_prefix => "", text_node_key => "content");
$config = $treepp->parse($xml) or mydie;
$config = $config->{mashrc};

if (defined $config->{prompt} && (scalar(@ARGV) == 0 || $ARGV[0] ne '-c')) {
    # prompt configured and -c not given so act like normal shell
    $config->{prompt} =~ s/\\n/\n/g;
    my $cmd;
    $SIG{INT} = sub {
        # C-c returns new prompt
        $cmd = "";
        $| = 1;
        print "\n$config->{prompt} ";
        $| = 0;
    };
    while (1) {
        # keep reading commands until explicit exit
        print "$config->{prompt} ";
        $cmd = <STDIN>;
        exit if ($cmd =~ /^\s*exit\s*$/);
        # print error message but do not exit if unauthorized command
        mydie(1) if (!defined do_cmd($cmd));
    }
} else {
    # assume bash if not given -c and prompt not configured
    @ARGV = ('-c', 'bash') if (scalar(@ARGV) == 0 || $ARGV[0] ne '-c');
    my $rc = do_cmd($ARGV[1]);
    mydie if (!defined $rc);
    exit $rc;
}

# execute the given command if authorized and return the exit code
sub do_cmd {
    my $cmd = shift;

    # exit if key expired
    $Mash::Policy::Error = "key expired";
    mydie if ($ENV{MESH_PUBKEY} =~ /\s+(\d+)\s*$/ && $1 < time);
    $Mash::Policy::Error = undef;

    $cmd =~ s/^\s+|\s+$//g;
    @ARGV = quotewords('\s+', 1, $cmd);
    # log original command to syslog
    mylog "RCMD '" . join("' '", @ARGV) . "'";

    # parse policies
    my $pols = $config->{policies};
    my $rewrite = undef;
    # attempt to find policy that permits given command
    foreach my $pol_name (keys %{$pols}) {
        my $pol = Mash::Policy->new($pols->{$pol_name}, $config->{parsers});
        $rewrite = $pol->parse;
        last if (defined $rewrite);
    }
    return undef if (!defined $rewrite);
    my @newcmd = @{$rewrite};

    # log modified command to syslog
    mylog "EXEC '" . join("' '", @newcmd) . "'";

    # ENV will be set in rcommand parsing
    system {$newcmd[0]} @newcmd;
    return $? >> 8;
}

# This chunk of stuff was generated by App::FatPacker. To find the original
# file's code, look for the end of this BEGIN block or the string 'FATPACK'
BEGIN {
my %fatpacked;

$fatpacked{"XML/TreePP.pm"} = '#line '.(1+__LINE__).' "'.__FILE__."\"\n".<<'XML_TREEPP';
  package XML::TreePP;use strict;use Carp;use Symbol;use vars qw($VERSION);$VERSION='0.43';my$XML_ENCODING='UTF-8';my$INTERNAL_ENCODING='UTF-8';my$USER_AGENT='XML-TreePP/'.$VERSION.' ';my$ATTR_PREFIX='-';my$TEXT_NODE_KEY='#text';my$USE_ENCODE_PM=($] >= 5.008);my$ALLOW_UTF8_FLAG=($] >= 5.008001);my$EMPTY_ELEMENT_TAG_END=' />';sub new {my$package=shift;my$self={@_};bless$self,$package;$self}sub die {my$self=shift;my$mess=shift;return if$self->{ignore_error};Carp::croak$mess}sub warn {my$self=shift;my$mess=shift;return if$self->{ignore_error};Carp::carp$mess}sub set {my$self=shift;my$key=shift;my$val=shift;if (defined$val){$self->{$key}=$val}else {delete$self->{$key}}}sub get {my$self=shift;my$key=shift;$self->{$key}if exists$self->{$key}}sub writefile {my$self=shift;my$file=shift;my$tree=shift or return$self->die('Invalid tree');my$encode=shift;return$self->die('Invalid filename')unless defined$file;my$text=$self->write($tree,$encode);if ($ALLOW_UTF8_FLAG && utf8::is_utf8($text)){utf8::encode($text)}$self->write_raw_xml($file,$text)}sub write {my$self=shift;my$tree=shift or return$self->die('Invalid tree');my$from=$self->{internal_encoding}|| $INTERNAL_ENCODING;my$to=shift || $self->{output_encoding}|| $XML_ENCODING;my$decl=$self->{xml_decl};$decl='<?xml version="1.0" encoding="' .$to .'" ?>' unless defined$decl;local$self->{__first_out};if (exists$self->{first_out}){my$keys=$self->{first_out};$keys=[$keys]unless ref$keys;$self->{__first_out}={map {$keys->[$_]=>$_}0 .. $#$keys }}local$self->{__last_out};if (exists$self->{last_out}){my$keys=$self->{last_out};$keys=[$keys]unless ref$keys;$self->{__last_out}={map {$keys->[$_]=>$_}0 .. $#$keys }}my$tnk=$self->{text_node_key}if exists$self->{text_node_key};$tnk=$TEXT_NODE_KEY unless defined$tnk;local$self->{text_node_key}=$tnk;my$apre=$self->{attr_prefix}if exists$self->{attr_prefix};$apre=$ATTR_PREFIX unless defined$apre;local$self->{__attr_prefix_len}=length($apre);local$self->{__attr_prefix_rex}=$apre;local$self->{__indent};if (exists$self->{indent}&& $self->{indent}){$self->{__indent}=' ' x $self->{indent}}if (!UNIVERSAL::isa($tree,'HASH')){return$self->die('Invalid tree')}my$text=$self->hash_to_xml(undef,$tree);if ($from && $to){my$stat=$self->encode_from_to(\$text,$from,$to);return$self->die("Unsupported encoding: $to")unless$stat}return$text if ($decl eq '');join("\n",$decl,$text)}sub parsehttp {my$self=shift;local$self->{__user_agent};if (exists$self->{user_agent}){my$agent=$self->{user_agent};$agent .= $USER_AGENT if ($agent =~ /\s$/s);$self->{__user_agent}=$agent if ($agent ne '')}else {$self->{__user_agent}=$USER_AGENT}my$http=$self->{__http_module};unless ($http){$http=$self->find_http_module(@_);$self->{__http_module}=$http}if ($http eq 'LWP::UserAgent'){return$self->parsehttp_lwp(@_)}elsif ($http eq 'HTTP::Lite'){return$self->parsehttp_lite(@_)}else {return$self->die("LWP::UserAgent or HTTP::Lite is required: $_[1]")}}sub find_http_module {my$self=shift || {};if (exists$self->{lwp_useragent}&& ref$self->{lwp_useragent}){return 'LWP::UserAgent' if defined$LWP::UserAgent::VERSION;return 'LWP::UserAgent' if&load_lwp_useragent();return$self->die("LWP::UserAgent is required: $_[1]")}if (exists$self->{http_lite}&& ref$self->{http_lite}){return 'HTTP::Lite' if defined$HTTP::Lite::VERSION;return 'HTTP::Lite' if&load_http_lite();return$self->die("HTTP::Lite is required: $_[1]")}return 'LWP::UserAgent' if defined$LWP::UserAgent::VERSION;return 'HTTP::Lite' if defined$HTTP::Lite::VERSION;return 'LWP::UserAgent' if&load_lwp_useragent();return 'HTTP::Lite' if&load_http_lite();return$self->die("LWP::UserAgent or HTTP::Lite is required: $_[1]")}sub load_lwp_useragent {return$LWP::UserAgent::VERSION if defined$LWP::UserAgent::VERSION;local $@;eval {require LWP::UserAgent};$LWP::UserAgent::VERSION}sub load_http_lite {return$HTTP::Lite::VERSION if defined$HTTP::Lite::VERSION;local $@;eval {require HTTP::Lite};$HTTP::Lite::VERSION}sub load_tie_ixhash {return$Tie::IxHash::VERSION if defined$Tie::IxHash::VERSION;local $@;eval {require Tie::IxHash};$Tie::IxHash::VERSION}sub parsehttp_lwp {my$self=shift;my$method=shift or return$self->die('Invalid HTTP method');my$url=shift or return$self->die('Invalid URL');my$body=shift;my$header=shift;my$ua=$self->{lwp_useragent}if exists$self->{lwp_useragent};if (!ref$ua){$ua=LWP::UserAgent->new();$ua->env_proxy();$ua->agent($self->{__user_agent})if defined$self->{__user_agent}}else {$ua->agent($self->{__user_agent})if exists$self->{user_agent}}my$req=HTTP::Request->new($method,$url);my$ct=0;if (ref$header){for my$field (sort keys %$header){my$value=$header->{$field};$req->header($field=>$value);$ct ++ if ($field =~ /^Content-Type$/i)}}if (defined$body &&!$ct){$req->header('Content-Type'=>'application/x-www-form-urlencoded')}$req->add_content_utf8($body)if defined$body;my$res=$ua->request($req);my$code=$res->code();my$text;if ($res->can('decoded_content')){$text=$res->decoded_content(charset=>'none')}else {$text=$res->content()}my$tree=$self->parse(\$text)if$res->is_success();wantarray ? ($tree,$text,$code): $tree}sub parsehttp_lite {my$self=shift;my$method=shift or return$self->die('Invalid HTTP method');my$url=shift or return$self->die('Invalid URL');my$body=shift;my$header=shift;my$http=HTTP::Lite->new();$http->method($method);my$ua=0;if (ref$header){for my$field (sort keys %$header){my$value=$header->{$field};$http->add_req_header($field,$value);$ua ++ if ($field =~ /^User-Agent$/i)}}if (defined$self->{__user_agent}&&!$ua){$http->add_req_header('User-Agent',$self->{__user_agent})}$http->{content}=$body if defined$body;my$code=$http->request($url)or return;my$text=$http->body();my$tree=$self->parse(\$text);wantarray ? ($tree,$text,$code): $tree}sub parsefile {my$self=shift;my$file=shift;return$self->die('Invalid filename')unless defined$file;my$text=$self->read_raw_xml($file);$self->parse(\$text)}sub parse {my$self=shift;my$text=ref $_[0]? ${$_[0]}: $_[0];return$self->die('Null XML source')unless defined$text;my$from=&xml_decl_encoding(\$text)|| $XML_ENCODING;my$to=$self->{internal_encoding}|| $INTERNAL_ENCODING;if ($from && $to){my$stat=$self->encode_from_to(\$text,$from,$to);return$self->die("Unsupported encoding: $from")unless$stat}local$self->{__force_array};local$self->{__force_array_all};if (exists$self->{force_array}){my$force=$self->{force_array};$force=[$force]unless ref$force;$self->{__force_array}={map {$_=>1}@$force };$self->{__force_array_all}=$self->{__force_array}->{'*'}}local$self->{__force_hash};local$self->{__force_hash_all};if (exists$self->{force_hash}){my$force=$self->{force_hash};$force=[$force]unless ref$force;$self->{__force_hash}={map {$_=>1}@$force };$self->{__force_hash_all}=$self->{__force_hash}->{'*'}}my$tnk=$self->{text_node_key}if exists$self->{text_node_key};$tnk=$TEXT_NODE_KEY unless defined$tnk;local$self->{text_node_key}=$tnk;my$apre=$self->{attr_prefix}if exists$self->{attr_prefix};$apre=$ATTR_PREFIX unless defined$apre;local$self->{attr_prefix}=$apre;if (exists$self->{use_ixhash}&& $self->{use_ixhash}){return$self->die("Tie::IxHash is required.")unless&load_tie_ixhash()}if (exists$self->{require_xml_decl}&& $self->{require_xml_decl}){return$self->die("XML declaration not found")unless looks_like_xml(\$text)}my$flat=$self->xml_to_flat(\$text);my$class=$self->{base_class}if exists$self->{base_class};my$tree=$self->flat_to_tree($flat,'',$class);if (ref$tree){if (defined$class){bless($tree,$class)}elsif (exists$self->{elem_class}&& $self->{elem_class}){bless($tree,$self->{elem_class})}}wantarray ? ($tree,$text): $tree}sub xml_to_flat {my$self=shift;my$textref=shift;my$flat=[];my$prefix=$self->{attr_prefix};my$ixhash=(exists$self->{use_ixhash}&& $self->{use_ixhash});my$deref=\&xml_unescape;my$xml_deref=(exists$self->{xml_deref}&& $self->{xml_deref});if ($xml_deref){if ((exists$self->{utf8_flag}&& $self->{utf8_flag})|| ($ALLOW_UTF8_FLAG && utf8::is_utf8($$textref))){$deref=\&xml_deref_string}else {$deref=\&xml_deref_octet}}while ($$textref =~ m{
          ([^<]*) <
          ((
              \? ([^<>]*) \?
          )|(
              \!\[CDATA\[(.*?)\]\]
          )|(
              \!DOCTYPE\s+([^\[\]<>]*(?:\[.*?\]\s*)?)
          )|(
              \!--(.*?)--
          )|(
              ([^\!\?\s<>](?:"[^"]*"|'[^']*'|[^"'<>])*)
          ))
          > ([^<]*)
      }sxg){my ($ahead,$match,$typePI,$contPI,$typeCDATA,$contCDATA,$typeDocT,$contDocT,$typeCmnt,$contCmnt,$typeElem,$contElem,$follow)=($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13);if (defined$ahead && $ahead =~ /\S/){$ahead =~ s/([^\040-\076])/sprintf("\\x%02X",ord($1))/eg;$self->warn("Invalid string: [$ahead] before <$match>")}if ($typeElem){my$node={};if ($contElem =~ s#^/##){$node->{endTag}++}elsif ($contElem =~ s#/$##){$node->{emptyTag}++}else {$node->{startTag}++}$node->{tagName}=$1 if ($contElem =~ s#^(\S+)\s*##);unless ($node->{endTag}){my$attr;while ($contElem =~ m{
                      ([^\s\=\"\']+)\s*=\s*(?:(")(.*?)"|'(.*?)')
                  }sxg){my$key=$1;my$val=&$deref($2 ? $3 : $4);if (!ref$attr){$attr={};tie(%$attr,'Tie::IxHash')if$ixhash}$attr->{$prefix.$key}=$val}$node->{attributes}=$attr if ref$attr}push(@$flat,$node)}elsif ($typeCDATA){if (exists$self->{cdata_scalar_ref}&& $self->{cdata_scalar_ref}){push(@$flat,\$contCDATA)}else {push(@$flat,$contCDATA)}}elsif ($typeCmnt){}elsif ($typeDocT){}elsif ($typePI){}else {$self->warn("Invalid Tag: <$match>")}if ($follow =~ /\S/){my$val=&$deref($follow);push(@$flat,$val)}}$flat}sub flat_to_tree {my$self=shift;my$source=shift;my$parent=shift;my$class=shift;my$tree={};my$text=[];if (exists$self->{use_ixhash}&& $self->{use_ixhash}){tie(%$tree,'Tie::IxHash')}while (scalar @$source){my$node=shift @$source;if (!ref$node || UNIVERSAL::isa($node,"SCALAR")){push(@$text,$node);next}my$name=$node->{tagName};if ($node->{endTag}){last if ($parent eq $name);return$self->die("Invalid tag sequence: <$parent></$name>")}my$elem=$node->{attributes};my$forcehash=$self->{__force_hash_all}|| $self->{__force_hash}->{$name};my$subclass;if (defined$class){my$escname=$name;$escname =~ s/\W/_/sg;$subclass=$class.'::'.$escname}if ($node->{startTag}){my$child=$self->flat_to_tree($source,$name,$subclass);next unless defined$child;my$hasattr=scalar keys %$elem if ref$elem;if (UNIVERSAL::isa($child,"HASH")){if ($hasattr){%$elem=(%$elem,%$child)}else {$elem=$child}}else {if ($hasattr){$elem->{$self->{text_node_key}}=$child}elsif ($forcehash){$elem={$self->{text_node_key}=>$child }}else {$elem=$child}}}elsif ($forcehash &&!ref$elem){$elem={}}if (ref$elem && UNIVERSAL::isa($elem,"HASH")){if (defined$subclass){bless($elem,$subclass)}elsif (exists$self->{elem_class}&& $self->{elem_class}){my$escname=$name;$escname =~ s/\W/_/sg;my$elmclass=$self->{elem_class}.'::'.$escname;bless($elem,$elmclass)}}$tree->{$name}||=[];push(@{$tree->{$name}},$elem)}if (!$self->{__force_array_all}){for my$key (keys %$tree){next if$self->{__force_array}->{$key};next if (1 < scalar @{$tree->{$key}});$tree->{$key}=shift @{$tree->{$key}}}}my$haschild=scalar keys %$tree;if (scalar @$text){if (scalar @$text==1){$text=shift @$text}elsif (!scalar grep {ref $_}@$text){$text=join('',@$text)}else {my$join=join('',map {ref $_ ? $$_ : $_}@$text);$text=\$join}if ($haschild){$tree->{$self->{text_node_key}}=$text}else {$tree=$text}}elsif (!$haschild){$tree=""}$tree}sub hash_to_xml {my$self=shift;my$name=shift;my$hash=shift;my$out=[];my$attr=[];my$allkeys=[keys %$hash ];my$fo=$self->{__first_out}if ref$self->{__first_out};my$lo=$self->{__last_out}if ref$self->{__last_out};my$firstkeys=[sort {$fo->{$a}<=> $fo->{$b}}grep {exists$fo->{$_}}@$allkeys ]if ref$fo;my$lastkeys=[sort {$lo->{$a}<=> $lo->{$b}}grep {exists$lo->{$_}}@$allkeys ]if ref$lo;$allkeys=[grep {!exists$fo->{$_}}@$allkeys ]if ref$fo;$allkeys=[grep {!exists$lo->{$_}}@$allkeys ]if ref$lo;unless (exists$self->{use_ixhash}&& $self->{use_ixhash}){$allkeys=[sort @$allkeys ]}my$prelen=$self->{__attr_prefix_len};my$pregex=$self->{__attr_prefix_rex};my$textnk=$self->{text_node_key};my$tagend=$self->{empty_element_tag_end}|| $EMPTY_ELEMENT_TAG_END;for my$keys ($firstkeys,$allkeys,$lastkeys){next unless ref$keys;my$elemkey=$prelen ? [grep {substr($_,0,$prelen)ne $pregex}@$keys ]: $keys;my$attrkey=$prelen ? [grep {substr($_,0,$prelen)eq $pregex}@$keys ]: [];for my$key (@$elemkey){my$val=$hash->{$key};if (!defined$val){next if ($key eq $textnk);push(@$out,"<$key$tagend")}elsif (UNIVERSAL::isa($val,'HASH')){my$child=$self->hash_to_xml($key,$val);push(@$out,$child)}elsif (UNIVERSAL::isa($val,'ARRAY')){my$child=$self->array_to_xml($key,$val);push(@$out,$child)}elsif (UNIVERSAL::isa($val,'SCALAR')){my$child=$self->scalaref_to_cdata($key,$val);push(@$out,$child)}else {my$ref=ref$val;$self->warn("Unsupported reference type: $ref in $key")if$ref;my$child=$self->scalar_to_xml($key,$val);push(@$out,$child)}}for my$key (@$attrkey){my$name=substr($key,$prelen);my$val=&xml_escape($hash->{$key});push(@$attr,' ' .$name .'="' .$val .'"')}}my$jattr=join('',@$attr);if (defined$name && scalar @$out &&!grep {!/^</s}@$out){if (defined$self->{__indent}){s/^(\s*<)/$self->{__indent}$1/mg foreach @$out}unshift(@$out,"\n")}my$text=join('',@$out);if (defined$name){if (scalar @$out){$text="<$name$jattr>$text</$name>\n"}else {$text="<$name$jattr$tagend\n"}}$text}sub array_to_xml {my$self=shift;my$name=shift;my$array=shift;my$out=[];my$tagend=$self->{empty_element_tag_end}|| $EMPTY_ELEMENT_TAG_END;for my$val (@$array){if (!defined$val){push(@$out,"<$name$tagend\n")}elsif (UNIVERSAL::isa($val,'HASH')){my$child=$self->hash_to_xml($name,$val);push(@$out,$child)}elsif (UNIVERSAL::isa($val,'ARRAY')){my$child=$self->array_to_xml($name,$val);push(@$out,$child)}elsif (UNIVERSAL::isa($val,'SCALAR')){my$child=$self->scalaref_to_cdata($name,$val);push(@$out,$child)}else {my$ref=ref$val;$self->warn("Unsupported reference type: $ref in $name")if$ref;my$child=$self->scalar_to_xml($name,$val);push(@$out,$child)}}my$text=join('',@$out);$text}sub scalaref_to_cdata {my$self=shift;my$name=shift;my$ref=shift;my$data=defined $$ref ? $$ref : '';$data =~ s#(]])(>)#$1]]><![CDATA[$2#g;my$text='<![CDATA[' .$data .']]>';$text="<$name>$text</$name>\n" if ($name ne $self->{text_node_key});$text}sub scalar_to_xml {my$self=shift;my$name=shift;my$scalar=shift;my$copy=$scalar;my$text=&xml_escape($copy);$text="<$name>$text</$name>\n" if ($name ne $self->{text_node_key});$text}sub write_raw_xml {my$self=shift;my$file=shift;my$fh=Symbol::gensym();open($fh,">$file")or return$self->die("$! - $file");print$fh @_;close($fh)}sub read_raw_xml {my$self=shift;my$file=shift;my$fh=Symbol::gensym();open($fh,$file)or return$self->die("$! - $file");local $/=undef;my$text=<$fh>;close($fh);$text}sub looks_like_xml {my$textref=shift;my$args=($$textref =~ /^(?:\s*\xEF\xBB\xBF)?\s*<\?xml(\s+\S.*)\?>/s)[0];if (!$args){return}return$args}sub xml_decl_encoding {my$textref=shift;return unless defined $$textref;my$args=looks_like_xml($textref)or return;my$getcode=($args =~ /\s+encoding=(".*?"|'.*?')/)[0]or return;$getcode =~ s/^['"]//;$getcode =~ s/['"]$//;$getcode}sub encode_from_to {my$self=shift;my$txtref=shift or return;my$from=shift or return;my$to=shift or return;unless (defined$Encode::EUCJPMS::VERSION){$from='EUC-JP' if ($from =~ /\beuc-?jp-?(win|ms)$/i);$to='EUC-JP' if ($to =~ /\beuc-?jp-?(win|ms)$/i)}my$RE_IS_UTF8=qr/^utf-?8$/i;if ($from =~ $RE_IS_UTF8){$$txtref =~ s/^\xEF\xBB\xBF//s}my$setflag=$self->{utf8_flag}if exists$self->{utf8_flag};if (!$ALLOW_UTF8_FLAG && $setflag){return$self->die("Perl 5.8.1 is required for utf8_flag: $]")}if ($USE_ENCODE_PM){&load_encode();my$encver=($Encode::VERSION =~ /^([\d\.]+)/)[0];my$check=($encver < 2.13)? 0x400 : Encode::FB_XMLCREF();my$encfrom=Encode::find_encoding($from)if$from;return$self->die("Unknown encoding: $from")unless ref$encfrom;my$encto=Encode::find_encoding($to)if$to;return$self->die("Unknown encoding: $to")unless ref$encto;if ($ALLOW_UTF8_FLAG && utf8::is_utf8($$txtref)){if ($to =~ $RE_IS_UTF8){}else {$$txtref=$encto->encode($$txtref,$check)}}else {$$txtref=$encfrom->decode($$txtref);if ($to =~ $RE_IS_UTF8 && $setflag){}else {$$txtref=$encto->encode($$txtref,$check)}}}elsif ((uc($from)eq 'ISO-8859-1' || uc($from)eq 'US-ASCII' || uc($from)eq 'LATIN-1')&& uc($to)eq 'UTF-8'){&latin1_to_utf8($txtref)}else {my$jfrom=&get_jcode_name($from);my$jto=&get_jcode_name($to);return$to if (uc($jfrom)eq uc($jto));if ($jfrom && $jto){&load_jcode();if (defined$Jcode::VERSION){Jcode::convert($txtref,$jto,$jfrom)}else {return$self->die("Jcode.pm is required: $from to $to")}}else {return$self->die("Encode.pm is required: $from to $to")}}$to}sub load_jcode {return if defined$Jcode::VERSION;local $@;eval {require Jcode}}sub load_encode {return if defined$Encode::VERSION;local $@;eval {require Encode}}sub latin1_to_utf8 {my$strref=shift;$$strref =~ s{
          ([\x80-\xFF])
      }{
          pack( 'C2' => 0xC0|(ord($1)>>6),0x80|(ord($1)&0x3F) )
      }exg}sub get_jcode_name {my$src=shift;my$dst;if ($src =~ /^utf-?8$/i){$dst='utf8'}elsif ($src =~ /^euc.*jp(-?(win|ms))?$/i){$dst='euc'}elsif ($src =~ /^(shift.*jis|cp932|windows-31j)$/i){$dst='sjis'}elsif ($src =~ /^iso-2022-jp/){$dst='jis'}$dst}sub xml_escape {my$str=shift;return '' unless defined$str;$str =~ s{
          ([\x00-\x08\x0B\x0C\x0E-\x1F\x7F])
      }{
          sprintf( '&#%d;', ord($1) );
      }gex;$str =~ s/&(?!#(\d+;|x[\dA-Fa-f]+;))/&amp;/g;$str =~ s/</&lt;/g;$str =~ s/>/&gt;/g;$str =~ s/'/&apos;/g;$str =~ s/"/&quot;/g;$str}sub xml_unescape {my$str=shift;my$map={qw(quot " lt < gt > apos ' amp &)};$str =~ s{
          (&(?:\#(\d{1,3})|\#x([0-9a-fA-F]{1,2})|(quot|lt|gt|apos|amp));)
      }{
          $4 ? $map->{$4} : &code_to_ascii( $3 ? hex($3) : $2, $1 );
      }gex;$str}sub xml_deref_octet {my$str=shift;my$map={qw(quot " lt < gt > apos ' amp &)};$str =~ s{
          (&(?:\#(\d{1,7})|\#x([0-9a-fA-F]{1,6})|(quot|lt|gt|apos|amp));)
      }{
          $4 ? $map->{$4} : &code_to_utf8( $3 ? hex($3) : $2, $1 );
      }gex;$str}sub xml_deref_string {my$str=shift;my$map={qw(quot " lt < gt > apos ' amp &)};$str =~ s{
          (&(?:\#(\d{1,7})|\#x([0-9a-fA-F]{1,6})|(quot|lt|gt|apos|amp));)
      }{
          $4 ? $map->{$4} : pack( U => $3 ? hex($3) : $2 );
      }gex;$str}sub code_to_ascii {my$code=shift;if ($code <= 0x007F){return pack(C=>$code)}return shift if scalar @_;sprintf('&#%d;',$code)}sub code_to_utf8 {my$code=shift;if ($code <= 0x007F){return pack(C=>$code)}elsif ($code <= 0x07FF){return pack(C2=>0xC0|($code>>6),0x80|($code&0x3F))}elsif ($code <= 0xFFFF){return pack(C3=>0xE0|($code>>12),0x80|(($code>>6)&0x3F),0x80|($code&0x3F))}elsif ($code <= 0x10FFFF){return pack(C4=>0xF0|($code>>18),0x80|(($code>>12)&0x3F),0x80|(($code>>6)&0x3F),0x80|($code&0x3F))}return shift if scalar @_;sprintf('&#x%04X;',$code)}1;
XML_TREEPP

s/^  //mg for values %fatpacked;

my $class = 'FatPacked::'.(0+\%fatpacked);
no strict 'refs';
*{"${class}::files"} = sub { keys %{$_[0]} };

if ($] < 5.008) {
  *{"${class}::INC"} = sub {
     if (my $fat = $_[0]{$_[1]}) {
       return sub {
         return 0 unless length $fat;
         $fat =~ s/^([^\n]*\n?)//;
         $_ = $1;
         return 1;
       };
     }
     return;
  };
}

else {
  *{"${class}::INC"} = sub {
    if (my $fat = $_[0]{$_[1]}) {
      open my $fh, '<', \$fat
        or die "FatPacker error loading $_[1] (could be a perl installation issue?)";
      return $fh;
    }
    return;
  };
}

unshift @INC, bless \%fatpacked, $class;
  } # END OF FATPACK CODE

