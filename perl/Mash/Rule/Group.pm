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
# group of the user invoking the command.

package Mash::Rule::Group;

use strict;

use Mash::Policy;

our $VERSION = 0.15;

# return true if given args and opts are authorized according to
# conditions specified in group definition, false otherwise
sub allow {
    my $proto = shift;
    my $conf_hash = shift;
    my $argv = shift;
    my $opts = shift;

    # get user name and default group id of invoking user
    my ($user, $ugid) = (getpwuid($<))[0,3];
    # get default group of invoking user
    my $ugroup = getgrgid($ugid);

    # invoking user group must not match any given deny value
    my $denies = $conf_hash->{deny};
    if (defined $denies) {
        $denies = [$denies] if (ref $denies ne 'ARRAY');
        foreach my $deny (@{$denies}) {
            # return false if default group matches given group
            return Mash::Policy->error($conf_hash->{error}, 0)
                if ($deny->{$ugroup} || $deny->{"gid_$ugid"});
            foreach my $group (keys(%{$deny})) {
                my $members;
                # get members of given group
                if ($group =~ /^gid_(\d+)$/) {
                    $members = (getgrgid($1))[3];
                } else {
                    $members = (getgrnam($group))[3];
                }
                # return false if user a member of given group
                return Mash::Policy->error($conf_hash->{error}, 0)
                    if ($members =~ /(^|\s)\Q$user\E($|\s)/);
            }
        }
    }

    # invoking user group must match a given allow value
    my $allows = $conf_hash->{allow};
    if (defined $allows) {
        $allows = [$allows] if (ref $allows ne 'ARRAY');
        foreach my $allow (@{$allows}) {
            # return true if default group matches given group
            return 1 if ($allow->{$ugroup} || $allow->{"gid_$ugid"});
            foreach my $group (keys(%{$allow})) {
                my $members;
                # get members of given group
                if ($group =~ /^gid_(\d+)$/) {
                    $members = (getgrgid($1))[3];
                } else {
                    $members = (getgrnam($group))[3];
                }
                # return true if user a member of given group
                return 1 if ($members =~ /(^|\s)\Q$user\E($|\s)/);
            }
        }
        # return false if allow condition defined but user not a member
        return Mash::Policy->error($conf_hash->{error}, 0);
    }

    return 1;
}

1;

