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

# This module is a parent class of different proxy types that are
# responsible for parsing and authorizing a set of commands.

package Mash::Proxy;

use strict;
use Storable qw(dclone);

use Mash::Command;

our $VERSION = 0.31;

# initialize new proxy instance
sub new {
    my $proto = shift;
    my $self = {};
    $self->{conf} = shift;
    $self->{parsers} = shift;
    my $class = ref($proto) || $proto;

    # untaint directory
    return undef if (!defined $self->{conf}->{directory});
    if ($self->{conf}->{directory} =~ /^([[:print:]]+)$/) {
        $self->{directory} = $1;
    } else {
        return undef;
    }
    delete $self->{conf}->{directory};

    # untaint name
    return undef if (!defined $self->{conf}->{name});
    if ($self->{conf}->{name} =~ /^([\w.-]+)$/) {
        $self->{name} = $1;
    } else {
        return undef;
    }
    $self->{path} = $self->{directory} . "/" . $self->{name};
    delete $self->{conf}->{name};

    bless($self, $class);
    return $self;
}

# return true if given args and opts are authorized according to rules
# specified in proxy definition, false otherwise
sub allow {
    my $self = shift;
    my $argv = shift;
    my $opts = shift;

    foreach my $rule_name (keys %{$self->{conf}}) {
        # ignore <commands/> section
        next if (lc($rule_name) eq 'commands');
        if ($rule_name =~ /(\w+)/) {
            # use rule module corresponding to name
            my $module = "Mash::Rule::" . ucfirst(lc($1));
            # disallow proxy if corresponding module not found
            eval "require $module" or return 0;
            my $rule_hash = $self->{conf}->{$rule_name};
            return 0 if (!$module->allow($rule_hash, $argv, $opts));
        } else {
            return 0;
        }
    }
    return 1;
}

# return command rewritten by command/parser if authorized, undef otherwise
sub parse {
    my $self = shift;

    my $rewrite = undef;
    foreach my $cmd_name (keys %{$self->{conf}->{commands}}) {
        my $cmd_hashes = $self->{conf}->{commands}->{$cmd_name};
        $cmd_hashes = [$cmd_hashes] if (ref $cmd_hashes ne 'ARRAY');
        foreach (@{$cmd_hashes}) {
            # clone command hash so changes will be localized
            my $cmd_hash = dclone $_;
            if ($cmd_name =~ /([\w.-]+)/) {
                $cmd_name = $1;
                # search for custom parser module corresponding to name
                my $module = "Mash::Command::" . ucfirst(lc($cmd_name));
                if ($cmd_name =~ /[.-]/ || !eval "require $module") {
                    # use generic parser for commands without custom parser
                    $module = "Mash::Command";
                    my $parser_hash = $self->{parsers}->{$cmd_name};
                    if (defined $parser_hash) {
                        # clone parser hash so changes will be localized
                        $parser_hash = dclone $parser_hash;
                        foreach my $ckey (keys %{$cmd_hash}) {
                            # parser elements not in cmd hash stay the same
                            my $cval = $cmd_hash->{$ckey};
                            my $pval = $parser_hash->{$ckey};
                            if (ref $cval eq 'HASH' && ref $pval eq 'HASH') {
                                # cmd/parser hashes both specify same element
                                foreach my $psubkey (keys %{$pval}) {
                                    # cmd subelements not in parser subhash
                                    # stay the same
                                    my $psubval = $pval->{$psubkey};
                                    my $csubval = $cval->{$psubkey};
                                    if (defined $psubval && defined $csubval) {
                                        # merge cmd/parser subhashes
                                        $psubval = [$psubval]
                                            if (ref $psubval ne 'ARRAY');
                                        $csubval = [$csubval]
                                            if (ref $csubval ne 'ARRAY');
                                        push(@{$csubval}, @{$psubval});
                                    } elsif (defined $psubval) {
                                        # use parser subhash value
                                        $csubval = $psubval;
                                    }
                                    # reset cmd subhash value in case modified
                                    $cval->{$psubkey} = $csubval;
                                }
                            }
                            # use (merged if applicable) cmd hash value
                            $parser_hash->{$ckey} = $cval;
                        }
                        $cmd_hash = $parser_hash;
                    }
                }
                $cmd_hash->{name} = $cmd_name if (!defined $cmd_hash->{name});
                my $cmd = $module->new($cmd_hash);
                $rewrite = $cmd->parse;
                last if (defined $rewrite);
            } else {
                return undef;
            }
        }
        last if (defined $rewrite);
    }
    return $rewrite;
}

1;

