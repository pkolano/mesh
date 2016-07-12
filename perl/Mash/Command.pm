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

# This module is responsible for parsing and authorizing a specific
# command while constructing the appropriate command line to be executed.

package Mash::Command;

use strict;
use Getopt::Long qw(:config bundling no_ignore_case require_order);
use Getopt::Std;
use Tie::IxHash;

our $VERSION = 0.35;

# initialize new command instance
sub new {
    my $proto = shift;
    my $conf_hash = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{conf} = $conf_hash;

    if ($self->{conf}->{getopt}) {
        $self->{getopt} = $self->{conf}->{getopt};
        delete $self->{conf}->{getopt};
    }

    if (defined $self->{conf}->{name_regex}) {
        # untaint name_regex
        if ($self->{conf}->{name_regex} =~ /^([[:print:]]+)$/) {
            $self->{name_regex} = $1;
        } else {
            return undef;
        }
        delete $self->{conf}->{name_regex};
    } else {
        # untaint directory
        return undef if (!defined $self->{conf}->{directory});
        if ($self->{conf}->{directory} =~ /^([[:print:]]+)$/) {
            $self->{directory} = $1;
        } else {
            return undef;
        }
        delete $self->{conf}->{directory};
    }

    # untaint name
    return undef if (!defined $self->{conf}->{name});
    if ($self->{conf}->{name} =~ /^([\w+.-]+)$/) {
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
# specified in command definition, false otherwise
sub allow {
    my $self = shift;
    my $argv = shift;
    my $opts = shift;

    foreach my $rule_name (keys %{$self->{conf}}) {
        if ($rule_name =~ /(\w+)/) {
            # use rule module corresponding to name
            my $module = "Mash::Rule::" . ucfirst(lc($1));
            # disallow proxy if corresponding module not found
            eval "require $module" or return 0;
            return 0 if (!$module->allow($self->{conf}->{$rule_name}, $argv, $opts));
        } else {
            return 0;
        }
    }
    return 1;
}

# return command rewritten from @ARGV if authorized, undef otherwise
sub parse {
    my $self = shift;

    # abort if first argument does not match name or path
    return undef if (scalar(@ARGV) == 0);
    if (defined $self->{name_regex}) {
        return undef if ($ARGV[0] !~ qr/$self->{name_regex}/);
    } elsif ($ARGV[0] ne $self->{path} && $ARGV[0] ne $self->{name}) {
        return undef;
    }
    my @argv_save = @ARGV;
    my $argv0 = shift @ARGV;

    # parse options if getopt defined and abort on parse error
    my $longopt = 0;
    my %opts = ();
    # retain option order
    tie(%opts, 'Tie::IxHash');
    # disable warnings
    $SIG{__WARN__} = sub {};
    if ($self->{getopt} =~ /[,=|!+]/) {
        # use Getopt::Long parsing if getopt specification contains
        # items specific to Getopt::Long
        GetOptions(\%opts, split(/,/, $self->{getopt})) or return undef;
        $longopt = 1;
    } elsif ($self->{getopt}) {
        # use Getopt::Std parsing otherwise
        getopts($self->{getopt}, \%opts) or return undef;
    }
    # enable warnings
    delete $SIG{__WARN__};

    my @argv_new = @ARGV;
    @ARGV = @argv_save;

    if (defined $self->{name_regex}) {
        # untaint saved first argument
        if ($argv0 =~ /^([[:print:]]+)$/) {
            $argv0 = $1;
        } else {
            return undef;
        }
        # prepend original path to arguments
        unshift(@argv_new, $argv0);
    } else {
        # prepend absolute path to arguments
        unshift(@argv_new, $self->{path});
    }

    # abort if not allowed
    return undef if (!$self->allow(\@argv_new, \%opts));

    # begin command rewrite with absolute path
    my $rewrite = [shift @argv_new];

    # untaint and add original options
    foreach my $opt (keys %opts) {
        my @vals = ref $opts{$opt} ? @{$opts{$opt}} : ($opts{$opt});
        foreach my $val (@vals) {
            push(@{$rewrite}, (length $opt > 1 ? "--" : "-") . $opt);
            if ($longopt &&
                    # Getopt::Long definition specifies option takes value
                    $self->{getopt} =~ /(^|[,|])\Q$opt\E(\|[^,]*)?[=:]/ ||
                    # Getopt::Std definition specifies option takes value
                    !$longopt && $self->{getopt} =~ /\Q$opt\E:/) {
                if ($val =~ /^([[:print:]]*)$/) {
                    push(@{$rewrite}, $1);
                } else {
                    return undef;
                }
            } elsif ($longopt &&
                    # Getopt::Long definition specifies option incrementing
                    $self->{getopt} =~ /(^|[,|])\Q$opt\E(\|[^,]*)?\+/) {
                # add appropriate number of options
                for (my $i = 1; $i < $opts{$opt}; $i++) {
                    push(@{$rewrite}, (length $opt > 1 ? "--" : "-") . $opt);
                }
            }
        }
    }

    # untaint and add original non-option arguments
    foreach my $arg (@argv_new) {
        if ($arg =~ /^([[:print:]]*)$/) {
            push(@{$rewrite}, $1);
        } else {
            return undef;
        }
    }

    return $rewrite;
}

1;

