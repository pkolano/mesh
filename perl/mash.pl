#!/usr/bin/perl -T
#
# Copyright (C) 2006-2009 United States Government as represented by the
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
use XML::Simple;

our $VERSION = 0.43;

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
    return if (!$config->{syslog});
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
$config = XMLin($xml, KeyAttr => [], NormalizeSpace => 2) or mydie;

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

