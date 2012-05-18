package CorrTableEntry;
use strict;

#
# This is a SAS component
#

sub new
{
    my($class, $line) = @_;
    my $l = $line;
    chomp $l;
    return bless [split(/\t/, $l)], $class;
}

# Column-1
sub id1
{
    return $_[0]->[0];
}

# Column-2
sub id2
{
    return $_[0]->[1];
}

# Column-3
sub npairs
{
    return $_[0]->[2];
}

# Column-4
sub pairs
{
    my @pairs = split(/,/, $_[0]->[3]);
    return map { [split(/:/, $_)] } @pairs;
}

# Column-5
sub func1
{
    return $_[0]->[4];
}

# Column-6
sub func2
{
    return $_[0]->[5];
}

# Column-7
sub aliases1
{
    return $_[0]->[6];
}

# Column-8
sub aliases2
{
    return $_[0]->[7];
}

# Column-9
sub hitinfo
{
    return $_[0]->[8];
}

# Column-10
sub iden
{
    return $_[0]->[9];
}

# Column-11
sub psc
{
    return $_[0]->[10];
}

# Column-12
sub beg1
{
    return $_[0]->[11];
}

# Column-13
sub end1
{
    return $_[0]->[12];
}

# Column-14
sub ln1
{
    return $_[0]->[13];
}

# Column-14
sub len1
{
    return $_[0]->[13];
}

# Column-15
sub beg2
{
    return $_[0]->[14];
}

# Column-16
sub end2
{
    return $_[0]->[15];
}

# Column-17
sub ln2
{
    return $_[0]->[16];
}

# Column-17
sub len2
{
    return $_[0]->[16];
}

# Column-18
sub bsc
{
    return $_[0]->[17];
}

# Column-19
sub num_matching_functions
{
    return $_[0]->[18];
}

1;
