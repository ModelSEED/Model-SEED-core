
# This is a SAS component.

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
# 
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License. 
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

package set_utilities;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(
	     member
	     union
	     intersection
	     set_diff
	     unique
);

sub member {
    my($x,$set) = @_;
    my($i);

    for ($i=0; $i <= $#{$set}; $i++)
    {
	if ($set->[$i] eq $x) { return 1; }
    }
    return 0;
}

sub set_diff {
    my($s1,$s2) = @_;
    my(@set1,@set2,$p1,$p2,$diff);

    @set1 = sort @$s1;
    @set2 = sort @$s2;
#   print STDERR "set1 has $#set1+1 and set2 has $#set2+1\n";

    $p1   = 0;
    $p2   = 0;
    $diff = [];

    while (($p1 <= $#set1) && ($p2 <= $#set2))
    {
	if    ($set1[$p1] lt $set2[$p2])
	{
	    push(@$diff,$set1[$p1]); $p1++;
	}
	elsif ($set2[$p2] lt $set1[$p1])
	{
	    $p2++;
	}
	else  
	{
	    $p1++; $p2++;
	}
    }
    while ($p1 <= $#set1)
    {
	push(@$diff,$set1[$p1]); $p1++;
    }
    return $diff;
}
	
sub union {
    my($s1,$s2) = @_;
    my(@set1,@set2,$p1,$p2,$union);

    @set1 = sort @$s1;
    @set2 = sort @$s2;
    
    $p1   = 0;
    $p2   = 0;
    $union = [];

    while (($p1 <= $#set1) || ($p2 <= $#set2))
    {
	if    ($p2 > $#set2)
	{
	    push(@$union,$set1[$p1++]);
	}
	elsif ($p1 > $#set1)
	{
	    push(@$union,$set2[$p2++]);
	}
	elsif ($set1[$p1] lt $set2[$p2])
	{
	    push(@$union,$set1[$p1++]); 
	}
	elsif ($set2[$p2] lt $set1[$p1])
	{
	    push(@$union,$set2[$p2++]); 
	}
	else  
	{
	    push(@$union,$set1[$p1++]); 
	    $p2++;
	}
    }
    return $union;
}

sub intersection {
    my($s1,$s2) = @_;
    my(@set1,@set2,$p1,$p2,$intersection);

    @set1 = sort @$s1;
    @set2 = sort @$s2;
    
    $p1   = 0;
    $p2   = 0;
    $intersection = [];

    while (($p1 <= $#set1) && ($p2 <= $#set2))
    {
	if ($set1[$p1] lt $set2[$p2])
	{
	    $p1++;
	}
	elsif ($set2[$p2] lt $set1[$p1])
	{
	    $p2++;
	}
	else  
	{
	    push(@$intersection,$set1[$p1++]); 
	    $p2++;
	}
    }
    return $intersection;
}
    
sub unique {
# &unique(\@L) -> \@Lunique
    my($f)   = @_;
    my(@xL)  = sort(@$f);
    my(@ans) = ();
    my($i);
    
    for ($i=0; $i <= $#xL; $i++)
    {
	if (($i == $#xL) || ($xL[$i] ne $xL[$i+1]))
	{
	    push(@ans,$xL[$i]);
	}
    }
    return \@ans;
}

