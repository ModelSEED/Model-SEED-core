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

package tree_utilities;

use set_utilities;
use Carp;

require Exporter;
@ISA = (Exporter);
@EXPORT = qw(
             ancestors_of
	     build_tree_from_outline
	     collapse_unnecessary_nodes
	     copy_tree
	     display_tree
	     dist_from_root
	     distance_between
	     ids_of_tree
	     in_tree
	     is_desc_of
	     is_leaf
	     label_all_nodes
	     label_of
	     label_to_file
	     label_to_node
	     label_to_printable
	     locate_node
	     max_dist_to_tip
	     min_dist_to_tip
	     most_recent_common_ancestor
	     move_to
	     neighboring_nodes
	     neighborhood_of_tree_point
	     neighboring_tips
	     neighboring_tipsN
	     neighboring_tipsN_by_steps
	     neighboring_tips_by_steps
	     node_brlen
	     node_label
	     node_pointers
	     nodes_in_context
	     nodes_within_dist
	     normalize_fake_distances
	     number_nodes_in_tree
	     parent_of
	     parent_of_node
	     parse_newick_tree
	     prefix_of
	     print_tree
	     printable_to_label
	     relabel_nodes
	     read_ncbi_tree
	     representative_by_size
	     root_tree
	     root_tree_at_node
	     root_tree_between_nodes
	     simple_move_to_middle
	     size_tree
	     split_tree
	     subtree
	     subtree_no_collapse
	     tip_in_tree
	     tips_of_tree
	     to_binary
	     to_get_context
	     to_newick
	     to_newick_label
	     to_prolog
	     top_tree
	     tree_from_subtrees
	     tree_index_tables
	     uproot
	     write_newick
	     write_xml
);

# tree utilities
#
#  Tree is [Label,DistanceToParent,[ParentPointer,ChildPointer1,...],[Name1\tVal1,Name2\Val2...]]
#
#  IndexSet is [NodeToPrefix,NodeToLabel,LabelToNode]  3 associative arrays
#

sub ancestors_of {
    my($node,$tabP) = @_;

    if (! (ref($node) eq "ARRAY")) { $node = &label_to_node($tabP,$node); }
    my @anc = ();
    while (my $x = $node->[2]->[0])
    {
	push(@anc,$x);
	$node = $x;
    }
    return @anc;
}

sub build_tree_from_outline {
# &build_outline($outline_file) -> \tree
    local($file) = @_;
    local(@stack,$nodeP,$x,$nxt,$lev,$parent,$descP);

    open TMP_BUILD_OUTLINE,"<$file" || die $!;
    $stack[0] = ["",0.0,[0],[]]; $nxt = 1;

    while (defined($_ = <TMP_BUILD_OUTLINE>))
    {
#	if ($_ =~ /^\s*(\d+)\.+\s*(\S.*\S)\s*$/)
	if ($_ =~ /^\s*(\d+)\.(.*)$/)
	{
	    $lev = $1;
	    $x = $2;  
	    $x =~ s/^\s+//;
	    $x =~ s/\s+$//;

	    if ($x =~ /\'/)
	    {
		$x =~ s/\'/''/g;
		$x = "\'$x\'";
	    }
	    else
	    {
		if ($x =~ /[ \[\]\(\)\:\;\,]/)
		{
		    $x = "\'$x\'";
		}
	    }

#	    print STDERR "processing $_ : lev=$lev nxt=$nxt\n";
	    $parent = $lev-1;
	    $nodeP = [$x,1,[$stack[$parent]],[]];
	    (($parent < $nxt) && ($parent >= 0)) || die("invalid: parent=$parent nxt=$nxt: $_");
	    $descP = $stack[$parent]->[2];
	    push(@$descP,$nodeP);
	    if ($lev == $nxt)
	    {
		push(@stack,$nodeP);
		$nxt++;
	    }
	    else
	    {
		while ($nxt > ($lev+1))
		{
		    $x = pop(@stack); $nxt--;
		}
		$stack[$nxt-1] = $nodeP;
	    }
	}
    }
    close(TMP_BUILD_OUTLINE);

    ($#{$stack[0]->[2]} == 1) ||
	die("invalid outline: must be a single level 1 entry: $#{$stack[0]->[2]}");
    $stack[0]->[2]->[1]->[2]->[0] = 0; # zero out parent pointer
    return $stack[0]->[2]->[1];
}

# a debugging routine
sub print_tree1 {
# &print_tree1(\node,indent)
    local($nodeP,$indent) = @_;
    local($label,$blen,$chP,$attrP,$i,$j,$name,$val);

    $i = " " x (2 * $indent);
    print $i;

    $label = $nodeP->[0];
    $blen  = $nodeP->[1];
    $chP   = $nodeP->[2];
    $attrP = $nodeP->[3];

    print "($indent) label=$label brlen=$blen\n";
    for ($j=0; $j <= $#{$attrP}; $j++)
    {
	($name,$val) = split(/\t/,$attrP->[$j]);
	print "$i \* $name\: $val\n";
    }

    for ($j=1; $j <= $#{$chP}; $j++)
    {
	&print_tree1($chP->[$j],$indent+1);
    }
}

sub print_tree {
    local($treeP) = @_;

    if (! $treeP) 
    { 
	print "print_tree received a null tree as input\n"; return 0; 
    }
    &print_tree1($treeP,0);
    return 1;
}

sub node_pointers {
    local($nodeP) = @_;
    return $nodeP->[2];
}

sub node_label {
    local($nodeP) = @_;
    return $nodeP->[0];
}

sub node_brlen {
    local($nodeP) = @_;
    return $nodeP->[1];
}

sub node_attributes {
    local($nodeP) = @_;
    return $nodeP->[3];
}


sub size_tree {
# size_tree(\node) -> number leaves
    my($nodeP) = @_;
    my($children,$cnt,$x);

    $children = &node_pointers($nodeP);
    if ($#{$children} >= 1)
    {
	$cnt = 0;
	for ($x=1; $x <= $#{$children}; $x++)
	{
	    $cnt += &size_tree($children->[$x]);
	}
    }
    else
    {
	$cnt=1;
    }
    return $cnt;
}

sub number_nodes_in_tree {
# size_tree(\node) -> number leaves
    my($nodeP) = @_;
    my($children,$cnt,$x);

    $children = &node_pointers($nodeP);
    if ($#{$children} >= 1)
    {
	$cnt = 1;
	for ($x=1; $x <= $#{$children}; $x++)
	{
	    $cnt += &number_nodes_in_tree($children->[$x]);
	}
    }
    else
    {
	$cnt=1;
    }
    return $cnt;
}

sub move_to {
# &move_to(\node,child) -> \new_tree
    local($nodeP,$child) = @_;

    local($cc,$cl,$cbr);

    $cc = &node_pointers($nodeP);
    local($node1P) = $cc->[$child];
    $cc1 = &node_pointers($node1P);
    $cbr1 = &node_brlen($node1P);

    $cc1->[$#{$cc1}+1] = $nodeP;
    $nodeP->[1] = $cbr1;
    $node1P->[1] = 0.0;
    $nodeP->[2]->[0]  = $node1P;
    $node1P->[2]->[0] = 0;
    splice(@{$cc},$child,1);
    return $node1P;
}

sub simple_move_to_middle {
# &simple_move_to_middle(\tree) -> \new_tree
    local($treeP) = @_;
    local($x,$y,$z,$nr);

    local($cc) = &node_pointers($treeP);

    if ($#{$cc} != 3) { return $treeP; }

    $x = &size_tree($treeP->[2]->[1]);
    $y = &size_tree($treeP->[2]->[2]);
    $z = &size_tree($treeP->[2]->[3]);
    
    if ($x > ($y+$z)) 
    {
	$nr = &move_to($treeP,1);
	return &simple_move_to_middle($nr);
    }
    elsif ($y > ($x+$z))
    {
	$nr = &move_to($treeP,2);
	return &simple_move_to_middle($nr);
    }
    elsif ($z > ($x+$y))
    {
	$nr = &move_to($treeP,3);
	return &simple_move_to_middle($nr);
    }
    return $treeP;
}
 
sub skip_white {
    local($sP,$offP) = @_;
    local($c);
    
    $c = substr($$sP,$$offP,1);
    while (($c !~ /\S/) || ($c eq "\["))
    {
	while ($c =~ /\s/)
	{
	    $$offP++; $c = substr($$sP,$$offP,1);
	}

	if ($c eq "\[")
	{
	    $$offP = index($$sP,"\]",$$offP);
	    if ($$offP < 0)
	    {
		return 0;
	    }
	    $$offP++;
	}
	$c = substr($$sP,$$offP,1);
    }
    return 1;
}

sub tree_from_subtrees {
# &tree_from_subtrees([$sub1,$sub2,...],$label,$dist) -> treeP
    my($children,$label) = @_;
     
    my($pointers,$x,$tree);

    $pointers = [0];
    foreach $x (@$children)
    {
	push(@$pointers,$x);
    }
    $tree = [$label,$dist,$pointers,[]];
#   $pointers->[0] = $tree;    ### removed oct 29, 1995; bug, I believe RAO
    return $tree;
}

sub parse_newick_treeR {
# usage: parse_newick_treeR(\String,\Start) -> \tree
    local($sP,$offP) = @_;
    local($c,$child,$new_node,$p,$label,$brlen,$to,$from);
    
#    $p = substr($$sP,$$offP,20); print STDERR "parsing: $p\n";

    @children = ();
    $new_node = [0,0,[0],[]];
#    print STDERR "building node $nxt\n";

    &skip_white($sP,$offP);
    $c = substr($$sP,$$offP,1); 


    if ($c eq "(")
    {
	$$offP++;
	while (substr($$sP,$$offP,1) ne ")")
	{
	    $child = &parse_newick_treeR($sP,$offP);
	    if (! $child) { return 0; }
	    $child->[2]->[0] = $new_node;
	    $p = $new_node->[2];
	    push(@$p,$child);
	    &skip_white($sP,$offP);
	    if (substr($$sP,$$offP,1) eq ",") 
	    { 
		$$offP++; 
		&skip_white($sP,$offP);
	    }
	}
	$$offP++;
	&skip_white($sP,$offP);
	$c = substr($$sP,$$offP,1);
    }
    
    if ($c !~ /^[,:\(]/)
    {
	if ($c eq "\'")
	{
	    $label = "";
	    while (substr($$sP,$$offP,1) eq "\'")
	    {
		$from = $$offP++;
		$to = index($$sP,"\'",$$offP);
		if ($to < 0) { return 0; }
		$label .= substr($$sP,$from,($to - $from + 1));
		$$offP = $to+1;
	    }
#	    print STDERR "got label $label\n";
	    $new_node->[0] = $label;
	}
	else
	{
	    $label = "";
	    $c = substr($$sP,$$offP,1);
	    while ($c =~ /[^ \(\)\[\]\'\:\;\,]/)
	    {
		$label .= $c;
		$$offP++;
		$c = substr($$sP,$$offP,1);
	    }
#	    print STDERR "got label $label\n";
	    $new_node->[0] = $label;
	}
	
	&skip_white($sP,$offP);
	$c = substr($$sP,$$offP,1);
    }

    if ($c eq ":")
    {
	$brlen = "";
	$$offP++;
	&skip_white($sP,$offP);
	$c = substr($$sP,$$offP,1);
	while ($c =~ /[0-9-+e\.]/)
	{
	    $brlen .= $c;
	    $$offP++;
	    $c = substr($$sP,$$offP,1);
	}
	$new_node->[1] = $brlen;
	&skip_white($sP,$offP);
    }
#    print STDERR "returning $new_node->[0] $new_node->[1]\n";
    return $new_node;
}

sub no_lengths {
    my($treeP) = @_;
    my($cc,$i);

    $cc = &node_pointers($treeP);

    if ($treeP->[1]) { return 0; }

    if ($#{$cc} < 1)  # we are on a leaf
    {
	return 1;
    }

    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if (! &no_lengths($cc->[$i])) { return 0; }
    }
    return 1;
}

sub parse_newick_tree {
# usage: parse_newick_tree(String) -> \root
    my($input) = @_;
    my($p) = 0;

    my($t) = &parse_newick_treeR(\$input,\$p);
    if (&no_lengths($t))
    {
#	print STDERR "normalizing distances\n";
	&normalize_fake_distances($t);
    }
#    &print_tree($t);
    return $t;
}

sub max {
    local($x,$y) = @_;

    if ($x >= $y) 
    {
	return $x;
    }
    else
    {
	return $y;
    }
}


sub max_dist_to_leaf {
    my($treeP) = @_;
    my($x,$i);

    my($cc,$cbr);
    $cc = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
 
    if ($#{$cc} < 1) { return $cbr; }  # handle leaf

    my($largest) = &max_dist_to_leaf($cc->[1]);
    for ($i=2; $i <= $#{$cc}; $i++)
    {
	$x = &max_dist_to_leaf($cc->[$i]);
	$largest = &max($x,$largest);
    }
    return ($cbr + $largest);
}

sub display_from_node {
    local($nodeP,$relabelP,$x,*y,$scale,*output) = @_;
    local($cc,$cl,$cbr);
    local($i,$sz,$y_me);
    local($x1,$y1,$y2);

    $cc = &node_pointers($nodeP);
    ($cl = &node_label($nodeP))  || ($cl = "");
    ($cbr = &node_brlen($nodeP)) || ($cbr = 0);

    if ($cbr <= $scale)
    {
	$sz = 1;
    }
    else
    {
	$sz = int($cbr / $scale);
    }
    $x1 = $x+$sz;

    if ($#{$cc} < 1) #at leaf
    {
	if ($$relabelP{$cl}) { $cl = $$relabelP{$cl}; }

	substr($output[$y],$x1,1) = " ";
	substr($output[$y],$x1+1,length($cl)) = $cl;

	$y_me = $y;
	$y += 3;
    }
    else
    {
	$y1 = &display_from_node($cc->[1],$relabelP,$x1+1,*y,$scale,*output);
	$y_me = $y;
	$y += 3;

	if ($cl)    # if internal label
	{
	    if ($$relabelP{$cl}) { $cl = $$relabelP{$cl}; }	
	    substr($output[$y_me],$x1+3,length($cl)) = $cl;
	}

	for ($i=2; $i <= $#{$cc}; $i++)
	{
	    $y2 = &display_from_node($cc->[$i],$relabelP,$x1+1,*y,$scale,*output);
	}
	
	for ($i=$y1+1; $i < $y2; $i++)
	{
	    substr($output[$i],$x1,1) = "|";
	}
	substr($output[$y1],$x1,1) = ",";
	substr($output[$y2],$x1,1) = "`";
    }
    substr($output[$y_me],$x,$sz) = ("-" x $sz);

    return $y_me;
}

sub collapse_unnecessary_nodes {
    my($treeP) = @_;
    my($label,$ptrs,$i);

    ($label,undef,$ptrs) = @$treeP;
    if (@$ptrs == 1)
    {
	return $treeP;
    }
    else
    {
	for ($i=1; ($i < @$ptrs); $i++)
	{
	    $ptrs->[$i] = &collapse_unnecessary_nodes($ptrs->[$i]);
	}

	if (@$ptrs == 2)
	{
	    if ($label && (@{$ptrs->[1]->[2]} > 1))
	    {
		$ptrs->[1]->[0] = $label;
	    }
	    $ptrs->[1]->[2]->[0] = $ptrs->[0];
	    return $ptrs->[1];
	}
	else
	{
	    return $treeP;
	}
    }
}

sub display_tree {
    local($treeP,$relabelP) = @_;
    local($x,@y,$lines,$dist,$scale);
    local(@output);
    local($y) = 0;

    $treeP = &collapse_unnecessary_nodes(&copy_tree($treeP));
    
    if (! $treeP) { print STDERR "display_tree passed a null tree\n"; return 0; }

    if ($dist = &max_dist_to_leaf($treeP))
    {
	$scale = $dist / 70;
    }
    else
    {
	$scale = 1;
    }

    $lines = &size_tree($treeP) * 6;
#   print STDERR "size=$lines\n";
    for ($x=0; $x < $lines; $x++)
    {
	$output[$x] = " " x 1000;
    }

    &display_from_node($treeP,$relabelP,1,*y,$scale,*output);
    for ($x=0; $x <= $#output; $x++)
    {
	$output[$x] =~ s/\s+$//;
    }

#    $x=0;
#    while ($x <= $#output)
#    {
#	if ($output[$x] !~ /[^ |]/)
#	{
#	    splice(@output,$x,1);
#	}
#	else
#	{
#	    $x++;
#	}
#    }

    $x = join("\n",@output);
    $x =~ s/\s+$//;
    return "$x\n";
}

sub copy_tree {
# &copy_tree(\tree) -> \copy
    my($treeP) = @_;
    my($newT,$cc,$desc,$i,$child,$attrL,$attr);
    
    $newT = [$treeP->[0],$treeP->[1],0,0];
    $desc = [0];
    $new_attr = [];
    $cc   = &node_pointers($treeP);
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$child = &copy_tree($cc->[$i]);
	$child->[2]->[0] = $newT;
	push(@$desc,$child);
    }
    if ($#{$treeP} == 3)
    {
	$attrL = $treeP->[3];
	foreach $attr (@$attrL)
	{
	    push(@$new_attr,$attr);
	}
    }
    $newT->[2] = $desc;
    $newT->[3] = $new_attr;
    return $newT;
}
    
sub inverted {
# &inverted(\node) -> \inverted_tree_up_from_parent
    my($node) = @_;

    my($brlen,$cc,$par,$sib,$i,$new_sib,$newT,$new_attr,$attrL,$attr,$desc,$x,$inv_par);
    my($y);

    $brlen = $node->[1];
    $par   = $node->[2]->[0];
    $cc    = &node_pointers($par);
#    print STDERR "inverting $node->[0] with parent $par->[0]\n";

    if ($par == 0) { return 0; }  # You cannot invert the root
    
    $sib   = [];
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if ($cc->[$i] ne $node)
	{
#	    print STDERR "$cc->[$i]->[0] is a sibling\n";
	    push(@$sib,$cc->[$i]);
	}
    }
    
    if ($par->[2]->[0] == 0)
    {
	if (($#{$sib} == 0) && (! $par->[0]))
	{
	    $new_sib       = &copy_tree($sib->[0]);
	    $new_sib->[1] += $brlen;
	    $newT          = $new_sib;
	}
	elsif ($#{$sib} >= 0)
	{
	    $new_attr = [];
	    if ($#{$par} > 2)
	    {
		$attrL = $par->[3];
		foreach $attr (@$attrL)
		{
		    push(@$new_attr,$attr);
		}
	    }
	    $desc  = [0];
	    foreach $x (@$sib)
	    {
		$y = &copy_tree($x);
		push(@$desc,$y);
	    }
	    $newT          = [$par->[0],$brlen,$desc,$new_attr];
	}
	else
	{
	    return [$par->[0],$brlen,[],[]];
	}
    }
    else
    {
	$inv_par = &inverted($par);
	$new_attr = [];
	if ($#{$par} > 2)
	{
	    $attrL = $par->[3];
	    foreach $attr (@$attrL)
	    {
		push(@$new_attr,$attr);
	    }
	}
	$desc    = [0];

	foreach $x (@$sib)
	{
	    $y = &copy_tree($x);
	    push(@$desc,$y);
	}
	for ($i=1; ($i <= $#{$desc}) && ($desc->[$i]->[1] < $inv_par->[1]); $i++) {}
	splice(@$desc,$i,0,$inv_par);

	$newT          = [$par->[0],$brlen,$desc,$new_attr];
    }
    return $newT;
}

sub root_tree {
# &root_tree(Indexes,Node,Frac) -> \rooted_tree
#     We root the tree Frac way up to the parent of Node from Node
    my($indexP,$node_id,$frac) = @_;

    my($newT,$node,$branch1,$branch2,$to_parent);
    $newT      = ["",0.0,0,0];

    if (ref($node_id) ne "ARRAY")
    {
	$node      = &label_to_node($indexP,$node_id);
    }
    else
    {
	$node = $node_id;
	$node_id = $node->[0];
    }

    $to_parent = $node->[1];
    $branch1   = &copy_tree($node);
    $branch2   = &inverted($node);
    
    $branch1->[1]      = $to_parent * $frac;
    $branch2->[1]      = $to_parent - $branch1->[1];

    $branch1->[2]->[0] = $newT;
    $branch2->[2]->[0] = $newT;
    $newT->[2]         = [0,$branch1,$branch2];
    return $newT;
}

sub root_tree_at_node {
# &root_tree(Indexes,NodeId) -> \rooted_tree
#     We root the tree at the node with the given id
    my($indexP,$node_id) = @_;
    my($ch,$node,$branch1,$branch2,$to_parent);

    if (ref($node_id) ne "ARRAY")
    {
	($node      = &label_to_node($indexP,$node_id)) || confess "could not locate node $node_id";
    }
    else
    {
	$node = $node_id;
	$node_id = $node->[0];
    }

    if (! $node->[2]->[0]) { return &copy_tree($node); }
    $branch1   = &copy_tree($node);
#    print STDERR "==== branch1\n"; print_tree($branch1);
    $branch2   = &inverted($node);
#    print STDERR "==== branch2\n"; print_tree($branch2);
    
    $branch1->[1]      = 0.0;
    $branch1->[2]->[0] = 0;
    $branch2->[2]->[0] = $branch1;
    $ch                = $branch1->[2];
    for ($i=1; ($i <= $#{$ch}) && ($ch->[$i]->[1] < $branch2->[1]); $i++) {}
    splice(@$ch,$i,0,$branch2);
#    push(@$ch,$branch2);
    return $branch1;
}

sub uproot {
# &uproot(\tree) -> \unrooted_tree
    my($treeP) = @_;
    my($n,$subT1,$subT2,$cc1,$nbr1,$nbr2);
    my($cc,$cl,$cbr);
    my($x,$y);

    $cc = &node_pointers($treeP);

    if ($#{$cc} != 2)  { return $treeP; }

# This is the normal situation in which the current position
# is on the root of a tree, and the root has two children.    
    if (($x = &number_nodes_in_tree($cc->[1])) > 1)
    {
	$subT1 = $cc->[1];
	$subT2 = $cc->[2];
    }
    elsif (($y = &number_nodes_in_tree($cc->[2])) > 1)
    {
	$subT1 = $cc->[2];
	$subT2 = $cc->[1];
    }
    else
    {
	$n = &size_tree($treeP);
	die("could not uproot: only $n nodes in the tree: $x $y");
    }

    $nbr1 = &node_brlen($subT1);
    $nbr2 = &node_brlen($subT2);
    $subT2->[1] = $nbr1+$nbr2;   # subT2 branch length is to $subT1
    $subT2->[2]->[0] = $subT1;
    $cc1 = &node_pointers($subT1);
    $$cc1[$#{$cc1}+1] = $subT2;
    $subT1->[2]->[0] = 0;
    return $subT1;
}

sub subtree {
# subtree(\tree,\$keep) -> \subtree  keep is a reference to an associative array indicating
#                                   nodes to put in the subtree
#                                   *** returns 0 for empty tree
    local($treeP,$keepP) = @_;
    local($cc,$cl,$i,$x);
    $cc = &node_pointers($treeP);
    $cl = &node_label($treeP);

    if ($#{$cc} < 1)  # we are on a leaf
    {
	if ($cl && $$keepP{$cl})
	{
	    return [$treeP->[0],$treeP->[1],[0],[]];
	}
	else
	{
	    return 0;
	}
    }

    local(@children,$d1,$d2,$lab,$node);
    push(@children,0);
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$x = &subtree($cc->[$i],$keepP);
	if ($x)
	{
	    $children[$#children+1] = $x;
	}
    }

    if ($#children == 1)
    {
	$x = $children[1];
	$d1 = &node_brlen($x);
	$d2 = &node_brlen($treeP);
	$x->[1] = $d1+$d2;
	$x->[2]->[0] = 0;
	return $x;
    }
    elsif ($#children > 1)
    {
	$d1 = &node_brlen($treeP);
	$lab = &node_label($treeP);
	$node = [$lab,$d1,\@children];
	foreach $x (@children)
	{
	    $x->[2]->[0] = $node;
	}
	return $node;
    }
    else
    {
	if ($cl && $$keepP{$cl})
	{
	    $d1 = &node_brlen($treeP);
	    @children = (0);
	    return [$cl,$d1,\@children];
	}
	else
	{
	    return 0;
	}
    }
}    

sub subtree_no_collapse1 {
# subtree(\tree,\$keep) -> \subtree  keep is a reference to an associative array indicating
#                                   nodes to put in the subtree
#                                   *** returns 0 for empty tree
    my($treeP,$keepP) = @_;
    my($cc,$cl,$i,$x);
    $cc = &node_pointers($treeP);
    $cl = &node_label($treeP);

    if ($#{$cc} < 1)  # we are on a leaf
    {
	if ($cl && $$keepP{$cl})
	{
	    return [$treeP->[0],$treeP->[1],[0],[]];
	}
	else
	{
	    return 0;
	}
    }

    my(@children,$d1,$d2,$lab,$node);
    push(@children,0);
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$x = &subtree_no_collapse1($cc->[$i],$keepP);
	if ($x)
	{
	    $children[$#children+1] = $x;
	}
    }

    if ($#children >= 1)
    {
	$d1 = &node_brlen($treeP);
	$lab = &node_label($treeP);
	$node = [$lab,$d1,\@children,[]];
	foreach $x (@children)
	{
	    $x->[2]->[0] = $node;
	}
	return $node;
    }
    else
    {
	if ($cl && $$keepP{$cl})
	{
	    $d1 = &node_brlen($treeP);
	    @children = (0);
	    return [$cl,$d1,\@children,[]];
	}
	else
	{
	    return 0;
	}
    }
}    

sub subtree_no_collapse {
# subtree(\tree,\$keep) -> \subtree  keep is a reference to an associative array indicating
#                                   nodes to put in the subtree
#                                   *** returns 0 for empty tree
    my($treeP,$keepP) = @_;
    my($cc,$cl,$i,$x);

    $tree1 = &subtree_no_collapse1($treeP,$keepP);
    while (((! $tree1->[0]) || (! $keepP->{$tree1->[0]})) &&
	   ($#{$tree1->[2]} == 1))
    {
	$tree1 = $tree1->[2]->[1];
    }
    return $tree1;
}


sub read_ncbi_tree {
# &read_ncbi_tree($file) -> \tree
    local($file) = @_;
    local(@stack,$nodeP,$x,$nxt,$lev,$parent,$descP);

    open TMP_READ_NCBI,"<$file" || die $!;
    $stack[0] = ["Universal Ancestor",0,[0],[]]; $nxt = 1;

    while (defined($_ = <TMP_READ_NCBI>))
    {
	if ($_ =~ /^\s*(\d+)\.+\s*(\S[^\[]+)/)
	{
	    $lev = $1;
	    $x = $2;  $x =~ s/\s+$//;

	    if ($x =~ /\'/)
	    {
		$x =~ s/\'/''/g;
		$x = "\'$x\'";
	    }
	    else
	    {
		if ($x =~ /[ \[\]\(\)\:\;\,]/)
		{
		    $x = "\'$x\'";
		}
	    }

	    $parent = $lev-1;
#	    print STDERR "processing $lev :$x:\n";
	    $nodeP = [$x,1,[$stack[$parent]],[]];
	    (($parent < $nxt) && ($parent >= 0)) || die("invalid: $nxt $parent $_");
	    $descP = $stack[$parent]->[2];
	    push(@$descP,$nodeP);
	    if ($lev == $nxt)
	    {
		push(@stack,$nodeP);
		$nxt++;
	    }
	    else
	    {
		while ($nxt > ($lev+1))
		{
		    $x = pop(@stack); $nxt--;
		}
		$stack[$nxt-1] = $nodeP;
	    }
	}
    }
    close(TMP_READ_NCBI);
    return $stack[0];
}
    

sub in_tree {
# &in_tree(id,\tree) -> boolean
    local($id,$treeP) = @_;

    local($cc,$cl,$i);
  
    $cl = &node_label($treeP);
    if ($cl eq $id)
    {
	return 1;
    }

    $cc = &node_pointers($treeP);
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if (&in_tree($id,$cc->[$i]))
	{
	    return 1;
	}
    }
    return 0;
}

sub tip_in_tree {
# &tip_in_tree(id,\tree) -> boolean
    my($id,$treeP) = @_;

    my($cc,$cl,$i);
  
    $cc = &node_pointers($treeP);
    if ($#{$cc} == 0)
    {
	$cl = &node_label($treeP);
	return ($cl eq $id);
    }

    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if (&tip_in_tree($id,$cc->[$i]))
	{
	    return 1;
	}
    }
    return 0;
}

sub ids_of_treeR {
# &ids_in_treeR(\tree,\ids) -> 1
    local($treeP,$idsP) = @_;

    local($cc,$cl,$i);
    $cc = &node_pointers($treeP);
  
    $cl = &node_label($treeP);
    if ($cl)
    {
	$$idsP[$#{$idsP}+1] = $cl;
    }

    for ($i=1; $i <= $#{$cc}; $i++)
    {
	&ids_of_treeR($cc->[$i],$idsP);
    }
    return 1;
}

sub ids_of_tree {
# &ids_in_tree(\tree) -> \IdList    
    local($treeP) = @_;
    local(@ids) = ();

    &ids_of_treeR($treeP,\@ids);
    return \@ids;
}

sub tips_of_treeR {
# &tips_of_treeR(\tree,\ids) -> 1
    local($treeP,$idsP) = @_;

    local($cc,$cl,$i);
    $cc = &node_pointers($treeP);
  
    if ($#{$cc} < 1)  # we are on a leaf
    {
	$cl = &node_label($treeP);
	if ($cl)
	{
	    $$idsP[$#{$idsP}+1] = $cl;
	}
    }
    else
    {
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    &tips_of_treeR($cc->[$i],$idsP);
	}
    }
    return 1;
}

sub tips_of_tree {
# &tips_of_tree(\tree) -> \IdList    
    local($treeP) = @_;
    local(@ids) = ();

    &tips_of_treeR($treeP,\@ids);
    return \@ids;
}

sub to_newickR {
# &to_newickR(\tree) -> newick_string
    my($treeP,$indent) = @_;

    my($cc,$cl,$cbr,$i);
    my($output) = "";

    $cc = &node_pointers($treeP);
    $cl = &node_label($treeP);
    $cbr = &node_brlen($treeP);

    $output .= " " x $indent;
    if ($#{$cc} >= 1)  # we are not on a leaf
    {
	$output .= "(\n";
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    $output .= &to_newickR($cc->[$i],$indent+1);
	    if ($i < $#{$cc})
	    {
		$output .= ",\n";
	    }
	    else
	    {
	        $output .= "\n";
		$output .= " " x $indent;
		$output .= ")";
	    }
	}
    }

    if ($cl)
    {
	$output .= &to_newick_label("$cl");
    }
    $cbr = sprintf "%0.6f",$cbr;
    $output .= " : $cbr";
    return $output;
}

sub to_newick {
    my($tree) = @_;

    return &to_newickR($tree,0) . ";\n";
}

sub to_prologR {
# &to_prologR(\tree) -> prolog_string
    my($treeP) = @_;

    my($len,$cc,$lab,$i);
    my($output) = "";

    $cc = &node_pointers($treeP);
    $output .= "newick([],[";
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$output .= &to_prologR($cc->[$i]);
	if ($i < $#{$cc})
	{
	    $output .= ",";
	}
    }
    if (!($lab = $treeP->[0]))
    {
	$lab = "";
    }

    $len = $treeP->[1];
    $len =~ s/^(\d+)e/$1.0e/;

    $lab =~ s/^\'(.+)\'$/$1/;  

    $output .= "],[],\'$lab\',[],[],$len,[]\)";
    return $output;
}

sub to_prolog {
    my($tree) = @_;

    return (&to_prologR($tree) . ".\n");
}
    
sub to_xmlR {
    my($treeP, $indent, $relabelP, $full_path, $distance) = @_;

    my($attrL, $attr, $len,$lab);
    my($cc,$cl,$cbr,$i, $j, $f);
    my($output) = "";

    $cc = &node_pointers($treeP);
    ($cl = &node_label($treeP))  || ($cl = "");
    ($cbr = &node_brlen($treeP)) || ($cbr = 0);

    #$j = $cbr * 100;
    $j = $cbr * 10;
    if ($distance) {
	    $output .= "<NODE>\n" x $j;
    }	
    $output .= "<NODE rank=\"$indent\"";
    if ($$relabelP{$cl}) { 
    	#print STDERR $cl;
	my $id = $cl;
	my $key_subs = $id."subs";
	my $key_check = $id."checkbox";
    	$cl = $$relabelP{$cl}; 
    	#print STDERR ", $cl \n";
	if ($cl =~ /(fig\S*).*/i) {
		$f = $1;
		$f =~ s/\|/%7c/; 
		print STDERR "RelabelP ", $$relabelP{$key_subs}, "\n";
		$output .= " hidden = \"$$relabelP{$key_check},$f,$full_path,$$relabelP{$key_subs}\"\n";
		$output .= " attachments=\"Protein Page\"";
		#$output .= " attachments=\"0http://bioseed.mcs.anl.gov/~disz/FIG/protein.cgi?prot=$f&amp;user=TerryD;\"";
		#$output .= " attachments=\"0http://bioseed.mcs.anl.gov/~disz/FIG/protein.cgi?prot=$f&amp;user=TerryD,";
		#$output .= "1http://bioseed.mcs.anl.gov/~disz/FIG/assign_using_tree.cgi?checked_leaf=$f&amp;Reroot%20tree=Reroot%20tree&amp;user=TerryD&amp;full_path=$full_path;xml=1;\"";
	} else {
		#$output .= " hidden = \"$$relabelP{checkbox},$cl,$full_path\"\n";
		$output .= " hidden = \"checked_nonleaf,$cl,$full_path, \"\n";
		$output .= " attachments=\"Show Alignment\"";
		#$output .= " attachments =\"1http://bioseed.mcs.anl.gov/~disz/FIG/assign_using_tree.cgi?checked_nonleaf=$cl&amp;Reroot%20tree=Reroot%20tree&amp;user=TerryD&amp;full_path=$full_path;xml=1;\"";

	}
    }
    $output .= ">\n";
    $output .= "$cl\n"; #fig id, insub, gs, func or just node id#
    $cbr = sprintf "%0.6f",$cbr;
    $output .= "$cbr\n";
    #$output .= "$lab $len \n";
#	$attrL = $treeP->[3];
	#foreach $attr (@$attrL)
	#{
	    #$output .= " $attr";
	#}
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$output .= &to_xmlR($cc->[$i], $indent+1, $relabelP, $full_path, $distance);
    }
    $output .= "</NODE>\n";
    if ($distance) {
	    $output .= "</NODE>\n" x $j;
    }
    return $output;
}

sub to_xml {
    my($treeP, $relabelP, $full_path, $distance) = @_;

    return (&to_xmlR($treeP,0, $relabelP, $full_path, $distance) . "\n");
}
sub write_xml {
    my($treeP, $relabelP, $full_path, $distance, $file) = @_;

    my($output);
    $output = to_xml($treeP, $relabelP, $full_path, $distance);

    if ($file) {
	    open(TMP_WRITE_xml,">$file") || confess "could not open $file";
	    print TMP_WRITE_xml $output;
	    close(TMP_WRITE_xml);
    } else {
    		print $output;
	}
	    
    return 1;
}

sub write_newick {
# &write_newick(\tree,$file) -> 1
    my($treeP,$file) = @_;

    my($output);
    $output = to_newick($treeP);

    open(TMP_WRITE_NEWICK,">$file") || confess "could not open $file";
    print TMP_WRITE_NEWICK $output;
    close(TMP_WRITE_NEWICK);

    return 1;
}

sub max_steps_to_leaf {
    local($treeP) = @_;
    local($x,$largest,$i);

    local($cc);
    $cc = &node_pointers($treeP);
 
    if ($#{$cc} < 1) { return 1; }  # handle leaf

    local($largest) = &max_steps_to_leaf($cc->[1]);
    for ($i=2; $i <= $#{$cc}; $i++)
    {
	$x = &max_steps_to_leaf($cc->[$i]);
	$largest = &max($x,$largest);
    }
    return (1 + $largest);
}

sub normalize_fake_distancesR {
# &normalize_fake_distancesR(\tree,max,sofar) -> 1   # resets distances on all branches to be equal
    local($treeP,$max,$sofar) = @_;

    local($cc,$cl,$cbr,$i);

    $cc = &node_pointers($treeP);
    $cl = &node_label($treeP);

    if ($#{$cc} < 1)  # we are on a leaf
    {
#	print STDERR "$treeP->[0] : $max $sofar\n";
	$treeP->[1] = $max - $sofar;
    }
    else
    {
	$treeP->[1] = 1;
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    &normalize_fake_distancesR($cc->[$i],$max,$sofar+1);
	}
    }
    return 1;
}

sub normalize_fake_distances {
# &normalize_fake_distances(\tree) -> 1   # resets distances on all branches to be equal
    local($treeP) = @_;
    local($dist) = &max_steps_to_leaf($treeP);

#    print STDERR "max steps = $dist\n";

    return normalize_fake_distancesR($treeP,$dist,0);
}

sub nodes_within_dist {
    local($treeP,$blen) = @_;
    local($cc,$i,$x);

    $cc = &node_pointers($treeP);

    if ($#{$cc} < 1)  # we are on a leaf
    {
	return 1;
    }
    elsif ($blen == 1)
    {
	$x = &size_tree($treeP);
	if ($x < 4)
	{
	    return $x;
	}
	else
	{
	    return 1;
	}
    }
    else
    {
	$x = 1;
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    $x += &nodes_within_dist($cc->[$i],$blen-1);
	}
	return $x;
    }
}

sub split_treeR {
# &split_treeR(\tree,$min,$max,$depth,\current_conn,\trees,\connections) -> \copied and split tree
    local($treeP,$min,$max,$depth,$current_connP,$treesP,$connsP) = @_;

    local(@children,$cc,$cl,$i,$node);

    $cc = &node_pointers($treeP);
    if ($#{$cc} == 1)     # if a leaf
    {
	return [$treeP->[0], $treeP->[1], [0], []];
    }
    elsif (($depth == 0) && (&size_tree($treeP) >= 4))
    {
	$cl = &node_label($treeP);
	push(@$current_connP,$cl);
	&split_tree($treeP,$min,$max,$treesP,$connsP);
	return [$treeP->[0], $treeP->[1], [0], []];
    }
    else
    {
	@children = (0);
	$node = [$treeP->[0], $treeP->[1], \@children, []];
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    $children[$i] = split_treeR($cc->[$i],$min,$max,$depth-1,$current_connP,
					$treesP,$connsP);
	    $children[$i]->[2]->[0] = $node;
	}
	return $node;
    }
}

sub split_tree {
# &split_tree(\tree,$min,$max,\(trees),\(connections)) -> 1
    local($treeP,$min,$max,$treesP,$connectionsP) = @_;

    local($my_conn) = [];
    local($sz,$t);

    $sz = &size_tree($treeP);

    if ($sz <= $max)
    {
	$t = &split_treeR($treeP,$min,$max,100,$my_conn,$treesP,$connectionsP);
    }
    else
    {
	local($blen,$found,$i);
	for ($blen=2, $found=0; ! $found; $blen++)
	{
	    $i = &nodes_within_dist($treeP,$blen);
	    if ($i >= $min)
	    {
		$found = $blen;
	    }
	}
	$t = &split_treeR($treeP,$min,$max,$found,$my_conn,$treesP,$connectionsP);
    }
    push(@$treesP,$t);
    push(@$connectionsP,$my_conn);

    1;
}

sub top_treeR {
# &top_treeR(\tree,$depth) -> \copied and truncated tree
    local($treeP,$depth) = @_;

    local(@children,$cc,$cl,$i,$node);

    $cc = &node_pointers($treeP);
    if ($#{$cc} == 1)     # if a leaf
    {
	return [$treeP->[0], $treeP->[1], [0], []];
    }
    elsif (($depth == 0) && (&size_tree($treeP) >= 4))
    {
	return [$treeP->[0], $treeP->[1], [0], []];
    }
    else
    {
	@children = (0);
	$node = [$treeP->[0], $treeP->[1], \@children, []];
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    $children[$i] = top_treeR($cc->[$i],$depth-1);
	    $children[$i]->[2]->[0] = $node;
	}
	return $node;
    }
}

sub top_tree {
# &top_tree(\tree,$min,$max) -> 1
    local($treeP,$min,$max) = @_;

    local($sz,$t);

    $sz = &size_tree($treeP);

    if ($sz <= $max)
    {
	$t = &top_treeR($treeP,100);
    }
    else
    {
	local($blen,$found,$i);
	for ($blen=2, $found=0; ! $found; $blen++)
	{
	    $i = &nodes_within_dist($treeP,$blen);
	    if ($i >= $min)
	    {
		$found = $blen;
	    }
	}
	$t = &top_treeR($treeP,$found);
    }
    return $t;
}


sub to_newick_label {
    my($lab) = @_;

    my($newick) = $lab;
    if (($newick =~ /^\'(.*)\'$/) && (index($1,"\'") < 0))
    {
	return $newick;
    }
    elsif ($newick =~ /[\'_]/)
    {
	$newick =~ s/\'/''/g;
	$newick = "\'$newick\'";
    }
    else
    {
	if ($newick =~ /[ \[\]\(\)\:\;\,]/)
	{
	    $newick = "\'$newick\'";
	}
    }
    return $newick;
}

sub label_to_file {
    my($lab) = @_;

    my($file) = $lab;

    if ($file =~ /^\'/)
    {
	$file =~ s/^.(.*).$/$1/;
    }
    
    $file =~ s/\'\'/_/g;
    $file =~ s/[ \'\[\]\/\;\:]/_/g;
    return $file;
}

sub label_to_printable {
    my($lab) = @_;

    my($printable) = $lab;

    if ($printable !~ /^\'/)
    {
	return $printable;
    }
    
    $printable =~ s/^.(.*).$/$1/;
    $printable =~ s/\'\'/\'/g;
    return $printable;
}

sub printable_to_label {
    my($printable) = @_;

    $printable =~ s/ sp$/ sp./;
    if ($printable =~ /\'/)
    {
	$printable =~ s/\'/''/g;
	$printable = "\'$printable\'";
    }
    else
    {
	if ($printable =~ /[ \[\]\(\)\:\;\,]/)
	{
	    $printable = "\'$printable\'";
	}
    }
    return $printable;
}

sub tree_index_tablesR {
    my($treeP,$prefix,$node_to_prefix,$prefix_to_node,$lab_to_node,$string) = @_;

    my($cc,$cl,$i,$c);
    $cc = &node_pointers($treeP);
    $cl = &node_label($treeP);
#    print STDERR "cl=$cl\n";
    
    $prefix_to_node->{$prefix}    = $treeP;
    $node_to_prefix->{$treeP}     = $prefix;
    if ($cl)
    {
	$lab_to_node->{$cl}       = $treeP;
#	print STDERR "prefix=$prefix lab=$cl\n";
    }
    
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$c = substr($string,$i,1);
	&tree_index_tablesR($cc->[$i],$prefix . "$c",$node_to_prefix,$prefix_to_node,$lab_to_node,$string);
    }
    return 1;
}

sub tree_index_tables {
# &tree_index_tables(\tree) -> [\LabelToPrefix,\PrefixToLabel,\LabelToNode]
    my($treeP) = @_;
    my($node_index_str,$i);

    $node_index_str = " " x 254;
    for ($i=0; $i <= 254; $i++)
    {
	substr($node_index_str,$i,1) = pack("c",$i+1);
    }

    $node_to_prefix = {};
    $lab_to_node    = {};
    $prefix_to_node = {};

    &tree_index_tablesR($treeP,"0",$node_to_prefix,$prefix_to_node,$lab_to_node,$node_index_str);
    return [$node_to_prefix,$prefix_to_node,$lab_to_node];
}

sub label_to_node {
# &label_to_node(\index_tables,$label) -> \node
    my($tabsP,$label) = @_;

#   print STDERR "looking for node $label\n";
    return $tabsP->[2]->{$label};
}

sub is_desc_of {
# &is_desc_of($id1,$id2,$tablesP) -> boolean (1 <-> $id1 is a desc of $id2)
    my($id1,$id2,$tabsP) = @_;
    my($p1,$p2);

#    print STDERR "is $id1 a desc of $id2\n";
    $p1 = &prefix_of($id1,$tabsP);
    $p2 = &prefix_of($id2,$tabsP);
#    print STDERR "prefix for $id1 is $p1\n";
#    print STDERR "prefix for $id2 is $p2\n";
    if (defined($p1) && defined($p2) &&(index($p1,$p2) == 0))
    {
	return 1;
    }
    else
    {
	return 0;
    }
}

sub most_recent_common_ancestor {
# &most_recent_common_ancestor(Nodes,Indexes) -> node_of_ancestor
# we now accept nodes designated with IDs or actual node pointers
#
    my($idsP,$tablesP) = @_;

    my($i,$common,$node);
    my(@prefix);
    
#   print STDERR "most recent common ancestor for @$idsP\n";

    for ($i=0; $i <= $#{$idsP}; $i++)
    {
	if (ref($idsP->[$i]) eq "ARRAY")
	{
	    $node = $idsP->[$i];
	}
	else
	{
	    $node = &label_to_node($tablesP,$idsP->[$i]);
	}

	if (! defined($prefix[$i] = $tablesP->[0]->{$node}))
	{
	    print STDERR "*** mrca: $i $idsP->[$i] is not indexed\n";
	    return "";
	}
    }
    $common = &common_prefix(\@prefix);
#   print STDERR "most_recent_common_ancestor prefix is $common\n";
    return $tablesP->[1]->{$common};
}

sub common_prefix {
    my($prefixes) = @_;
    my($common,$ok,$i,$j,@len,$c);

    $common = "";
    $ok     = 1;
    for ($i=0; $i <= $#{$prefixes}; $i++)
    {
	$len[$i] = length($prefixes->[$i]);
    }

    for ($i=0; $ok; $i++)
    {
	if ($len[0] <= $i)
	{
	    $ok=0;
	}
	else
	{
	    $c = substr($prefixes->[0],$i,1);
	    for ($j=1; $ok && ($j <= $#{$prefixes}); $j++)
	    {
		if (($len[$j] <= $i) || ($c ne substr($prefixes->[$j],$i,1)))
		{
		    $ok=0;
		}
	    }
	    if ($ok)
	    {
		$common .= $c;
	    }
	}
    }
    return $common;
}

sub parent_of {
# &parent_of(\index_tables,label) -> \parent_node
    my($tabsP,$label) = @_;
 
    my($p)      = &label_to_node($tabsP,$label);
    return $p->[2]->[0];
}

sub parent_of_node {
    my($node) = @_;
    
    return $node->[2]->[0];
}

sub prefix_of {
# &prefix_of(label,tabsP) -> prefix
    my($label,$tabsP) = @_;

    return $tabsP->[0]->{$label};
}

sub label_of {
# &label_of(prefix,tabsP) -> label
    my($prefix,$tabsP) = @_;

    return $tabsP->[1]->{$prefix};
}

########### first, by number of steps
sub collect_tips_up_within_steps {
    my($treeP,$totsteps,$steps,$node,$tips) = @_;
    my($cc,$cbr,$d0,$i);

    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $steps - 1;
#    print STDERR "$d0 left on way up at $treeP->[0]\n";
    if (($d0 > 0) && ($cc->[0]))
    {
	&collect_tips_up_within_steps($cc->[0],$totsteps,$d0,$treeP->[0],$tips);
    }

    if ($d0 > 0)
    {
	for ($i=1; $i <= $#{$cc}; $i++)
	{
	    if ($node ne $cc->[$i]->[0])
	    {
#		print STDERR "going down to $cc->[$i]->[0] with $d0 left\n";
		&collect_tips_down_within_steps($cc->[$i],$totsteps,$d0,$tips);
	    }
	}
    }
    return 1;
}

sub collect_tips_down_within_steps {
    my($treeP,$totsteps,$steps,$tips) = @_;
    my($cc,$cbr,$d0,$used,$i);

    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $steps - 1;
#    print STDERR "down to $treeP->[0] with $d0 left $#{$cc} \n";

    if ($d0 >= 0)
    {
	if ($#{$cc} == 0)  # if leaf
	{
#	    print STDERR "pushing $treeP->[0]\n";
	    $used = $totsteps-$d0;
	    push(@$tips,[$used,$treeP->[0]]);
	}
	else
	{
	    for ($i=1; $i <= $#{$cc}; $i++)
	    {
		&collect_tips_down_within_steps($cc->[$i],$totsteps,$d0,$tips);
	    }
	}
    }
    return 1;
}

sub by_key {
    return ($a->[0] <=> $b->[0]);
}

sub neighboring_tips_and_steps {
    my($treeP,$steps) = @_;
    my($node) = $treeP->[0];
    my($cc,$i,$d0,$cbr,$tips,@tipsS);

    $tips = [];
    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $steps - 1;
#    print STDERR "$d0 left on way up at $treeP->[0]\n";
    if (($d0 > 0) && ($cc->[0]))
    {
	&collect_tips_up_within_steps($cc->[0],$steps,$d0,$node,$tips);
    }
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	&collect_tips_down_within_steps($cc->[$i],$steps,$steps,$tips);
    }
    @tipsS = sort by_key @$tips;
    return \@tipsS;
}

sub neighboring_tips_by_steps {
    my($treeP,$steps) = @_;
    my($node) = $treeP->[0];
    my($tips,$ordered_tips,$i);

    $tips = &neighboring_tips_and_steps($treeP,$steps);

    $ordered_tips = [];
    foreach $i (@$tips)
    {
	push(@$ordered_tips,$i->[1]);
    }
    return $ordered_tips;
}

sub neighboring_tipsN_by_steps {
    my($treeP,$n) = @_;
    my($node) = $treeP->[0];
    my($cc,$i,$d0,$cbr,$tips,$ordered_tips);

    $cc  = &node_pointers($treeP);
    $d0  = 1;

    $tips = &neighboring_tips_and_steps($treeP,$d0);
    while ($#{$tips} < ($n-1))
    {
	$d0 = $d0 + 1;
	$tips = &neighboring_tips_and_steps($treeP,$d0);
	print STDERR "at distance $d0\n";
	foreach $i (@$tips)
	{
	    print STDERR "   $i->[0]  $i->[1]\n";
	}
	print STDERR "=======\n\n";
    }

    $ordered_tips = [];
    for ($i=0; $i < $n; $i++)
    {
	push(@$ordered_tips,$tips->[$i]->[1]);
    }
    return $ordered_tips;
}



############  now by distance
sub collect_tips_up_within_range {
    my($treeP,$totdist,$dist,$node,$tips) = @_;
    my($cc,$cbr,$d0,$i);

    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $dist - $cbr;
#    print STDERR "$d0 left on way up at $treeP->[0]\n";
    if (($d0 > 0) && ($cc->[0]))
    {
	&collect_tips_up_within_range($cc->[0],$totdist,$d0,$treeP->[0],$tips);
    }

    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if ($node ne $cc->[$i]->[0])
	{
#	    print STDERR "going down to $cc->[$i]->[0] with $dist left\n";
	    &collect_tips_down_within_range($cc->[$i],$totdist,$dist,$tips);
	}
    }
    return 1;
}

sub collect_tips_down_within_range {
    my($treeP,$totdist,$dist,$tips) = @_;
    my($cc,$cbr,$d0,$used,$i);

    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $dist - $cbr;
#   print STDERR "down to $treeP->[0] with $d0 left $#{$cc} \n";

    if ($d0 >= 0)
    {
	if ($#{$cc} == 0)  # if leaf
	{
#	    print STDERR "pushing $treeP->[0]\n";
	    $used = $totdist-$d0;
	    push(@$tips,[$used,$treeP->[0]]);
	}
	else
	{
	    for ($i=1; $i <= $#{$cc}; $i++)
	    {
		&collect_tips_down_within_range($cc->[$i],$totdist,$d0,$tips);
	    }
	}
    }
    return 1;
}

sub by_distance {
    return ($a->[0] <=> $b->[0]);
}

sub neighboring_tips_and_distances {
    my($treeP,$dist) = @_;
    my($node) = $treeP->[0];
    my($cc,$i,$d0,$cbr,$tips,@tipsS);

    $tips = [];
    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $dist - $cbr;
#    print STDERR "$d0 left on way up at $treeP->[0]\n";
    if (($d0 > 0) && ($cc->[0]))
    {
	&collect_tips_up_within_range($cc->[0],$dist,$d0,$node,$tips);
    }
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	&collect_tips_down_within_range($cc->[$i],$dist,$dist,$tips);
    }
    @tipsS = sort by_distance @$tips;
    return \@tipsS;
}


sub neighboring_tips {
    my($treeP,$dist) = @_;
    my($node) = $treeP->[0];
    my($tips,$ordered_tips,$i);

    $tips = &neighboring_tips_and_distances($treeP,$dist);

    $ordered_tips = [];
    foreach $i (@$tips)
    {
	push(@$ordered_tips,$i->[1]);
    }
    return $ordered_tips;
}

sub collect_nodes_up_within_range {
    my($treeP,$totdist,$dist,$node,$tips) = @_;
    my($cc,$cbr,$d0,$i);

    $used = $totdist-$dist;
    push(@$tips,[$used,$treeP->[0]]);
    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $dist - $cbr;
#    print STDERR "$d0 left on way up at $treeP->[0]\n";
    if (($d0 > 0) && ($cc->[0]))
    {
	&collect_nodes_up_within_range($cc->[0],$totdist,$d0,$treeP->[0],$tips);
    }

    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if ($node ne $cc->[$i]->[0])
	{
#	    print STDERR "going down to $cc->[$i]->[0] with $dist left\n";
	    &collect_nodes_down_within_range($cc->[$i],$totdist,$dist,$tips);
	}
    }
    return 1;
}

sub collect_nodes_down_within_range {
    my($treeP,$totdist,$dist,$tips) = @_;
    my($cc,$cbr,$d0,$used,$i);

    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $dist - $cbr;
#   print STDERR "down to $treeP->[0] with $d0 left $#{$cc} \n";

    if ($d0 >= 0)
    {
	$used = $totdist-$d0;
	push(@$tips,[$used,$treeP->[0]]);
	if ($#{$cc} > 0)
	{
	    for ($i=1; $i <= $#{$cc}; $i++)
	    {
		&collect_nodes_down_within_range($cc->[$i],$totdist,$d0,$tips);
	    }
	}
    }
    return 1;
}



sub neighboring_nodes_and_distances {
    my($treeP,$dist) = @_;
    my($node) = $treeP->[0];
    my($cc,$i,$d0,$cbr,$tips,@tipsS);

    $tips = [];
    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $dist - $cbr;
#    print STDERR "$d0 left on way up at $treeP->[0]\n";
    if (($d0 > 0) && ($cc->[0]))
    {
	&collect_nodes_up_within_range($cc->[0],$dist,$d0,$node,$tips);
    }
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	&collect_nodes_down_within_range($cc->[$i],$dist,$dist,$tips);
    }
    @tipsS = sort by_distance @$tips;
    return \@tipsS;
}

sub neighboring_nodes {
    my($treeP,$dist) = @_;
    my($node) = $treeP->[0];
    my($nodes,$ordered_nodes,$i);

    $nodes = &neighboring_nodes_and_distances($treeP,$dist);

    $ordered_nodes = [];
    foreach $i (@$nodes)
    {
	push(@$ordered_nodes,$i->[1]);
    }
    return $ordered_nodes;
}

sub neighboring_tipsN {
    my($treeP,$n) = @_;
    my($node) = $treeP->[0];
    my($cc,$i,$d0,$cbr,$tips,$ordered_tips);

    $cc  = &node_pointers($treeP);
    $cbr = &node_brlen($treeP);
    $d0  = $cbr + 0.0001;

    $tips = &neighboring_tips_and_distances($treeP,$d0);
    while ($#{$tips} < ($n-1))
    {
	$d0 = $d0 + $d0;
	$tips = &neighboring_tips_and_distances($treeP,$d0);
#	print STDERR "at distance $d0\n";
#	foreach $i (@$tips)
#	{
#	    print STDERR "   $i->[0]  $i->[1]\n";
#	}
#	print STDERR "=======\n\n";
    }

    $ordered_tips = [];
    for ($i=0; $i < $n; $i++)
    {
	push(@$ordered_tips,$tips->[$i]->[1]);
    }
    return $ordered_tips;
}


    
sub to_binary {
# &to_binary($treeP) -> \BinaryTree (if original is binary, a copy)
    my($treeP) = @_;

    my($label,$brlen,$ptrs,$attr) = @$treeP;
    if (@$ptrs < 2)
    {
	my $copy = &copy_tree($treeP);
	$copy->[2]->[0] = 0;
	return $copy;
    }
    elsif (@$ptrs == 2)
    {
	my $copy = &to_binary($treeP->[2]->[1]);
	$copy->[2]->[0] = 0;
	return $copy;
    }
    else
    {
	my @children = ();
	my $i;
	for ($i=1; ($i < @$ptrs); $i++)
	{
	    push(@children,&to_binary($ptrs->[$i]));
	}

	while (@children > 2)
	{
	    my $sub1 = shift @children;
	    my $sub2 = shift @children;
	    my $node = ["",1.0e-7,[0,&copy_tree($sub1),&copy_tree($sub2)],[]];
	    $node->[2]->[1]->[2]->[0] = $node;
	    $node->[2]->[2]->[2]->[0] = $node;
	    push(@children,$node);
	}

	my $node = ["",$treeP->[1],[0,
				    &tree_utilities::copy_tree($children[0]),
				    &tree_utilities::copy_tree($children[1])
			           ],[]];
	$node->[2]->[1]->[2]->[0] = $node;
	$node->[2]->[2]->[2]->[0] = $node;
	return $node;
    }
}

sub get_collapse_values {
    my($treeP,$nodesP) = @_;
    my($cc,$dm1,$ds1,$dm2,$ds2,$dm,$ds,$x);

    $cc  = &node_pointers($treeP);
    if ($#{$cc} == 0)
    {
	$dm = $treeP->[1];
	return "$dm\t$dm";
    }

    $x = &get_collapse_values($cc->[1],$nodesP);
    ($dm1,$ds1) = split(/\t/,$x);
    $x = &get_collapse_values($cc->[2],$nodesP);
    ($dm2,$ds2) = split(/\t/,$x);
    $ds = $dm1+$dm2+0.000000001;
    $x = &max($ds1,$ds2);
    if ($ds <= $x)
    {
	$ds = $x + 0.000000001;
    }
    push(@$nodesP,[$ds,$treeP]);
#   print STDERR "collapse for $treeP->[0] is $ds\n";
    $dm = &max($dm1,$dm2) + 0.000000001 + $treeP->[1];
#   print STDERR "max_dist for $treeP->[0] is $dm\n";
    return "$ds\t$dm";
}
    

sub representative_by_size {
# &representative_by_size($RootedTree,$N) -> \RepTree
    my($treeP,$size) = @_;

    my($btree,@nodes,@sorted_nodes,%del,%keep,$tips);
    my ($start,$to_remove,$i,$j,$nodeP,$cc);

    $tips = &tips_of_tree($treeP);
    $start = $#{$tips} + 1;
    $to_remove = $start - $size;
#   print STDERR "we start with $start, so we need to pull $to_remove\n";
    if (($to_remove <= 0) || ($size < 3))
    {
	return $treeP;
    }

    $btree = &to_binary($treeP);
#   &print_tree($btree);

    &get_collapse_values($btree,\@nodes);
    @sorted_nodes = sort by_distance @nodes;

#    print STDERR "nodes:\n";
#    foreach $y (@nodes) { print STDERR "    $y->[0] $y->[1]->[0]\n"; }
#    print STDERR "sorted:\n";
#    foreach $y (@sorted_nodes) { print STDERR "    $y->[0] $y->[1]->[0]\n"; }

    for ($k=0; ($k <= $#sorted_nodes) && ($to_remove > 0); $k++,$to_remove--)
    {
	$nodeP = $sorted_nodes[$k]->[1];
	$cc  = &node_pointers($nodeP);
	if ($cc->[1]->[1] <= $cc->[2]->[1])
	{
	    $i = 1; $j = 2;
	}
	else
	{
	    $i = 2; $j = 1;
	}

	$del{$cc->[$j]->[0]} = 1;
#	print STDERR "pulling at $nodeP->[0] ($sorted_nodes[$k]->[0])  $cc->[$j]->[0] $cc->[$i]->[0]\n";

	$nodeP->[0] = $cc->[$i]->[0];
	$nodeP->[1] += $cc->[$i]->[1];
    }
    
    foreach $x (@$tips)
    {
	if (! $del{$x})
	{
	    $keep{$x} = 1;
#	    print STDERR "keeping $x\n";
	}
    }
    
    return &subtree($btree,\%keep);
}

sub unlabel_internal_nodes {
    my($tree) = @_;

    my $ptrs = $tree->[2];
    if (@$ptrs == 1) { return }
    my $i;
    $tree->[0] = 0;
    for ($i=1; ($i < @$ptrs); $i++)
    {
	&unlabel_internal_nodes($ptrs->[$i]);
    }
}

sub label_all_nodesR {
    my($treeP,$n) = @_;

    my($children,$x);

    if (! $treeP->[0])
    {
	$n++;
	$treeP->[0] = "n$n";
    }
    $children = &node_pointers($treeP);
    for ($x=1; $x <= $#{$children}; $x++)
    {
	$n = &label_all_nodesR($children->[$x],$n);
    }
    return $n;
}

sub label_all_nodes {
    my($treeP) = @_;
    my($max);

    $max = &max_n_label($treeP);
    return &label_all_nodesR($treeP,$max);
}


sub max_n_labelR {
    my($treeP,$max) = @_;
    my($cc,$cl,$i);

    $cc = &node_pointers($treeP);
    $cl = &node_label($treeP);
    if ($cl)
    {
	if ($cl =~ /^n(\d+)$/)
	{
	    $max = ($max < $1) ? $1:$max;
	}
    }

    for ($i=1; $i <= $#{$cc}; $i++)
    {
	$max = &max_n_labelR($cc->[$i],$max);
    }
    return $max;
}

sub max_n_label {
    my($treeP) = @_;

    return &max_n_labelR($treeP,0);
}

 
sub to_get_context {
    my($nodeP,$n) = @_;
    my($parent,$cc,$i,$got,$left);

    $parent = &parent_of_node($nodeP);
    if (! $parent) { return 0; }
    $cc  = &node_pointers($parent);
    $got = 0;
    for ($i=1; $i <= $#{$cc}; $i++)
    {
	if ($cc->[$i] != $nodeP)
	{
	    $got += &size_tree($cc->[$i]);
	}
    }
    if (($got >= $n) || (! $parent))
    {
	return 1;
    }
    else
    {
	$left = $n - $got;
	return &to_get_context($parent,$left) + 1;
    }
}

sub nodes_in_context {
    my($nodeP,$N,$tabP) = @_;
    my($tips,$i,$x,$y,$tip,$tipP,$closest,$nearest_that_one);

#    print STDERR "nodes_in_context: $nodeP->[0] $N\n";
    $tips = &neighboring_tipsN_by_steps($nodeP,$N);
#    print STDERR "$#{$tips} + 1 nodes should be $N\n";
    if ($nodeP->[0])
    {
	push(@$tips,$nodeP->[0]);
    }
    for ($i=2,$x=$nodeP; $i && ($y = &parent_of_node($x)); $x=$y,$i--)
    {
	if ($y->[0])
	{
	    push(@$tips,$y->[0]);
	}
    }
    $closest = [];
    foreach $tip (@$tips)
    {
	$tipP = &label_to_node($tabP,$tip);
	$nearest_that_one = &neighboring_tipsN($tipP,5);
	$closest = &union($closest,$nearest_that_one);
#	print STDERR "got 5 closest\n";
    }
#    print STDERR "returning @$closest\n";
    return $closest;
}

sub dist_from_root {
    my($rootP,$node,$tabP) = @_;

    if (($rootP eq $node) || ($rootP->[0] eq $node))  # we will buy either an id or a pointer
    {
	return 0;
    }
    else
    {
	if (! (ref($node) eq "ARRAY")) { $node = &label_to_node($tabP,$node); }
	return ($node->[1] + &dist_from_root($rootP,$node->[2]->[0],$tabP));
    }
}

sub distance_between {
    my($id1,$id2,$indexesP) = @_;
    my($mrca,$mrcaP,$d1,$d2);

    if ($id1 eq $id2) { return 0.0; }

    $mrcaP   = &most_recent_common_ancestor([$id1,$id2],$indexesP);
    $mrca    = $mrcaP->[0];
#   print STDERR "mrca of $id1 and $id2 is $mrca\n";
    $d1     = &dist_from_root($mrcaP,$id1,$indexesP);
#   print STDERR "dist from $id1 to $mrca is $d1\n";
    $d2     = &dist_from_root($mrcaP,$id2,$indexesP);
#   print STDERR "dist from $id2 to $mrca is $d2\n";
    return ($d1+$d2);
}

sub is_leaf {
    my($node) = @_;
    my($children);

    $children = &node_pointers($node);
    return ($#{$children} == 0);
}

sub min_dist_to_tipR {
    my($node) = @_;
    my($children,$x,$best,$y);

    $children = &node_pointers($node);

    if ($#{$children} >= 1)
    {
	$best = &min_dist_to_tipR($children->[1]);
	for ($x=2; $x <= $#{$children}; $x++)
	{
	    if (($y = &min_dist_to_tipR($children->[$x])) < $best)
	    {
		$best = $y;
	    }
	}
	return $best + $node->[1];
    }
    else
    {
	return $node->[1];
    }
}

sub min_dist_to_tip {
    my($node) = @_;

    return (&min_dist_to_tipR($node ) - $node->[1]);
}


sub max_dist_to_tipR {
    my($node) = @_;
    my($children,$x,$best,$y);

    $children = &node_pointers($node);

    if ($#{$children} >= 1)
    {
	$best = &max_dist_to_tipR($children->[1]);
	for ($x=2; $x <= $#{$children}; $x++)
	{
	    if (($y = &max_dist_to_tipR($children->[$x])) > $best)
	    {
		$best = $y;
	    }
	}
	return $best + $node->[1];
    }
    else
    {
	return $node->[1];
    }
}

sub max_dist_to_tip {
    my($node) = @_;

    return (&max_dist_to_tipR($node ) - $node->[1]);
}

sub locate_node {
    my($node_ids,$tabP) = @_;

    my($nd1,$nd2,$nd3,$pref1,$pref2,$pref3,$comm1,$comm2,$comm3,@pairs);

    if (@$node_ids == 1)
    {
	return &label_to_node($tabP,$node_ids->[0]);
    }
    
    ($nd1,$nd2,$nd3) = @$node_ids;
    defined($pref1 = $tabP->[0]->{&label_to_node($tabP,$nd1)}) || confess "Missing indexes? node_ids=@$node_ids";
    defined($pref2 = $tabP->[0]->{&label_to_node($tabP,$nd2)}) || confess "Missing indexes? node_ids=@$node_ids";
    defined($pref3 = $tabP->[0]->{&label_to_node($tabP,$nd3)}) || confess "Missing indexes? node_ids=@$node_ids";

    $comm1 = &common_prefix([$pref1,$pref2]);
    $comm2 = &common_prefix([$pref1,$pref3]);
    $comm3 = &common_prefix([$pref2,$pref3]);

    @pairs = sort by_numeric_arg1 ([length($comm1),$comm1],[length($comm2),$comm2],[length($comm3),$comm3]);
    return $tabP->[1]->{$pairs[0]->[1]};
}

sub by_numeric_arg1 {
    return ($b->[0] <=> $a->[0]);
}

sub root_tree_between_nodes {
    my($node1,$node2,$frac,$tabP) = @_;
    my($pref1,$pref2,$comm,$mrca,$d1,$d2,$f1);

    defined($pref1 = $tabP->[0]->{$node1}) || confess "Missing indexes? node1=$node1";
    defined($pref2 = $tabP->[0]->{$node2}) || confess "Missing indexes? node2=$node2";
    $comm = &common_prefix([$pref1,$pref2]);
    $mrca = $tabP->[1]->{$comm};
    $d1 = &dist_from_root($mrca,$node1,$tabP);
    $d2 = &dist_from_root($mrca,$node2,$tabP);
#   print STDERR "d1=$d1 d2=$d2 to $mrca->[0]\n";
    if (($d1 >= 0) && ($d2 >= 0) && ($d1 + $d2) > 0)
    {
	$f1 = $d1 / ($d1+$d2);
	if ($f1 > $frac)
	{
	    return &root_above($tabP,$node1,($frac * ($d1 + $d2)));
	}
	elsif ($frac > $f1)
	{
	    return &root_above($tabP,$node2,((1 - $frac) * ($d1 + $d2)));
	}
	else
	{
	    return &root_tree($tabP,$mrca,1.0e-5);
	}
    }
    else
    {
	return &root_tree($tabP,$mrca,1.0e-5);
    }
}

sub root_above {
    my($tabP,$node,$dist) = @_;

    while ($dist > $node->[1])
    {
	$dist -= $node->[1];
	$node  = $node->[2]->[0];
    }
    return &root_tree($tabP,$node,($dist / $node->[1]));
}

sub neighborhood_of_tree_point {
    my($tabP,$where,$sz) = @_;
    my($nd1,$nd2,$node1,$node2,$fract,$tree1,$tagged_tips,@best,$tips,$x);

    ($node1,$node2,$fract) = @$where;
    $nd1 = &locate_node($node1,$tabP);
    $nd2 = &locate_node($node2,$tabP);
    ($tree1 = &root_tree_between_nodes($nd1,$nd2,$fract,$tabP))
	|| confess "could not root tree at insertion point";
    $tagged_tips = &prioritized_neighborhood_tips($tree1);
    @best = sort by_arg1 @$tagged_tips;
    if (@best > $sz)
    {
	$#best = $sz-1;
    }
    $tips = {};
    foreach $x (@best)
    {
	$tips->{$x->[1]} = 1;
    }
    return &subtree($tree1,$tips);
}

sub prioritized_neighborhood_tips {
    my($tree) = @_;
    my($best,$discards);

    ($best,$discards) = &prioritized_neighborhood_tips1($tree,0.0);
    unshift(@$discards,[0.0,$best->[1]]);
    return $discards;
}

sub prioritized_neighborhood_tips1 {
    my($tree,$depth) = @_;
    my($best,$discards,$d,@keepers,@discards,$desc,$i,$keeper,$x);

    defined($tree->[1]) || confess "bad tree?";
    $d = $depth + $tree->[1];
    if ($#{$tree->[2]} == 0)
    {
	return ([$d,$tree->[0]],[]);
    }

    @keepers  = ();
    @discards = ();
    $desc = $tree->[2];
    for ($i=1; ($i <= $#{$desc}); $i++)
    {
	($keeper,$discards) = &prioritized_neighborhood_tips1($desc->[$i],$d);
	push(@keepers,$keeper);
	push(@discards,@$discards);
    }
    @keepers = sort by_arg1 @keepers;
    $best    = shift @keepers;
    foreach $x (@keepers)
    {
	$x->[0] = $d;
	push(@discards,$x);
    }
    return ($best,\@discards);
}

sub by_arg1 {
    return ($a->[0] <=> $b->[0]);
}

sub relabel_nodes {
    my($tree,$relabel) = @_;
    my($x,$i,$ptrs);

    if ($tree->[0] && ($x = $relabel->{$tree->[0]}))
    {
	if (($x !~ /^\'/) && ($x =~ /[ \(\)\[\]\'\:\;\,]/))
	{
	    $x = "'$x'";
	}
	$tree->[0] = $x;
    }
    $ptrs  = &node_pointers($tree);    
    for ($i=1; ($i <= $#{$ptrs}); $i++)
    {
	&relabel_nodes($ptrs->[$i],$relabel);
    }
}

1;

