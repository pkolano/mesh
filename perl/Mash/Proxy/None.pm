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

# This module is responsible for parsing and authorizing a set of commands
# that are to be executed on the local host while expanding any globbed
# pathnames and preserving the appropriate parts of the environment.

package Mash::Proxy::None;

use strict;
use File::Glob qw(:glob);

use Mash::Proxy;

our @ISA = qw(Mash::Proxy);
our $VERSION = 0.19;

# initialize new null proxy instance
sub new {
    my $proto = shift;
    my $conf_hash = shift;
    my $parser_hash = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    # set directory to dummy value
    $conf_hash->{directory} = "/";
    bless($self, $class);
    $self = $self->SUPER::new($conf_hash, $parser_hash);
    return $self;
}

# return command rewritten from parent proxy if authorized, undef otherwise
sub parse {
    my $self = shift;

    my @argv_save = @ARGV;

    return undef if (!$self->allow(\@ARGV, {}));

    # expand globbed pathnames
    @ARGV = ();
    foreach (@argv_save) {
        foreach (bsd_glob($_,
                GLOB_BRACE | GLOB_NOCHECK | GLOB_QUOTE | GLOB_TILDE)) {
            push(@ARGV, $1) if (/([[:print:]]+)/);
        }
    }

    # parse commands
    my $rewrite = $self->SUPER::parse;
    @ARGV = @argv_save;
    return undef if (!defined $rewrite);

    # keep specific environment settings
    %ENV = (
        # keep home since many shell scripts assume its existence
        HOME => $ENV{HOME},
        # needed for some mesh-* commands and rules in mash subshells
        MESH_PUBKEY => $ENV{MESH_PUBKEY},
        # needed to retain access to ssh agent during key generation
        SSH_AUTH_SOCK => $ENV{SSH_AUTH_SOCK},
        # needed for rules in mash subshells
        SSH_CONNECTION => $ENV{SSH_CONNECTION},
        # needed for forced command processing
        SSH_ORIGINAL_COMMAND => $ENV{SSH_ORIGINAL_COMMAND},
        # keep terminal settings for local commands that require one
        TERM => $ENV{TERM},
    );
    return $rewrite;
}

1;

