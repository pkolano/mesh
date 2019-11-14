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

# This module is responsible for parsing and authorizing a set of
# commands that are to be executed on a remote host while constructing the
# appropriate ssh command and preserving the appropriate parts of the
# environment.

package Mash::Proxy::Ssh;

use strict;
use Getopt::Long qw(:config bundling no_ignore_case require_order);
use Text::ParseWords;

use Mash::Proxy;

our @ISA = qw(Mash::Proxy);
our $VERSION = 0.41;

# initialize new ssh proxy instance
sub new {
    my $proto = shift;
    my $conf_hash = shift;
    my $parser_hash = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);
    $self = $self->SUPER::new($conf_hash, $parser_hash);
    return undef if (!defined $self);

    # untaint port
    return undef if (!defined $self->{conf}->{port});
    if ($self->{conf}->{port} =~ /^(\d+)$/) {
        $self->{port} = $1;
    } else {
        return undef;
    }
    delete $self->{conf}->{port};

    if (exists $self->{conf}->{forward_agent}) {
        $self->{forward_agent} = 1;
        delete $self->{conf}->{forward_agent};
    }
    if (exists $self->{conf}->{forward_x11}) {
        $self->{forward_x11} = 1;
        delete $self->{conf}->{forward_x11};
    }
    if (exists $self->{conf}->{login}) {
        $self->{login} = 1;
        delete $self->{conf}->{login};
    }

    return $self;
}

# return command rewritten from @ARGV if authorized, undef otherwise
sub parse {
    my $self = shift;

    # abort if first argument does not match name or path
    return undef if (scalar(@ARGV) == 0 ||
        $ARGV[0] ne $self->{path} && $ARGV[0] ne $self->{name});
    my @argv_save = @ARGV;
    shift @ARGV;

    # disable warnings
    $SIG{__WARN__} = sub {};
    # parse options
    my %opts = ();
    my $rc = GetOptions(\%opts,
        "a", "f", "g", "k", "n", "q", "s", "t", "v", "x",
        "A", "C", "N", "T", "X",
        "1", "2", "4", "6",
        "p=i", "D=i",
        "b=s", "c=s", "e=s", "i=s", "l=s", "m=s", "F=s", "L=s", "R=s",
        "o=s" => sub {
            # handle all -oKey=Val options of ssh
            my ($key, $val) = split(/=|\s+/, $_[1]);
            $val = shift @ARGV if (!defined $val);
            $opts{$_[0] . lc($key)} = $val;
        }
    );
    # enable warnings
    delete $SIG{__WARN__};
    my @argv_new = @ARGV;
    @ARGV = @argv_save;

    # prepend absolute path to arguments
    unshift(@argv_new, $self->{path});

    # abort on parse error
    return undef if (!$rc || scalar(@argv_new) == 0);
    return undef if (!$self->allow(\@argv_new, \%opts));

    # begin command rewrite with absolute path
    my $rewrite = [shift @argv_new];

    my $host = shift @argv_new;
    # first argument must be in form user@host or just host
    if ($host =~ /^(\w+@)?([\w-]+(\.[\w-]+)*)$/) {
        $host = $2;
    } else {
        return undef;
    }

    # add port
    push(@{$rewrite}, ('-p', $self->{port}));
    # disable GSS forwarding
    push(@{$rewrite}, '-k');
    if (!$self->{login}) {
        # force pubkey authentication
        push(@{$rewrite}, ('-oBatchMode=yes'));
        push(@{$rewrite}, ('-oPreferredAuthentications=publickey'));
    }
    # forward agent if specified
    if ($self->{forward_agent}) {
        push(@{$rewrite}, "-A");
    } else {
        push(@{$rewrite}, "-a");
    }
    # forward X11 if specified
    if ($self->{forward_x11}) {
        push(@{$rewrite}, "-X");
    } else {
        push(@{$rewrite}, "-x");
    }
    # add original options that are allowed
    foreach ("a", "q", "x") {
        push(@{$rewrite}, "-$_") if ($opts{$_});
    }
    # add original non-option arguments
    push(@{$rewrite}, $host);

    if (scalar(@argv_new) == 1 &&
            # batched commands must be explicitly quoted
            $argv_new[0] =~ /^['"](.*)['"]$/) {
        # support commands batched via ';'
        my $cmd = $1;
        $cmd =~ s/\s+$//;
        # split batch into list of individual commands
        my @batch = quotewords('\s*;\s*', 1, $cmd);
        $batch[0] =~ s/^\s+//;
        # further split each command into list of arguments
        my @arg_lists = nested_quotewords('\s+', 1, @batch);
        foreach my $arg_list (@arg_lists) {
            foreach (@{$arg_list}) {
                # disallow ; on its own
                return undef if (grep(/^;$/, shellwords($_)));
            }
            # parse each argument list using parent parse
            @ARGV = @{$arg_list};
            my $crewrite = $self->SUPER::parse;
            @ARGV = @argv_save;
            return undef if (!defined $crewrite);
            push(@{$rewrite}, @{$crewrite});
            # retain ';' for mess execution on remote host
            push(@{$rewrite}, ";");
        }
        # remove final ';'
        pop(@{$rewrite}) if ($rewrite->[-1] eq ';');
    } elsif (scalar(@argv_new) >= 1 || !$self->{login}) {
        foreach (@argv_new) {
            # disallow ; on its own
            return undef if (grep(/^;$/, shellwords($_)));
        }
        # parse argument list using parent parse
        @ARGV = @argv_new;
        my $crewrite = $self->SUPER::parse;
        @ARGV = @argv_save;
        return undef if (!defined $crewrite);
        push(@{$rewrite}, @{$crewrite});
    }

    # keep specific environment settings
    %ENV = (
        # needed to retain access to ssh agent during remote commands
        SSH_AUTH_SOCK => $ENV{SSH_AUTH_SOCK},
    );
    return $rewrite;
}

1;

