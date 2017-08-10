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

# This module is responsible for parsing and authorizing a set of proxies
# that comprise a policy.

package Mash::Policy;

use strict;
use Storable qw(dclone);

use Mash::Proxy;

our $VERSION = 0.15;

our $Error = undef;
our $Error_Priority = -1;

# set globally highest priority error message and return given value
sub error {
    my $proto = shift;
    my $err_hash = shift;
    my $return = shift;
    return $return if (!defined $err_hash);
    my ($err, $prio);
    if (ref $err_hash eq 'HASH') {
        # priority has been explicitly set
        $err = $err_hash->{content};
        $prio = $err_hash->{priority};
    } else {
        # use default priority
        $err = $err_hash;
        $prio = 0;
    }
    if (defined $prio && defined $err && $prio > $Error_Priority) {
        # a higher priority error has been found so change error message
        $Error = $err;
        $Error_Priority = $prio;
    }
    return $return;
}

# initialize new policy instance
sub new {
    my $proto = shift;
    my $self = {};
    $self->{conf} = shift;
    $self->{parsers} = shift;
    my $class = ref($proto) || $proto;
    bless($self, $class);
    return $self;
}

# return true if given args and opts are authorized according to rules
# specified in policy definition, false otherwise
sub allow {
    my $self = shift;
    my $argv = shift;
    my $opts = shift;

    # process any rules that apply to the whole policy
    foreach my $rule_name (keys %{$self->{conf}}) {
        # ignore <proxies/> section
        next if (lc($rule_name) eq 'proxies');
        if ($rule_name =~ /(\w+)/) {
            # use rule module corresponding to name
            my $module = "Mash::Rule::" . ucfirst(lc($1));
            # disallow policy if corresponding module not found
            eval "require $module" or return 0;
            my $rule_hash = $self->{conf}->{$rule_name};
            return 0 if (!$module->allow($rule_hash, $argv, $opts));
        } else {
            # disallow policy if invalid rule name specified
            return 0;
        }
    }
    return 1;
}

# return command rewritten by proxy if authorized, undef otherwise
sub parse {
    my $self = shift;

    my $rewrite = undef;
    return undef if (!$self->allow({}, {}));
    my $pcmds = $self->{conf}->{proxies};
    foreach my $pcmd_name (keys %{$pcmds}) {
        my $pcmd_hashes = $pcmds->{$pcmd_name};
        $pcmd_hashes = [$pcmd_hashes] if (ref $pcmd_hashes ne 'ARRAY');
        foreach (@{$pcmd_hashes}) {
            # clone proxy hash so changes will be localized
            my $pcmd_hash = dclone $_;
            if ($pcmd_name =~ /(\w+)/) {
                $pcmd_name = $1;
                # use proxy module corresponding to name
                my $module = "Mash::Proxy::" . ucfirst(lc($pcmd_name));
                # ignore policy if corresponding module not found
                eval "require $module" or return undef;
                $pcmd_hash->{name} = $pcmd_name;
                my $pcmd = $module->new($pcmd_hash, $self->{parsers});
                # continue parsing in proxy module
                $rewrite = $pcmd->parse;
                last if (defined $rewrite);
            } else {
                # ignore policy if invalid proxy name specified
                return undef;
            }
        }
        last if (defined $rewrite);
    }
    return $rewrite;
}

1;

