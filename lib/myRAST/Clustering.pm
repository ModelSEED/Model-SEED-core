# 
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

package Clustering;

use Carp;
use Data::Dumper;
use tree_utilities;

# $connections->{$object1} ->{$object2} is the distance between $object1 and $object2, if it is defined (undef
# is equivalent to infinity)
#
sub cluster {
    my($connections,$max_dist,$dist_func_ref,$things) = @_;

    if (! ref($dist_func_ref))
    {
	if    ($dist_func_ref eq "avg_dist")            { $dist_func_ref = \&avg_dist }
	elsif ($dist_func_ref eq "max_dist")            { $dist_func_ref = \&max_dist }
	elsif ($dist_func_ref eq "min_dist")            { $dist_func_ref = \&single_linkage_dist }
	elsif ($dist_func_ref eq "single_linkage_dist") { $dist_func_ref = \&single_linkage_dist }
	elsif ($dist_func_ref eq "double_linkage_dist") { $dist_func_ref = \&double_linkage_dist }
	elsif ($dist_func_ref eq "triple_linkage_dist") { $dist_func_ref = \&triple_linkage_dist }
	else { confess "Could not resolve the distance function" }
    }
    my @clusters = defined($things) ? map { [$_] } @$things :
                                      map { [$_] } keys(%$connections);
    my @trees    = map { [$_->[0],0,[undef]] } @clusters;

    my ($cI,$cJ,$d) = &closest($connections,\@clusters,$max_dist,$dist_func_ref);
    while (defined($cI))
    {
	my $treeI   = $trees[$cI];
	my $treeJ   = $trees[$cJ];
	my $parent  = ['',0,[0,$treeI,$treeJ]];
	$treeI->[2]->[0] = $treeJ->[2]->[0] = $parent;
	$treeI->[1] = $treeJ->[1] = $d/2;
	$trees[$cI] = $parent;
	splice(@trees,$cJ,1);
	push(@{$clusters[$cI]},@{$clusters[$cJ]});
	splice(@clusters,$cJ,1);
	($cI,$cJ,$d) = &closest($connections,\@clusters,$max_dist,$dist_func_ref);
    }
    return (\@clusters,\@trees);
}

sub closest {
    my($connections,$clusters,$max_dist,$dist_func_ref) = @_;

    my($i,$j,$best,$bestI,$bestJ);
    for ($i=0; ($i < (@$clusters - 1)); $i++)
    {
	for ($j=$i+1; ($j < @$clusters); $j++)
	{
	    my $dist = &$dist_func_ref($connections,$clusters->[$i],$clusters->[$j],$max_dist);
	    if (defined($dist) && ($dist <= $max_dist))
	    {
		if ((! defined($best)) || ($best > $dist))
		{
		    $bestI = $i;
		    $bestJ = $j;
		    $best  = $dist;
		}
	    }
	}
    }
    return ($bestI,$bestJ,$best);
}
    
sub single_linkage_dist {
    my($connections,$clust1,$clust2) = @_;

    my $best;
    foreach my $x (@$clust1)
    {
	foreach my $y (@$clust2)
	{
	    my $dist = $connections->{$x}->{$y};
	    if ((! defined($best)) || (defined($dist) && ($dist < $best)))
	    {
		$best = $dist;
	    }
	}
    }
    return $best;
}

sub double_linkage_dist {
    my($connections,$clust1,$clust2,$max_dist) = @_;

    return &n_linkage_dist($connections,$clust1,$clust2,$max_dist,2);
}

sub triple_linkage_dist {
    my($connections,$clust1,$clust2,$max_dist) = @_;

    return &n_linkage_dist($connections,$clust1,$clust2,$max_dist,3);
}


sub n_linkage_dist {
    my($connections,$clust1,$clust2,$max_dist,$min_link) = @_;

    my $best;
    my $count = 0;
    foreach my $x (@$clust1)
    {
	foreach my $y (@$clust2)
	{
	    my $dist = $connections->{$x}->{$y};
	    if (defined($dist) && ($dist <= $max_dist))
	    {
		$count++;
		if ((! defined($best)) || ($dist > $best))
		{
		    $best = $dist;
		}
	    }
	}
    }
    my $max_clust = (@$clust1 >= @$clust2) ? @$clust1 : @$clust2;
    my $need = ($max_clust > $min_link) ? $min_link : $max_clust;
    return ($count >= $need) ? $best : undef;
}

sub max_dist {
    my($connections,$clust1,$clust2) = @_;

    my $best;
    foreach my $x (@$clust1)
    {
	foreach my $y (@$clust2)
	{
	    my $dist = $connections->{$x}->{$y};
	    if (! defined($dist)) { return undef }
	    if ((! defined($best)) || ($dist > $best))
	    {
		$best = $dist;
	    }
	}
    }
    return $best;
}

sub avg_dist {
    my($connections,$clust1,$clust2) = @_;

    my $sum = 0;
    my $n   = 0;
    foreach my $x (@$clust1)
    {
	foreach my $y (@$clust2)
	{
	    my $dist = $connections->{$x}->{$y};
	    if (! defined($dist)) { return undef }
	    $n++;
	    $sum += $dist;
	}
    }
    return ($sum/$n);
}

1
