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

# This module is responsible for enforcing restrictions placed on the
# existence and values of command options and/or for dynamically modifying
# option values.

package Mash::Rule::Option;

use strict;

use Mash::Policy;

our $VERSION = 0.16;

# return true if given args and opts are authorized according to
# conditions specified in option definition, false otherwise
sub allow {
    my $proto = shift;
    my $conf_hash = shift;
    my $argv = shift;
    my $opts = shift;

    # option with given name must be set
    my $sets = $conf_hash->{set};
    if (defined $sets) {
        $sets = [$sets] if (ref $sets ne 'ARRAY');
        foreach my $set (@{$sets}) {
            return Mash::Policy->error($conf_hash->{error}, 0)
                if (!$opts->{$set->{name}});
        }
    }

    # option with given name must not be set
    my $unsets = $conf_hash->{unset};
    if (defined $unsets) {
        $unsets = [$unsets] if (ref $unsets ne 'ARRAY');
        foreach my $unset (@{$unsets}) {
            return Mash::Policy->error($conf_hash->{error}, 0)
                if ($opts->{$unset->{name}});
        }
    }

    # option with given name must exactly match given value
    my $values = $conf_hash->{value};
    if (defined $values) {
        $values = [$values] if (ref $values ne 'ARRAY');
        foreach my $value (@{$values}) {
            my $texts = $opts->{$value->{name}};
            $texts = [$texts] if (ref $texts ne 'ARRAY');
            foreach my $text (@{$texts}) {
                return Mash::Policy->error($conf_hash->{error}, 0)
                    if ($text ne $value->{content});
            }
        }
    }

    # with name, option with given name must match given regex, OR
    # without name, all options in single string must match given regex
    my $res = $conf_hash->{regex};
    if (defined $res) {
        $res = [$res] if (ref $res ne 'ARRAY');
        foreach my $re (@{$res}) {
            my ($content, $texts);
            if (ref $re eq 'HASH') {
                $content = $re->{content};
                $texts = $opts->{$re->{name}};
                # ignore regex if option not defined
                next if (!defined $texts);
            } else {
                # no name given so join options key value pairs with newlines
                $content = $re;
                foreach my $key (keys %{$opts}) {
                    my $jtexts = $opts->{$key};
                    $jtexts = [$jtexts] if (ref $jtexts ne 'ARRAY');
                    foreach my $jtext (@{$jtexts}) {
                        $jtext =~ s/\n//g;
                        $texts .= "$key=$jtext\n";
                    }
                }
            }
            $texts = [$texts] if (ref $texts ne 'ARRAY');
            foreach my $text (@{$texts}) {
                return Mash::Policy->error($conf_hash->{error}, 0)
                    if ($text !~ qr/$content/s);
            }
        }
    }

    # force option with given name to have given value
    my $forces = $conf_hash->{force};
    if (defined $forces) {
        $forces = [$forces] if (ref $forces ne 'ARRAY');
        foreach my $force (@{$forces}) {
            # untaint forced name and content
            if ($force->{name} =~ /^([[:print:]]+)$/) {
                $force->{name} = $1;
            } else {
                return Mash::Policy->error($conf_hash->{error}, 0);
            }
            if ($force->{content} =~ /^([[:print:]]*)$/) {
                $force->{content} = $1;
            } else {
                return Mash::Policy->error($conf_hash->{error}, 0);
            }
            $opts->{$force->{name}} = $force->{content};
        }
    }

    return 1;
}

1;

