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

# This module is responsible for enforcing restrictions placed on
# source/destination IP addresses and ports of the SSH connection.

package Mash::Rule::Connection;

use strict;
use Socket;

use Mash::Policy;

our $VERSION = 0.17;

# return true if given args and opts are authorized according to
# conditions specified in connection definition, false otherwise
sub allow {
    my $proto = shift;
    my $conf_hash = shift;
    my $argv = shift;
    my $opts = shift;

    my $ssh = $ENV{SSH_CONNECTION};
    return Mash::Policy->error($conf_hash->{error}, 0) if (!defined $ssh);
    # strip out IPv6 info in older versions of SSH
    $ssh =~ s/:\S*://g;
    my @conn = split(/\s+/, $ssh);
    return Mash::Policy->error($conf_hash->{error}, 0) if (scalar(@conn) != 4);

    # define user facing names for each connection field
    my %conn = (
        src_host => fqdn($conn[0]),
        src_ip => $conn[0],
        src_port => $conn[1],
        dst_host => fqdn($conn[2]),
        dst_ip => $conn[2],
        dst_port => $conn[3],
    );

    # given connection field must exactly match given value
    foreach my $key (keys %{$conf_hash}) {
        next if ($key eq 'regex' || $key =~ /publickey/);
        return Mash::Policy->error($conf_hash->{error}, 0)
            if ($conn{$key} ne $conf_hash->{$key});
    }

    # given connection field must match given regex
    my $res = $conf_hash->{regex};
    if (defined $res) {
        $res = [$res] if (ref $res ne 'ARRAY');
        foreach my $re (@{$res}) {
            my $content = $re->{content};
            my $text = $conn{$re->{name}};
            return Mash::Policy->error($conf_hash->{error}, 0)
                if ($text !~ qr/$content/s);
        }
    }

    return 1;
}

# return fully-qualified version of given host name
sub fqdn {
    my $host = shift;
    if ($host =~ /^\d+\.\d+\.\d+\.\d+$/) {
        # host name is ip address so resolve via dns
        my $name = gethostbyaddr(inet_aton($host), AF_INET);
        return $name if ($name);
    } else {
        # use official host name
        my @cols = gethostbyname($host);
        return $cols[0] if ($cols[0]);
    }
    # return original host name if unable to get fully-qualified version
    return $host;
}

1;

