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

# This module is responsible for enforcing restrictions placed on the
# number and values of command arguments and/or for dynamically modifying
# argument values.

package Mash::Rule::Argument;

use strict;
use Text::ParseWords;

use Mash::Policy;

our $VERSION = 0.21;

# return true if given args and opts are authorized according to
# conditions specified in argument definition, false otherwise
sub allow {
    my $proto = shift;
    my $conf_hash = shift;
    my $argv = shift;
    my $opts = shift;

    # argument at given index must exactly match given value
    my $values = $conf_hash->{value};
    if (defined $values) {
        $values = [$values] if (ref $values ne 'ARRAY');
        foreach my $value (@{$values}) {
            return Mash::Policy->error($conf_hash->{error}, 0)
                if ($argv->[$value->{index}] ne $value->{content});
        }
    }

    # with index, argument at given index must match given regex, OR
    # without index, all arguments in single string must match given regex
    my $res = $conf_hash->{regex};
    if (defined $res) {
        $res = [$res] if (ref $res ne 'ARRAY');
        foreach my $re (@{$res}) {
            my ($content, $text);
            if (ref $re eq 'HASH') {
                $content = $re->{content};
                $text = $argv->[$re->{index}];
                # ignore regex if argument not defined
                next if (!defined $text);
            } else {
                # no index given so join arguments with newlines
                $content = $re;
                foreach my $val (@{$argv}) {
                    $val =~ s/\n//g;
                    $text .= "$val\n";
                }
            }
            return Mash::Policy->error($conf_hash->{error}, 0)
                if ($text !~ qr/$content/s);
        }
    }

    # argument count must relate to given value as defined
    my $counts = $conf_hash->{count};
    if (defined $counts) {
        $counts = [$counts] if (ref $counts ne 'ARRAY');
        foreach my $count (@{$counts}) {
            my $test = 1;
            if (ref $count eq 'HASH') {
                # an operator is defined
                if ($count->{op} eq 'lt') {
                    $test = (scalar(@{$argv}) < $count->{content});
                } elsif ($count->{op} eq 'le') {
                    $test = (scalar(@{$argv}) <= $count->{content});
                } elsif ($count->{op} eq 'gt') {
                    $test = (scalar(@{$argv}) > $count->{content});
                } elsif ($count->{op} eq 'ge') {
                    $test = (scalar(@{$argv}) >= $count->{content});
                } else {
                    $test = 0;
                }
            } else {
                # default operator is equals
                $test = ($count == scalar(@{$argv}));
            }
            return Mash::Policy->error($conf_hash->{error}, 0) if (!$test);
        }
    }

    # with index and regex, replace portion of argument at given index
    # matching given regex with given value, OR without either, replace
    # entire argument list with new one derived from given value
    my $replaces = $conf_hash->{replace};
    if (defined $replaces) {
        $replaces = [$replaces] if (ref $replaces ne 'ARRAY');
        foreach my $replace (@{$replaces}) {
            if (ref $replace ne 'HASH') {
                # replace entire argument list with given value
                splice(@{$argv});
                # split replacement string on whitespace
                push(@{$argv}, quotewords('\s+', 1, $replace));
            } else {
                # untaint regex and content
                if ($replace->{content} =~ /^([[:print:]]*)$/) {
                    $replace->{content} = $1;
                } else {
                    return Mash::Policy->error($conf_hash->{error}, 0);
                }
                if (!defined $replace->{regex}) {
                    $replace->{regex} = ".+";
                } elsif ($replace->{regex} =~ /^([[:print:]]+)$/) {
                    $replace->{regex} = $1;
                } else {
                    return Mash::Policy->error($conf_hash->{error}, 0);
                }
                my ($re, $text) = ($replace->{regex}, $replace->{content});
                # replace regex with given value
                $argv->[$replace->{index}] =~ s/$re/$text/g;
            }
        }
    }

    # insert a forced argument of a given value at a given index
    my $inserts = $conf_hash->{insert};
    if (defined $inserts) {
        $inserts = [$inserts] if (ref $inserts ne 'ARRAY');
        foreach my $insert (@{$inserts}) {
            # untaint inserted content
            if ($insert->{content} =~ /^([[:print:]]+)$/) {
                $insert->{content} = $1;
            } else {
                return Mash::Policy->error($conf_hash->{error}, 0);
            }
            splice(@{$argv}, $insert->{index}, 0, $insert->{content});
        }
    }

    return 1;
}

1;

