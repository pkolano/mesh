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

# This module is responsible for parsing and authorizing a specific
# command while constructing the appropriate command line to be executed.

package Mash::Command;

use strict;
use Getopt::Long qw(:config bundling no_ignore_case require_order);
use Getopt::Std;
require Tie::IxHash;

our $VERSION = 0.36;

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

# This chunk of stuff was generated by App::FatPacker. To find the original
# file's code, look for the end of this BEGIN block or the string 'FATPACK'
BEGIN {
my %fatpacked;

$fatpacked{"Tie/IxHash.pm"} = '#line '.(1+__LINE__).' "'.__FILE__."\"\n".<<'TIE_IXHASH';
  require 5.005;package Tie::IxHash;use strict;use integer;require Tie::Hash;use vars qw/@ISA $VERSION/;@ISA=qw(Tie::Hash);$VERSION=$VERSION='1.23';sub TIEHASH {my($c)=shift;my($s)=[];$s->[0]={};$s->[1]=[];$s->[2]=[];$s->[3]=0;bless$s,$c;$s->Push(@_)if @_;return$s}sub FETCH {my($s,$k)=(shift,shift);return exists($s->[0]{$k})? $s->[2][$s->[0]{$k}]: undef}sub STORE {my($s,$k,$v)=(shift,shift,shift);if (exists$s->[0]{$k}){my($i)=$s->[0]{$k};$s->[1][$i]=$k;$s->[2][$i]=$v;$s->[0]{$k}=$i}else {push(@{$s->[1]},$k);push(@{$s->[2]},$v);$s->[0]{$k}=$#{$s->[1]}}}sub DELETE {my($s,$k)=(shift,shift);if (exists$s->[0]{$k}){my($i)=$s->[0]{$k};for ($i+1..$#{$s->[1]}){$s->[0]{$s->[1][$_]}--}if ($i==$s->[3]-1){$s->[3]--}delete$s->[0]{$k};splice @{$s->[1]},$i,1;return (splice(@{$s->[2]},$i,1))[0]}return undef}sub EXISTS {exists $_[0]->[0]{$_[1]}}sub FIRSTKEY {$_[0][3]=0;&NEXTKEY}sub NEXTKEY {return $_[0][1][$_[0][3]++ ]if ($_[0][3]<= $#{$_[0][1]});return undef}sub new {TIEHASH(@_)}sub Clear {my$s=shift;$s->[0]={};$s->[1]=[];$s->[2]=[];$s->[3]=0;return}sub Push {my($s)=shift;while (@_){$s->STORE(shift,shift)}return scalar(@{$s->[1]})}sub Push2 {my($s)=shift;$s->Splice($#{$s->[1]}+1,0,@_);return scalar(@{$s->[1]})}sub Pop {my($s)=shift;my($k,$v,$i);$k=pop(@{$s->[1]});$v=pop(@{$s->[2]});if (defined$k){delete$s->[0]{$k};return ($k,$v)}return undef}sub Pop2 {return $_[0]->Splice(-1)}sub Shift {my($s)=shift;my($k,$v,$i);$k=shift(@{$s->[1]});$v=shift(@{$s->[2]});if (defined$k){delete$s->[0]{$k};for (keys %{$s->[0]}){$s->[0]{$_}--}return ($k,$v)}return undef}sub Shift2 {return $_[0]->Splice(0,1)}sub Unshift {my($s)=shift;my($k,$v,@k,@v,$len,$i);while (@_){($k,$v)=(shift,shift);if (exists$s->[0]{$k}){$i=$s->[0]{$k};$s->[1][$i]=$k;$s->[2][$i]=$v;$s->[0]{$k}=$i}else {push(@k,$k);push(@v,$v);$len++}}if (defined$len){for (keys %{$s->[0]}){$s->[0]{$_}+= $len}$i=0;for (@k){$s->[0]{$_}=$i++}unshift(@{$s->[1]},@k);return unshift(@{$s->[2]},@v)}return scalar(@{$s->[1]})}sub Unshift2 {my($s)=shift;$s->Splice(0,0,@_);return scalar(@{$s->[1]})}sub Splice {my($s,$start,$len)=(shift,shift,shift);my($k,$v,@k,@v,@r,$i,$siz);my($end);($start,$end,$len)=$s->_lrange($start,$len);if (defined$start){if ($len > 0){my(@k)=splice(@{$s->[1]},$start,$len);my(@v)=splice(@{$s->[2]},$start,$len);while (@k){$k=shift(@k);delete$s->[0]{$k};push(@r,$k,shift(@v))}for ($start..$#{$s->[1]}){$s->[0]{$s->[1][$_]}-= $len}}while (@_){($k,$v)=(shift,shift);if (exists$s->[0]{$k}){$i=$s->[0]{$k};$s->[1][$i]=$k;$s->[2][$i]=$v;$s->[0]{$k}=$i}else {push(@k,$k);push(@v,$v);$siz++}}if (defined$siz){for ($start..$#{$s->[1]}){$s->[0]{$s->[1][$_]}+= $siz}$i=$start;for (@k){$s->[0]{$_}=$i++}splice(@{$s->[1]},$start,0,@k);splice(@{$s->[2]},$start,0,@v)}}return@r}sub Delete {my($s)=shift;for (@_){$s->DELETE($_)}}sub Replace {my($s)=shift;my($i,$v,$k)=(shift,shift,shift);if (defined$i and $i <= $#{$s->[1]}and $i >= 0){if (defined$k){delete$s->[0]{$s->[1][$i]};$s->DELETE($k);$s->[1][$i]=$k;$s->[2][$i]=$v;$s->[0]{$k}=$i;return$k}else {$s->[2][$i]=$v;return$s->[1][$i]}}return undef}sub _lrange {my($s)=shift;my($offset,$len)=@_;my($start,$end);my($size)=$#{$s->[1]}+1;return undef unless defined$offset;if($offset < 0){$start=$offset + $size;$start=0 if$start < 0}else {($offset > $size)? ($start=$size): ($start=$offset)}if (defined$len){$len=-$len if$len < 0;$len=$size - $start if$len > $size - $start}else {$len=$size - $start}$end=$start + $len - 1;return ($start,$end,$len)}sub Keys {my($s)=shift;return (@_==1 ? $s->[1][$_[0]]: (@_ ? @{$s->[1]}[@_]: @{$s->[1]}))}sub Values {my($s)=shift;return (@_==1 ? $s->[2][$_[0]]: (@_ ? @{$s->[2]}[@_]: @{$s->[2]}))}sub Indices {my($s)=shift;return (@_==1 ? $s->[0]{$_[0]}: @{$s->[0]}{@_})}sub Length {return scalar @{$_[0]->[1]}}sub Reorder {my($s)=shift;my(@k,@v,%x,$i);return unless @_;$i=0;for (@_){if (exists$s->[0]{$_}){push(@k,$_);push(@v,$s->[2][$s->[0]{$_}]);$x{$_}=$i++}}$s->[1]=\@k;$s->[2]=\@v;$s->[0]=\%x;return$s}sub SortByKey {my($s)=shift;$s->Reorder(sort$s->Keys)}sub SortByValue {my($s)=shift;$s->Reorder(sort {$s->FETCH($a)cmp $s->FETCH($b)}$s->Keys)}1;
TIE_IXHASH

s/^  //mg for values %fatpacked;

my $class = 'FatPacked::'.(0+\%fatpacked);
no strict 'refs';
*{"${class}::files"} = sub { keys %{$_[0]} };

if ($] < 5.008) {
  *{"${class}::INC"} = sub {
     if (my $fat = $_[0]{$_[1]}) {
       return sub {
         return 0 unless length $fat;
         $fat =~ s/^([^\n]*\n?)//;
         $_ = $1;
         return 1;
       };
     }
     return;
  };
}

else {
  *{"${class}::INC"} = sub {
    if (my $fat = $_[0]{$_[1]}) {
      open my $fh, '<', \$fat
        or die "FatPacker error loading $_[1] (could be a perl installation issue?)";
      return $fh;
    }
    return;
  };
}

unshift @INC, bless \%fatpacked, $class;
  } # END OF FATPACK CODE

1;

