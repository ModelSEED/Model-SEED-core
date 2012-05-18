# This is a SAS component
#
# Copyright (c) 2003-2010 University of Chicago and Fellowship
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

package ffxtree;

use strict;

use Carp;
use Data::Dumper;
use File::Copy;

use SAPserver;
use SeedAware;
use SeedUtils;

use gjoalign2html;
use gjoalignment;
use gjonewicklib;
use gjophylip;
use gjoseqlib;


#-------------------------------------------------------------------------------
#  Extract alignment from FASTA file, array or options hash.
#
#    ($ali, $opts) = process_input_args_w_ali(\@align, $opts)
#    ($ali, $opts) = process_input_args_w_ali($alignF, $opts)
#    ($ali, $opts) = process_input_args_w_ali($opts)
#
#    $opts         = process_input_args_w_ali(\@align, $opts)
#    $opts         = process_input_args_w_ali($alignF, $opts)
#    $opts         = process_input_args_w_ali($opts)
#
#-------------------------------------------------------------------------------

sub process_input_args_w_ali {
    my ($ali, $opts);

    $ali   = shift @_ if ref $_[0] eq 'ARRAY' || -s $_[0];
    $opts  = shift @_ if ref $_[0] eq 'HASH';

    $ali ||= $opts->{ali} || $opts->{align} || $opts->{alignment} || $opts->{seqs};

    $ali  = gjoseqlib::read_fasta($ali) if $ali && -s $ali;

    wantarray ? ($ali, $opts) : {ali => $ali, %$opts};
}


#-------------------------------------------------------------------------------
#  Extract alignment from FASTA file, array or options hash.
#
#    ($ali, $opts) = process_input_args_w_ali($treeRef, $opts)
#    ($ali, $opts) = process_input_args_w_ali($treeF,  $opts)
#    ($ali, $opts) = process_input_args_w_ali($opts)
#
#    $opts         = process_input_args_w_ali($treeRef, $opts)
#    $opts         = process_input_args_w_ali($treeF,  $opts)
#    $opts         = process_input_args_w_ali($opts)
#
#-------------------------------------------------------------------------------

sub process_input_args_w_tree {
    my ($tree, $opts);

    $tree   = shift @_ if ref $_[0] eq 'ARRAY' || -s $_[0];
    $opts   = shift @_ if ref $_[0] eq 'HASH';

    $tree ||= $opts->{tree};
    $tree   = read_tree($tree) if $tree && -s $tree;

    wantarray ? ($tree, $opts) : {tree => $tree, %$opts};
}

#-------------------------------------------------------------------------------
#  Break options hash into two hashes of values and flags
#-------------------------------------------------------------------------------

sub process_options_string {
    my @args = split(/\s+/, $_[0]);
    my ($vals, $flags);

    while ($_ = shift @args) {
        if (/^-([-a-zA-Z]\w*)/i) {
            my $k = $1;
            if (@args > 0 && $args[0] !~ /^-[-a-zA-Z]/i) {
                $vals->{$k}  = shift @args;
            } else {
                $flags->{$k} = 1;
            }
        }
    }
    return ($vals, $flags);
}


#-------------------------------------------------------------------------------
#  Combine two hashes of values and hashes into a paramter array
#-------------------------------------------------------------------------------

sub make_params_from_vals_and_flags {
    my ($vals, $flags) = @_;
    my @params;

    if ($vals) {
        for (keys %$vals) {
            if ($vals->{$_}) {
                push @params, "-$_";
                push @params, $vals->{$_};
            }
        }
    }
    
    if ($flags) {
        push @params, "-$_" for keys %$flags;
    }

    return @params;
}


#-----------------------------------------------------------------------------
#  Read newick tree:
#     
#     $tree = \@root_node                #  node structure defined in gjonewicklib
#
#     $tree = read_tree( $tree )         #  pass through
#     $tree = read_tree( )               #  STDIN
#     $tree = read_tree( \*FILEHANDLE )
#     $tree = read_tree(  $filename )
#     $tree = read_tree( \$string )      #  reference to file as string
#
#-----------------------------------------------------------------------------

sub read_tree {
    my $tree;
    if ( $_[0] && ref $_[0] eq 'ARRAY'  ) {
        $tree = $_[0];
    } elsif ( $_[0] && ref $_[0] eq 'SCALAR' ) {
        $tree = parse_newick_tree_str( ${$_[0]} );
    } else {
        $tree = parse_newick_tree_str( SeedAware::slurp_input( @_ ) );
    }
    return $tree;
}


#-------------------------------------------------------------------------------
#  Tree sequence with FastTree and return the tree. Tree is gjonewick format.
#
#     $tree           = tree_with_fasttree(\@ali, \%opts);
#    ($tree, \%stats) = tree_with_fasttree(\@ali, \%opts);
#   
#    @ali is composed of triples: ($id, $defined, $sequence)
#
#  Optional:
#
#     treefile   => tree_file_name
#     logfile    => log_file_name
#     input      => input_tree
#
#     params     => fasttree_param_string
#       or
#     search     => topolog_search_method # NNI (d), SPR
#     rate       => rate_distribution     # Gamma (d), Uniform 
#     model      => substitution_model    # nt: GTR (d)
#                                         # aa: JTT (d)
#     nclasses   => num_subst_categories  # 20 (d)
#     optimize   => all (d, topology && brlen && parameters),
#                   eval (optimize branch length only, under CAT model,
#                   and evaluate the likelihood under the discrete gamma model
#                   with the same number of categories)
#
#-------------------------------------------------------------------------------

sub tree_with_fasttree {
    my ($ali, $opts) = process_input_args_w_ali(@_);

    $ali      or die "tree_with_fasttree requires alignment";
    @$ali > 2 or die "tree_with_fasttree requires alignment with at least 3 sequences";

    my $type = gjoalignment::guess_seq_type($ali->[0]->[2]);

    my ($ali2, $id, $local_id) = ($type eq 'p') ? gjophylip::process_protein_alignment($ali)
                                                : gjophylip::process_dna_alignment($ali);

    my $tmpdir  = SeedAware::location_of_tmp($opts);
    my $tmpin   = SeedAware::new_file_name("$tmpdir/input_for_fasttree$$", 'fasta');
    my $tmptree = SeedAware::new_file_name("$tmpdir/fasttree$$", 'newick');
    my $tmptr2  = SeedAware::new_file_name("$tmpdir/fasttree_intree$$", 'newick');
    my $tmplog  = SeedAware::new_file_name("$tmpdir/fasttree$$", 'log');

    gjoseqlib::print_alignment_as_fasta($tmpin, $ali2);

    my ($vals, $flags) = process_options_string($opts->{params});

    $opts->{search}   ||= 'NNI';
    $opts->{rate}     ||= 'Gamma';
    $opts->{optimize} ||= 'all';
    $opts->{nclasses} ||= 20;

    $flags->{nt}      = 1      if $type eq 'n';
    $flags->{gamma}   = 1      if $opts->{rate}   =~ /Gamma/i;
    $flags->{nome}    = 1      if $opts->{nome};
    $flags->{noml}    = 1      if $opts->{noml};
    $flags->{mllen}   = 1      if $opts->{mllen};

    $vals->{spr}    ||= 4      if $opts->{search} =~ /SPR/i;
    $vals->{spr}      = undef  if $opts->{search} =~ /NNI/i;
    $vals->{cat}    ||= $opts->{nclasses} || 20;


    if (($opts->{optimize} =~ /eval/i || $opts->{eval}) && $opts->{input}) {
        my $tr2 = read_tree($opts->{input});
        gjonewicklib::newick_relabel_nodes($tr2, $local_id);
        gjonewicklib::writeNewickTree($tr2, $tmptr2);

        $vals->{intree} = $tmptr2;
        $flags->{nome}  = 1;
        $flags->{mllen} = 1;
        $flags->{gamma} = 1;
    }

    my @params = make_params_from_vals_and_flags($vals, $flags);

    my $fasttree = SeedAware::executable_for($opts->{fasttree} || $opts->{program} || 'fasttree');

    # print STDERR join(" ", $fasttree, @params, $tmpin). "\n";
    SeedAware::system_with_redirect($fasttree, @params, $tmpin, { stdout => $tmptree, stderr => $tmplog });

    my $tree = gjonewicklib::read_newick_tree($tmptree);
    my $info = SeedAware::slurp_input($tmplog);
    my $stats;

    if ($info =~ /LogLk\s*=\s*(\S+)\s*(alpha|Time)/) {
        $stats->{logLk} = $1;
    }
    if ($info =~ /Total time: (\S+)/) {
        $stats->{time}  = trim_timestr($1);
    }
    
    gjonewicklib::newick_relabel_nodes($tree, $id);

    gjonewicklib::writeNewickTree($tree, $opts->{treefile}) if $opts->{treefile};
    copy($tmplog,  $opts->{logfile})                        if $opts->{logfile};

    for ($tmpin, $tmptree, $tmplog, $tmptr2) {
        unlink $_ if -e $_;
    }
    
    wantarray() ? ($tree, $stats) : $tree;
}


#-------------------------------------------------------------------------------
#  Tree aligned sequences with PhyML and return the tree. Tree is gjonewick format.
#
#     $tree           = tree_with_phyml(\@alignment, \%opts);
#    ($tree, \%stats) = tree_with_phyml(\@alignment, \%opts);
#   
#    @alignment is composed of triples: ($id, $defined, $sequence)
#
#  Optional:
#
#     treefile   => tree_file_name
#     logfile    => log_file_name
#
#     params     => phyml_param_string
#       or
#     search     => topolog_search_method # NNI (d), SPR, BEST
#     model      => substitution_model    # nt: HKY85 (d), JC69, K80, F81, F84, TN93
#                                         # aa: LG (d), JTT, WAG, MtREV, Dayhoff, DCMut
#     rate       => rate_distribution     # Gamma (d), Uniform 
#     nclasses   => num_subst_categories  # 4 (d)
#     optimize   => all (d, topology && brlen && parameters), eval (optimize model parameters only)
#     input      => input tree            # tree file name
#
#-------------------------------------------------------------------------------

sub tree_with_phyml {
    my ($ali, $opts) = process_input_args_w_ali(@_);

    $ali      or die "tree_with_phyml requires alignment";
    @$ali > 2 or die "tree_with_phyml requires alignment with at least 3 sequences";

    my $type = gjoalignment::guess_seq_type($ali->[0]->[2]);

    my ($ali2, $id, $local_id) = ($type eq 'p') ? gjophylip::process_protein_alignment($ali)
                                                : gjophylip::process_dna_alignment($ali);

    my $tmpdir  = SeedAware::location_of_tmp($opts);
    my $tmpin   = SeedAware::new_file_name("$tmpdir/input_for_phyml$$", 'phylip');
    my $tmptr2  = SeedAware::new_file_name("$tmpdir/phyml_intree$$", 'newick');
    my $tmplog  = SeedAware::new_file_name("$tmpdir/phyml$$", 'log');
    my $tmptree = "$tmpin\_phyml_tree.txt"; # PHYML hard-coded output tree
    my $tmplog2 = "$tmpin\_phyml_stats.txt"; # PHYML hard-coded stats file

    $type = ($type eq 'p') ? "aa" : "nt";

    gjoseqlib::print_alignment_as_phylip($tmpin, $ali2);

    my ($vals, $flags) = process_options_string($opts->{params});

    $opts->{search}   ||= 'NNI';
    $opts->{rate}     ||= 'Gamma';
    $opts->{optimize} ||= 'all';
    $opts->{nclasses} ||= ($opts->{rate} =~ /Uniform/i) ? 1 : 4;
    $opts->{model}    ||= ($type eq 'aa') ? 'LG' : 'HKY85';

    $flags->{-quiet}    = 1;
    $vals->{i}          = $tmpin;
    $vals->{d}          = $type;
    $vals->{c}          = $opts->{nclasses};
    $vals->{s}          = uc $opts->{search};
    $vals->{m}          = uc $opts->{model};
    $vals->{o}          = 'tlr';

    if (($opts->{optimize} =~ /eval/i || $opts->{eval}) && $opts->{input}) {
        my $tr2 = read_tree($opts->{input});
        gjonewicklib::newick_relabel_nodes($tr2, $local_id);
        gjonewicklib::writeNewickTree($tr2, $tmptr2);

        $vals->{u} = $tmptr2;
        $vals->{o} = 'n';
        $vals->{b} = '0';
    }

    my @params = make_params_from_vals_and_flags($vals, $flags);

    my $phyml = SeedAware::executable_for($opts->{phyml} || $opts->{program} || 'phyml');

    SeedAware::system_with_redirect($phyml, @params, { stdout => $tmplog, stderr => '/dev/null' });
    # print STDERR join(" ", $phyml, @params). "\n";

    my $tree  = gjonewicklib::read_newick_tree($tmptree);
    my $info  = SeedAware::slurp_input($tmplog);
    my $info2 = SeedAware::slurp_input($tmplog2);
    my $stats;

    if ($info =~ /Log likelihood of the current tree: (\S+)\./) {
        $stats->{logLk} = $1;
    }
    if ($info =~ /Time used (\S+)/i) {
        $stats->{time}  = trim_timestr($1);
    }

    gjonewicklib::newick_relabel_nodes($tree, $id);
    gjonewicklib::writeNewickTree($tree, $opts->{treefile})    if $opts->{treefile};
    AlignTree::print_string($opts->{logfile}, "$info\n$info2") if $opts->{logfile};

    my @tmpfiles = map { "$tmpin\_phyml_$_.txt" }
        qw(tree stats boot_trees boot_stats rand_trees);

    for ($tmpin, $tmptr2, $tmplog, @tmpfiles) {
        unlink $_ if -e $_;
    }
    
    wantarray() ? ($tree, $stats) : $tree;
}

#-------------------------------------------------------------------------------
#  Get a rough estimate PhyML's computation time in seconds
#    PhymlFAQ: http://www.atgc-montpellier.fr/phyml/faq.php
#-------------------------------------------------------------------------------
sub estimate_phyml_time {
    my ($seqs, $opts) = @_;

    my ($ntaxa, $seqlen, $type, $nclasses, $search, $bootstrap);
    $ntaxa     = @$seqs;
    $seqlen    = length($seqs->[0]->[2]);
    $type      = guess_type($seqs->[0]->[2]);
    $type      = ($type eq 'p') ? 12 : 1;
    $bootstrap = 1;

    my $params = $opts->{params};
    if ($params) {
        $nclasses = ($params =~ /-c\s+(\d+)/) ? $1 : 1;
        $search   = ($params =~ /-s\s+best/i) ?  5 : 
                    ($params =~ /-s\s+spr/i)  ?  4 : 1;   
    } else {
        $nclasses = defined $opts->{nclasses} ? $opts->{nclasses} : 4;
        $search   = defined $opts->{search}   ? $opts->{search}   : 'NNI';
        $search   = (lc $search eq 'best') ?  5 : 
                    (lc $search eq 'spr')  ?  4 : 1;   
    }

    return ($ntaxa * $ntaxa * $seqlen * $type * $nclasses * $search * $bootstrap) / 400000;
}


#-------------------------------------------------------------------------------
#  Tree sequence with RAxML and return the tree. Tree is gjonewick format.
#
#     $tree           = tree_with_raxml(\@alignment, \%opts);
#    ($tree, \%stats) = tree_with_raxml(\@alignment, \%opts);
#   
#    @alignment is composed of triples: ($id, $defined, $sequence)
#
#  Optional:
#
#     treefile   => tree_file_name
#     logfile    => log_file_name
#
#     params     => phyml_param_string
#       or
#     search     => search algorithm      # SPR|d (d, rapid hill-climbing), o (old slower search)
#     model      => substitution_model    # nt: GTR (d)
#                                         # aa: WAG (d), DAYHOFF, DCMUT, JTT, MTREV, RTREV, CPREV, VT, BLOSUM62, MTMAM, GTR
#     rate       => rate_distribution     # Gamma (d), Uniform 
#     nclasses   => num_subst_categories  # 4 (d)
#     optimize   => all (d, topology && brlen && parameters), eval (optimize brlen and model parameters)
#     input      => input tree            # tree file name
#
#-------------------------------------------------------------------------------

sub tree_with_raxml {
    my ($ali, $opts) = process_input_args_w_ali(@_);
    
    $ali      or die "tree_with_raxml requires alignment";
    @$ali > 2 or die "tree_with_raxml requires alignment with at least 3 sequences";

    my $type = gjoalignment::guess_seq_type($ali->[0]->[2]);

    my ($ali2, $id, $local_id) = ($type eq 'p') ? gjophylip::process_protein_alignment($ali)
                                                : gjophylip::process_dna_alignment($ali);

    my $tmpkey  = "$$";
    my $tmpdir  = SeedAware::location_of_tmp($opts);
    my $tmpin   = SeedAware::new_file_name("$tmpdir/input_for_raxml", 'phylip');
    my $tmptr2  = SeedAware::new_file_name("$tmpdir/raxml_intree", 'newick');
    my $tmplog  = SeedAware::new_file_name("$tmpdir/raxml", 'log');
    my $tmptree = "$tmpdir/RAxML_result.$tmpkey";
    my $tmplog2 = "$tmpdir/RAxML_parsimonyTree.$tmpkey";

    $type = ($type eq 'p') ? "PROT" : "GTR";

    gjoseqlib::print_alignment_as_phylip($tmpin, $ali2);

    my ($vals, $flags) = process_options_string($opts->{params});

    $opts->{search}   ||= 'SPR';
    $opts->{rate}       = uc $opts->{rate}  || 'GAMMA';
    $opts->{rate}       = 'CAT'   if $opts->{rate}     =~ /Uniform/i;
    $opts->{rate}       = 'GAMMA' if $opts->{optimize} =~ /eval/i;
    $opts->{model}      = uc $opts->{model} || ($type eq 'PROT' ? 'WAG' : '');
    $opts->{nclasses} ||= ($opts->{rate} =~ /Uniform/i) ? 1 : 4;
    $opts->{optimize} ||= 'all';

    $vals->{f}          = 'd' if $opts->{search} =~ /SPR/i;
    $vals->{f}          = $opts->{search} if $opts->{search} =~ /[abcdeghijmnopqstwx]/;
    $vals->{c}          = $opts->{nclasses};
    $vals->{m}          = $type . $opts->{rate} . $opts->{model};
    $vals->{w}          = "$tmpdir/";
    $vals->{n}          = $tmpkey;
    $vals->{s}          = $tmpin;
    
    if (($opts->{optimize} =~ /eval/i || $opts->{eval}) && $opts->{input}) {
        my $tr2 = read_tree($opts->{input});
        gjonewicklib::newick_relabel_nodes($tr2, $local_id);
        remove_internal_labels($tr2);
        gjonewicklib::writeNewickTree($tr2, $tmptr2);

        $vals->{t} = $tmptr2;
        $vals->{f} = 'e';
    }

    my @params = make_params_from_vals_and_flags($vals, $flags);

    my $raxml = SeedAware::executable_for($opts->{raxml} || $opts->{program} || 'raxmlHPC');

    SeedAware::system_with_redirect($raxml, @params, { stdout => $tmplog, stderr => '/dev/null' });
    # print STDERR join(" ", $raxml, @params). "\n";

    my $tree  = gjonewicklib::read_newick_tree($tmptree);
    my $info  = SeedAware::slurp_input($tmplog);
    my $info2 = SeedAware::slurp_input($tmplog2);
    my $stats;

    if ($info =~ /Overall Time for \d+ Inference\s*(\S+)/) {
        $stats->{time}  = $1;
    } elsif ($info =~ /Overall Time for Tree Evaluation\s*(\S+)/) {
        $stats->{time}  = $1;
    }

    if ($info =~ /Likelihood   :\s*(\S+)/) {
        $stats->{logLk} = $1;
    } elsif ($info =~ /Final .* likelihood:\s*(\S+)/) {
        $stats->{logLk} = $1;
    }

    gjonewicklib::newick_relabel_nodes($tree, $id);
    gjonewicklib::writeNewickTree($tree, $opts->{treefile})    if $opts->{treefile};
    AlignTree::print_string($opts->{logfile}, "$info\n$info2") if $opts->{logfile};

    my @tmpfiles = map { "$tmpdir/RAxML_$_.$tmpkey" }
        qw(result info log);

    for ($tmpin, $tmptr2, $tmplog, $tmplog2, @tmpfiles) {
        unlink $_ if -e $_;
    }

    wantarray() ? ($tree, $stats) : $tree;
}


#-------------------------------------------------------------------------------
#  Get a rough estimate RAxML's computation time in seconds:
#    about 4x slower for protein sequences
#-------------------------------------------------------------------------------

sub estimate_raxml_time {
    my ($seqs, $opts) = @_;
    return 4 * estimate_phyml_time($seqs, $opts);
}


#-------------------------------------------------------------------------------
#  Recursively remove internal labels (e.g. bootstrap / branch support values)
#-------------------------------------------------------------------------------

sub remove_internal_labels {
    my ($node) = @_;
    my $ndesc;
    if ($ndesc = gjonewicklib::newick_n_desc($node)) {
        gjonewicklib::set_newick_lbl($node, undef);
        for (my $i = 1; $i <= $ndesc; $i++) {
            my $desc  = gjonewicklib::newick_desc_i($node, $i);
            remove_internal_labels($desc);
        }
    }
}


sub timestr_to_seconds {
    my ($str) = @_;
    $str =~ s/\s//g;
    my @units  = (1, 60, 60, 24);
    for (my $i = 1; $i < @units; $i++) {
        $units[$i] = $units[$i - 1] * $units[$i];
    }
    my $secs;
    my $i = 0;
    while ($str) {
        if ($str =~ /^(.*?)[dhms:]$/) {
            $str = $1;
        } 
        if ($str =~ /^(.*?)([.0-9]+)\s*$/) {
            $secs += $2 * $units[$i];
            $str   = $1;
        }
        $i++;
    }
    return $secs;
}

sub seconds_to_timestr {
    my $secs = int(shift);
    my @labels = qw(s m h d);
    my @units  = (60, 60, 24);
    my $str;
    my $i = 0;
    while ($secs > 0 && $i < @units) {
        $str  = ($secs % $units[$i]) . $labels[$i] . $str;
        $secs = int($secs / $units[$i]);
        $i++;
    }
    $str = $secs . $labels[$i] . $str if $secs > 0;
    return $str ? $str : '0s';
}

sub trim_timestr { seconds_to_timestr(timestr_to_seconds(shift)) }


#-----------------------------------------------------------------------------
#  Classify tips of tree into cohesion groups
#
#     \%cohesion_group  = make_cohesion_groups( $tree, $opts)
#
#  Options:
#
#    cg_cutoff       =>  $threshold     # collapse subtrees whose root branch has
#                                      support values greater than cutoff (D = 0.85)
#    max_fract       =>  fraction       # max fraction of a cohesion group (D = 0.50)
#    max_cg_size     =>  cg_size        # max size of a cohesion group (D = unlimited)
#    show_orphan     =>  bool           # label all orphan cohension groups as 'Orp'
#    single_collpase =>  bool           # no more than one collapse;
#                                         first collpase the largest one within the size limit above bootstrap level 
#
#  Based on Roy A. Jensen's cohesion group method (PubMed ID: 18322033)
#    
#-----------------------------------------------------------------------------
sub make_cohesion_groups {
    my ($tree, $opts) = @_;

    my @tips  = gjonewicklib::newick_tip_list($tree);
    my $fract = $opts->{max_fract} || $opts->{max_cg_fraction}  || 0.50;
    my $maxcg = $opts->{max_cg}    || $opts->{max_cg_size}      || scalar @tips;
    
    $opts->{max_cg_size} = SeedUtils::min(@tips * $fract, $maxcg);
    
    make_cohesion_groups_helper($tree, $opts);

    my %cg;

    my $group = $opts->{cohesion_group};
    my $count = $opts->{cohesion_group_count};

    if ($count) {
        my @ordered = map  { $_->[0] }
                      sort { $b->[1] <=> $a->[1] }
                      map  { [ $_, $count->{$_} ] } keys %$count;

        my %newgrp;
        my $i;
        for (@ordered) {
            $newgrp{$_} = 'CG-' . ++$i;
            $newgrp{$_} = 'Orp' if $opts->{show_orphan} && $count->{$_} == 1;
        }
        
        %cg = map { $_ => $newgrp{$group->{$_}} } gjonewicklib::newick_tip_list($tree);
    }

    return \%cg;
}

sub make_cohesion_groups_helper {
    my ($node, $opts) = @_;

    my $cutoff = $opts->{cg_cutoff} || $opts->{cohesion_group_cutoff} || 0.85;
    my $maxcg  = $opts->{max_cg}    || $opts->{max_cg_size};

    my @desc  = gjonewicklib::newick_desc_list($node);
    my $label = gjonewicklib::newick_lbl($node);

    if (@desc) {
        # print STDERR "ndesc = ". scalar@desc."\t b = ". $label."\t maxcg = $maxcg\n";
        my @tips = gjonewicklib::newick_tip_list($node);
        if ($label && $label >= $cutoff && (!$maxcg || @tips <= $maxcg)) {
            my @tips = gjonewicklib::newick_tip_list($node);
            my $group = ++$opts->{cohesion_group_total};
            for (@tips) {
                $opts->{cohesion_group}->{$_} = $group;
                $opts->{cohesion_group_count}->{$group}++;
            }
        } else {
            make_cohesion_groups_helper($_, $opts) for @desc;
        }
    } else {
        my $group = ++$opts->{cohesion_group_total};
        $opts->{cohesion_group}->{$label} = $group;
        $opts->{cohesion_group_count}->{$group}++;
    }
}


#-----------------------------------------------------------------------------
#  Tree-based similarity calculation 
#
#-----------------------------------------------------------------------------

sub tip_to_tip_distances {
    my ($tree) = @_;

    my ($dist, $height) = ({}, {});
    
    tip_to_tip_distances_helper($tree, $dist, $height);

    return $dist;
}

sub tip_to_tip_distances_helper {
    my ($node, $dist, $height) = @_;

    my @lbls;

    my @desc = gjonewicklib::newick_desc_list( $node );
    
    if (@desc) {
        my @brlbls;
        foreach (@desc) {
            my $x   = gjonewicklib::newick_x($_);
            my @lbl = tip_to_tip_distances_helper($_, $dist, $height);
            for my $tip (@lbl) { $height->{$tip} += $x }
            push @brlbls, \@lbl;
            push @lbls, @lbl;
        }
        my $n = $#brlbls;
        for my $i (0 .. $n-1) {
            for my $j ($i+1 .. $n) {
                for my $x (@{$brlbls[$i]}) {
                    for my $y (@{$brlbls[$j]}) {
                        $dist->{"$x,$y"}  = $dist->{"$y,$x"}  = $height->{$x} + $height->{$y};
                        $dist->{$x}->{$y} = $dist->{$y}->{$x} = $height->{$x} + $height->{$y};
                    }
                }
            }
        }
        return @lbls;
    } else {
        my $lbl = gjonewicklib::newick_lbl($node);
        $height->{$lbl} = 0;
        return $lbl;
    }
}


sub distances_from_tip {
    my ($tree, $tip) = @_;

    my ($dist, $height) = ({}, {});
    
    distances_from_tip_helper($tree, $tip, $dist, $height);

    return $dist;
}

sub distances_from_tip_helper {
    my ($node, $tip, $dist, $height) = @_;

    my @lbls;

    my @desc = gjonewicklib::newick_desc_list( $node );
    
    if (@desc) {
        my $desc_has_tip;
        my @tips_to_update;
        foreach (@desc) {
            my $x   = gjonewicklib::newick_x($_);
            my @lbl = distances_from_tip_helper($_, $tip, $dist, $height);
            my $has_tip;
            for (@lbl) {
                $height->{$_} += $x;
                $has_tip = $desc_has_tip = 1 if $_ eq $tip;
            }
            push @tips_to_update, @lbl unless $has_tip;
            push @lbls, @lbl;
        }
        if ($desc_has_tip) {
            for (@tips_to_update) {
                $dist->{$_} = $height->{$_} + $height->{$tip};
            }
        }
        return @lbls;
    } else {
        my $lbl = gjonewicklib::newick_lbl($node);
        $height->{$lbl} = 0;
        return $lbl;
    }
}

#-----------------------------------------------------------------------------
#  Read hash from a two-column table:
#
#     \%hash = read_hash( \%hash )        #  copy
#     \%hash = read_hash( )               #  STDIN
#     \%hash = read_hash( \*FILEHANDLE )
#     \%hash = read_hash(  $filename )
#     \%hash = read_hash( \$string )      #  reference to file as string
#
#-----------------------------------------------------------------------------

sub read_hash {
    my %hash;
    if ( $_[0] && ref $_[0] eq 'HASH' ) {
        %hash = %{$_[0]};
    } elsif ( $_[0] && ref $_[0] eq 'SCALAR' ) {
        %hash = map { /^\s*(\S+)\s+(\S.*?)\s*$/ ? ( $1 => $2 ) : () }
                split /\n/, ${$_[0]};
    } else {
        %hash = map { /^\s*(\S+)\s+(\S.*?)\s*$/ ? ( $1 => $2 ) : () }
                split /\n/,  SeedAware::slurp_input( @_ );
    }
    return \%hash;
}

#-----------------------------------------------------------------------------
#  Read set from a space delimited file of IDs
#
#     \%set = read_set( \%set )        #  copy
#     \%set = read_set( )               #  STDIN
#     \%set = read_set( \*FILEHANDLE )
#     \%set = read_set(  $filename )
#     \%set = read_set( \$string )      #  reference to file as string
#
#-----------------------------------------------------------------------------

sub read_set {
    my %set;
    if ( $_[0] && ref $_[0] eq 'HASH' ) {
        %set = %{$_[0]};
    } elsif ( $_[0] && ref $_[0] eq 'SCALAR' ) {
        %set = map { $_ => 1 }
               split /\s+/, ${$_[0]};
    } else {
        %set = map { $_ => 1 }
               split /\s+/, SeedAware::slurp_input( @_ );
    }
    return \%set;
}


#-------------------------------------------------------------------------------
#  Convert a newick tree to an HTML string
#
#     $html           = tree_to_html($tree, \%opts);
#     $html           = tree_to_html(\%opts);         # $tree = $opt{tree}
#   
#  Optional:
#
#     alias         => \%id_to_alias          # aliases for tips, often used for id => peg mapping
#                                               tree tips will be relabeled with aliases
#     anno          => bool                   # set http links to annotator's SEED
#     color_by      => \%id_to_group or $str  # classify tips into gruops, and paint tips in the same group with the same color
#                                               'taxonomy' (D), 'role', a hash, or 0
#     collapse_by   => \%id_to_group or $str  # classify tips into gruops, and collapse subtrees whose tips all belong to the same group
#                                               'genus' (D), 'species', a hash, or 0
#     collapse_show => \%keep_ids             # preferred tips to show when collapsing subtrees
#                                               'woese' (D), a hash, or 0
#     desc          => \%id_to_desc           # descriptions for tip:
#                                               to appear in parentheses of tree tip labels
#     focus_set     => \%focus_ids            # highlight a set of tips
#     gray          => $n                     # gray out name from the n-th word (D = 2)
#     keep          => \%keep_ids             # keep only the taxa in hash
#     link          => \%id_to_link           # insert http links for tips
#     text_link     => \%id_to_text_and_link  # insert extra text with link for tips
#     nc            => $n                     # maximum number of colors (D = 10)
#     popup         => \%id_to_popup          # mouseovers for tips:             
#                                               to appear in 'Description' field of tip popup window
#     raw           => bool                   # paint the original tree
#     title         => $str                   # title for HTML page
#
#     For each tip, if an associated FIG ID can be found in the label or alias hash,
#     taxonomy and function information is automatically retrieved from PSEED or SEED
#     via SAPserver, depending on whether the $ENV{SAS_SERVER} is set to 'PSEED'. 
#     
#-------------------------------------------------------------------------------

sub tree_to_html {
    my ($tree, $opts) = process_input_args_w_tree(@_);

    $opts->{gray}          ||= 2          unless defined $opts->{gray};
    $opts->{color_by}      ||= 'taxonomy' unless defined $opts->{color_by}; 
    $opts->{collapse_by}   ||= 'genus'    unless defined $opts->{collapse_by};
    $opts->{collapse_show} ||= 'woese'    unless defined $opts->{collapse_show};

    my $css    = html_tree_css    ($tree, $opts); # print STDERR $css;
    my $js     = html_tree_js     ($tree, $opts);
    my $body   = html_tree_body   ($tree, $opts);
    my $title  = html_tree_title  ($tree, $opts);
    my $legend = html_tree_legend ($tree, $opts);

    <<End_of_Page;
<html>

<head>
<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
<title>$title</title>
$css
</head>

<body>
$js
<pre>
$body
$legend
</pre>
</body>

</html>
End_of_Page
}

sub html_tree_title {
    my ($tree, $opts) = @_;

    my $title ||= $opts->{title};
    my $legend  = $opts->{color_legend};
    my $by      = $opts->{role} || (($legend ne 'taxonomy') && $opts->{color_by});

    if ($by && ref $by eq 'HASH') {
        my %cnt;
        $cnt{$_}++ for values %$by;
        
        my @key = sort { $cnt{$b} <=> $cnt{$a} } keys %cnt;
        $title ||= length($key[0]) > 0 ? $key[0] : $key[1];
    }
    return $title;
}

sub html_tree_css {
    my $css_main       = css_snippet_main();
    my $css_auxilary   = css_snippet_auxilary();
    my $css_taxonomy   = css_snippet_taxonomy();
    my $css_top_colors = css_snippet_top_colors();

    my @lines = map { css_from_hash($_) } ($css_main, $css_auxilary, $css_taxonomy, $css_top_colors);

    return join("\n", @lines). "\n";
}

sub html_tree_js {
    return mouseover_javascript();
}


#-------------------------------------------------------------------------------
#  Generate a legend table for tree coloring:
#
#    $html_string = html_tree_legend($tree, $opts)
#
#    If tips are colored based on taxonomy groups, a taxonomy legend is shown.
#    Otherwise, a table of color group (functional role by default) frequencies is shown.
#
#-------------------------------------------------------------------------------
sub html_tree_legend {
    my ($tree, $opts) = @_;
    my $legend = $opts->{color_legend};

    if ($legend eq 'taxonomy' && $opts->{tax} && %{$opts->{tax}}) {
        return html_tree_taxonomy_legend();     
    } elsif ($legend && ref $legend eq 'HASH') {
        my %cnt;
        for (values %{$opts->{color}}) {
            $cnt{$_}++;
        }

        my @keys = sort { $legend->{$a} cmp $legend->{$b} } keys %$legend;
        my @table;
        push @table, '  <table border="0">';
        push @table, "  <tr><td>". span_css($_, $legend->{$_}). "</td><td>". span_css(" (".$cnt{$legend->{$_}}.")", $legend->{$_}) ."</td></tr>" for @keys;
        push @table, "  <tr><td> Others </td><td>(". $cnt{''} .")</td></tr>" if $cnt{''} > 0;
        push @table, '  </table>';
        return join("\n", @table);
    }
}

sub html_tree_taxonomy_legend {
    return <<End_of_Legend;
  <table border="0">
    <tr>
      <td class="notax">Unclassified</td>
    </tr>
    <tr>
      <td class="eukaryota">Eukaryota</td>
    </tr>
    <tr>
      <td class="archaea">Archaea</td>
    </tr>
    <tr>
      <td class="bacteria">Bacteria</td>
      <td class="actino">Actinobacteria</td>
    </tr>
    <tr>
      <td></td>
      <td class="firmi">Firmicutes</td>
    </tr>
    <tr>
      <td></td>
      <td class="cyano">Cyanobacteria</td>
    </tr>
    <tr>
      <td></td>
      <td class="spiro">Spirochaetes</td>
    </tr>
    <tr>
      <td></td>
      <td class="teneri">Tenericutes</td>
    </tr>
    <tr>
      <td></td>
      <td class="chlorobi">Bacteroidetes/Chlorobi </td>
    </tr>
    <tr>
      <td></td>
      <td>Proteobacteria</td>
      <td class="alpha">Alphaproteobacteria</td>
    </tr>
    <tr>
      <td></td>
      <td></td>
      <td class="beta">Betaproteobacteria</td>
    </tr>
    <tr>
      <td></td>
      <td></td>
      <td class="gamma">Gammaproteobacteria </td>
    </tr>
    <tr>
      <td></td>
      <td></td>
      <td></td>
      <td class="delta">Deltaproteobacteria</td>
    </tr>
    <tr>
      <td></td>
      <td></td>
      <td></td>
      <td class="epsilon">Epsilonproteobacteria</td>
    </tr>
    <tr>
      <td>Others</td>
      <td></td>
    </tr>
  </table>
End_of_Legend
}


sub collapse_identical_seqs_helper {
    my ($node, $opts) = @_;

    my $zero;
    my @desc = gjonewicklib::newick_desc_list($node);
    foreach my $d (@desc) {
        my $x   = gjonewicklib::newick_x($d);
        my $tip = gjonewicklib::newick_lbl($d);

        if (gjonewicklib::newick_n_desc($d) == 0) {
            push(@{$opts->{uniq_}}, $tip) if !$zero || $x > 0;
            if ($x <= 0) {
                if (!$zero) {
                    $zero = $tip;
                } else {
                    my $ident = $opts->{ident_tips}->{$zero};
                    my $show1 = $opts->{collapse_show}->{$zero}; 
                    my $show2 = $opts->{collapse_show}->{$tip};
                    my $new_ident;
                    if (!$show1 && $show2) {
                        $new_ident = $ident ? [@$ident, $zero] : [$zero];
                        $zero = $tip;
                        $opts->{uniq_}->[-1] = $tip;
                    } else {
                        $new_ident = $ident ? [@$ident, $tip] : [$tip];
                    }
                    $opts->{ident_tips}->{$zero} = $new_ident;
                }
            }
        } else {
            collapse_identical_seqs_helper($d, $opts);
        }
    }
}

sub collapse_identical_seqs {
    my ($tree, $opts) = @_;
    
    ($tree) = gjonewicklib::collapse_zero_length_branches($tree);

    $opts->{uniq_} = [];
    collapse_identical_seqs_helper($tree, $opts);    
    $tree = gjonewicklib::newick_subtree($tree, $opts->{uniq_});
    delete $opts->{uniq_};

    return $tree;
}


sub mark_duplicated_tips {
    my ($tree, $opts) = @_;

    my %cnt;
    my %dup = map { $cnt{$_}++ > 0 ? ($_ => 1) : () } newick_tip_list($tree);

    $opts->{dup} = \%dup;
}

sub fig_id_of {
    $_[0] =~ /(fig\|\d+\.\d+.(peg|rna).\d+)/ ? $1 : undef;
}

#-------------------------------------------------------------------------------
#  For each tip, if an associated FIG ID can be found in the label or alias hash,
#  taxonomy and function information is automatically retrieved from PSEED or SEED
#  via SAPserver, depending on whether the $ENV{SAS_SERVER} is set to 'PSEED'. 
#-------------------------------------------------------------------------------

sub assign_tip_fig_attributes {
    my ($tree, $opts) = @_;
    
    my @tips = gjonewicklib::newick_tip_list($tree);
    
    my %peg  = map { my $p = fig_id_of($_. $opts->{alias}->{$_}); $p ? ($_ => $p) : () } @tips;
    
    return unless %peg;
    
    my $sap  = SAPserver->new();
    my @pegs = values %peg;
    my %org  = map { $_ => SeedUtils::genome_of($peg{$_}) } @tips;
    my @orgs = values %org;
    my $gnm  = $sap->all_genomes();
    my %name = map { $_ => $gnm->{$org{$_}} } @tips;
    my $tax  = $sap->taxonomy_of(-ids => \@orgs);
    my %tax  = map { $org{$_} ? ($_ => $tax->{$org{$_}}) : ()} @tips;
    my $role = $sap->ids_to_functions(-ids => \@pegs);
    my %role = map { $_ => $role->{$peg{$_}} } @tips;

    $opts->{fig}  ||= \%peg;
    $opts->{tax}  ||= \%tax;
    $opts->{role} ||= \%role;
    $opts->{name} ||= \%name;
}

sub major_taxonomy_group {
    my ($tax) = @_;
    return undef unless $tax;

    my $group;
    return 'notax' unless $tax->[0];

    if ($tax->[0] =~ /Bacteria/i) {
        return 'actino'     if $tax->[1] =~ /Actinobacteria/i; # high G+C
        return 'firmi'      if $tax->[1] =~ /Firmicutes/i; # low  G+C
        return 'cyano'      if $tax->[1] =~ /Cyanobacteria/i;    
        return 'spiro'      if $tax->[1] =~ /Spirochaetes/i;
        return 'chlorobi'   if $tax->[1] =~ /Chlorobi/i;
        return 'teneri'     if $tax->[1] =~ /Tenericutes/i;
        if ($tax->[1] =~ /Proteobacteria/i) {
            return 'alpha'   if $tax->[2] =~ /Alpha/i;
            return 'beta'    if $tax->[2] =~ /Beta/i;
            return 'gamma'   if $tax->[2] =~ /Gamma/i;
            return 'delta'   if $tax->[3] =~ /Delta/i;
            return 'epsilon' if $tax->[3] =~ /Epsilon/i;
        } 
    } elsif ($tax->[0] =~ /Eukaryota/i) {
        return "eukaryota";
    } elsif ($tax->[0] =~ /Archaea/i) {
        return "archaea";
    }
    return $group;
}

sub fix_tip_color_by {
    my ($tree, $opts) = @_;
    my $by = $opts->{color_by};
    return ($tree, $opts) unless $by && ref $by ne 'HASH' && $opts->{fig};

    my @pegs = keys %{$opts->{fig}};
    if ($by =~ /tax/i && $opts->{tax}) {
        $opts->{color_by} = { map { $_ => major_taxonomy_group($opts->{tax}->{$_}) } @pegs };
        $opts->{color} ||= $opts->{color_by};
        $opts->{color_legend} = 'taxonomy';
    } elsif ($by =~ /role/i && $opts->{role}) {
        $opts->{color_by} = $opts->{role};
    }
}

sub assign_tip_colors {
    my ($tree, $opts) = @_;
    my $by = $opts->{color_by};
    return unless $by && ref $by eq 'HASH';

    my @colors = css_top_colors($opts->{ncolor});
    my %freq;
    $freq{$by->{$_}}++ for gjonewicklib::newick_tip_list($tree);
    
    my $c = 'c001';
    my %topc  = map  { $_->[0] && shift @colors ? ($_->[0] => $c++) : () }
                sort { $b->[1] <=> $a->[1] }
                map  { [ $_, $freq{$_}] } keys %freq;

    $opts->{color} ||= { map { $_ => $topc{$by->{$_}} } newick_tip_list($tree) };

    $opts->{color_legend} ||= \%topc;
}

sub fix_tip_collapse_show {
    my ($tree, $opts) = @_;
    my $show = $opts->{collapse_show};
    
    return unless defined $show && ref $show ne 'HASH';

    $opts->{collapse_show} = undef;
    
    if ($opts->{fig}) {
        if ($show =~ /woese/i) {
            my $genomes = woese_genomes();
            $opts->{collapse_show} = { map { my $gid = ($_ =~ /(\d+\.\d+)/, $1); $genomes->{$gid} ? ($_, $genomes->{$gid}) : () } keys %{$opts->{fig}} };
        }
    }
}

sub fix_tip_collapse_by {
    my ($tree, $opts) = @_;
    my $by = $opts->{collapse_by};
    return unless $by && ref $by ne 'HASH' && $opts->{name};

    my $nword = ($by =~ /g/i) ? 1 : 2; # genus or species

    my %group = map { my @w = split(/\s+/, $opts->{name}->{$_});
                      $_ => join(" ", @w[0..$nword-1]) } keys %{$opts->{name}};

    $opts->{collapse_by} = \%group;
}

sub collapse_tree_by_group {
    my ($tree, $opts) = @_;

    if ($opts->{collapse_by} && ref $opts->{collapse_by} eq 'HASH') {
        collapse_tree_by_group_decorate($tree, $opts);
        collapse_tree_by_group_mark_keepers($tree, $opts);
        collapse_tree_by_group_undecorate($tree, $opts);

        my @keep = keys %{$opts->{collapse_keep}} if $opts->{collapse_keep};
        $tree = gjonewicklib::rooted_newick_subtree($tree, @keep);
    }
    
    return $tree;
}

sub collapse_tree_by_group_mark_keepers {
    my ($node, $opts) = @_;

    my $c1 = gjonewicklib::newick_c1($node);

    my $ncons = $c1->[-1];
    my $minx  = $c1->[-2];
    my $label = $c1->[-3];

    if (gjonewicklib::newick_n_desc($node) > 0) {

        if (length($label) > 0) {

            my $subtips = gjonewicklib::newick_tip_list($node);
            my $subtree = gjonewicklib::rooted_newick_subtree($node, $subtips);
               $subtree = gjonewicklib::aesthetic_newick_tree($subtree);

            $opts->{collapse_keep}->{$label} = 1;
            $opts->{collapse_tree}->{$label} = $subtree;
            $opts->{collapse_ntip}->{$label} = $ncons;
            
        } else {

            collapse_tree_by_group_mark_keepers($_, $opts) for gjonewicklib::newick_desc_list($node);
        }

    } else {
        $label = gjonewicklib::newick_lbl($node);
        $opts->{collapse_keep}->{$label} = 1;
    }
}

#-------------------------------------------------------------------------------
#  Use node comment field c1 to recursively set intermediate information for collapsing
#-------------------------------------------------------------------------------
sub collapse_tree_by_group_decorate {
    my ($node, $opts) = @_;

    my ($label, $minx, $ncons);
    my $ndesc = gjonewicklib::newick_n_desc($node);
    if ($ndesc > 0) {
        for (my $i = 1; $i <= $ndesc; $i++) {
            my $desc = gjonewicklib::newick_desc_i($node, $i);
            collapse_tree_by_group_decorate($desc, $opts);

            my $desc_c1  = gjonewicklib::newick_c1($desc);
            my $desc_n   = $desc_c1->[-1];
            my $desc_x   = $desc_c1->[-2];
            my $desc_lbl = $desc_c1->[-3];

            if ($i == 1) {
                $label = $desc_lbl;
                $minx  = $desc_x;
                $ncons = $desc_n;
            } else {
                my $group1 = $opts->{collapse_by}->{$label};
                my $group2 = $opts->{collapse_by}->{$desc_lbl};
                my $show1  = $opts->{collapse_show}->{$label}; 
                my $show2  = $opts->{collapse_show}->{$desc_lbl};
                if (length($group1) > 0 && $group1 eq $group2) {
                    $ncons += $desc_n;
                    if (($desc_x < $minx && (!$show1 || $show2)) || (!$show1 && $show2)) { 
                        $label = $desc_lbl;
                        $minx  = $desc_x;
                    }
                } else {
                    $label = undef;
                    $minx  = undef;
                    $ncons = undef;
                }
            }
        }
        $minx += gjonewicklib::newick_x($node);
    } else {
        $label = gjonewicklib::newick_lbl($node);
        $minx  = gjonewicklib::newick_x($node);
        $ncons = 1;
    }
    my $c1 = gjonewicklib::newick_c1($node);
    my @nc = $c1 ? (@$c1, $label, $minx, $ncons) : ($label, $minx, $ncons);
    gjonewicklib::set_newick_c1($node, \@nc);
}

#-------------------------------------------------------------------------------
#  Remove intermediate information from node comment field c1
#-------------------------------------------------------------------------------
sub collapse_tree_by_group_undecorate {
    my ($node, $opts) = @_;

    my $c1 = gjonewicklib::newick_c1($node);
    if ($c1 && @$c1) {
        pop @$c1;
        pop @$c1 if @$c1;
        pop @$c1 if @$c1;
    }
    gjonewicklib::set_newick_c1($node, \@$c1);

    if (my $ndesc = gjonewicklib::newick_n_desc( $node ) ) {
        for (my $d = 1; $d <= $ndesc; $d++) {
            collapse_tree_by_group_undecorate(gjonewicklib::newick_desc_i($node, $d), $opts);
        }
    }
}

#-------------------------------------------------------------------------------
#  Guess link from tip label or alias
#-------------------------------------------------------------------------------
sub fix_tip_links {
    my ($tree, $opts) = @_;

    for (newick_tip_list($tree)) {
        my $peg  = $opts->{fig}->{$_} or next;
        my $link = peg_link($peg, $opts->{anno});
        $link ||= SeedUtils::id_url($opts->{alias}->{$_}) || SeedUtils::id_url($_);
        $opts->{link}->{$_} = $link;
    }
}

sub fix_tip_text_links {
    my ($tree, $opts) = @_;

    for my $tip (newick_tip_list($tree)) {
        my ($text, $link) = split(/\t/, $opts->{text_link}->{$tip});
        $opts->{text_link}->{$tip} = add_link($text, $link);
    }
}

sub fix_tip_popups {
    my ($tree, $opts) = @_;

    my $spc = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";

    for my $tip (newick_tip_list($tree)) {
        my ($feature, $html);
        # $feature->{'Alias'}       = [ $opts->{alias}->{$tip} ]                if $opts->{alias}->{$tip};
        $feature->{'Description'} = [ $opts->{popup}->{$tip} ]                if $opts->{popup}->{$tip};
        $feature->{'Taxonomy'}    = [ reverse @{$opts->{tax}->{$tip}}[0..5] ] if $opts->{tax}->{$tip};
        $feature->{'Function'}    = [ split(/@\s*/, $opts->{role}->{$tip})  ] if $opts->{role}->{$tip};
        
        my @lines;
        for my $k (sort keys %$feature) {
            my $v = $feature->{$k};
            push @lines, span_css($k, "bold"); 
            push @lines, "$spc<nobr>$_</nobr>" for @$v;
        }
        $opts->{popup_html}->{$tip} = join('<br/>', @lines);
    }
}

sub fix_branch_support_values {
    my ($node, $opts) = @_;

    my $ndesc;
    if ($ndesc = gjonewicklib::newick_n_desc($node)) {
        my $label = gjonewicklib::newick_lbl($node);
        if ($label =~ /[ \.0-9]*/ && $label <= 1) {
            gjonewicklib::set_newick_lbl($node, sprintf("%.0f", $label * 100));
        }
        for (my $i = 1; $i <= $ndesc; $i++) {
            my $desc = gjonewicklib::newick_desc_i($node, $i);
            fix_branch_support_values($desc, $opts);
        }
    }
}

sub html_tree_body {
    my ($tree, $opts) = @_;    

    $tree = copy_newick_tree($tree);
    $tree = gjonewicklib::reroot_newick_to_midpoint_w($tree) unless gjonewicklib::newick_is_rooted($tree);
    # $tree = gjonewicklib::reroot_newick_to_midpoint_w($tree) unless $opts->{rooted};
    $tree = gjonewicklib::rooted_newick_subtree($tree, keys %{$opts->{keep}}) if $opts->{keep};

    ($tree) = gjonewicklib::collapse_zero_length_branches($tree);

    unless ($opts->{raw}) {
        mark_duplicated_tips($tree, $opts);
        assign_tip_fig_attributes($tree, $opts);
        fix_tip_collapse_show($tree, $opts);
        $tree = collapse_identical_seqs($tree, $opts) if $opts->{collapse_by};
    }

    fix_branch_support_values($tree, $opts) if $opts->{show_branch};

    fix_tip_collapse_by($tree, $opts);
    $tree = collapse_tree_by_group($tree, $opts) || $tree;

    fix_tip_color_by($tree, $opts);
    assign_tip_colors($tree, $opts);

    fix_tip_links($tree, $opts);
    fix_tip_text_links($tree, $opts);
    fix_tip_popups($tree, $opts);

    my $relabel;
    for (gjonewicklib::newick_tip_list($tree)) { 
        my $name  = $opts->{name}->{$_} || $opts->{alias}->{$_} || $_;
        my $id    = $name;
        my $desc  = $opts->{desc}->{$_};
        my $subt  = $opts->{collapse_tree}->{$_};
        my $ident = $opts->{ident_tips}->{$_};
        my $gray  = $opts->{gray};
        my $text  = $opts->{text_link}->{$_};

        my @words = split(/\s+/, $id);
        if ($gray > 0) {
            $id   = join(" ", @words[0..$gray-1]);
            $desc = join(" ", @words[$gray..$#words]);
        }

        $id    = $id . " (duplicate)" if $opts->{dup}->{$_};
        $id    = $id . " (". $opts->{desc}->{$_} .")" if $opts->{desc}->{$_};
        $id    = add_link($id, $opts->{link}->{$_});
        $id    = span_css($id, "bold") if $opts->{focus_set}->{$_};
        $id    = span_css($id, $opts->{color}->{$_});
        $id    = span_mouseover($id, $_, $opts->{popup_html}->{$_}) if $opts->{popup_html}->{$_};
        $desc  = span_css($desc, "strain");
        $ident = span_identical_seqs($ident, $opts);
        $subt  = span_collapsed_subtree($subt, $opts);
        $text  = span_css($text, "textlink");

        my $new = join(" ", $id, $desc, $ident, $subt, $text);
        $relabel->{$_} = $new;
    }

    $tree = gjonewicklib::newick_relabel_tips($tree, $relabel);
    $tree = gjonewicklib::aesthetic_newick_tree($tree);    

    $opts->{chars}  ||= 'html_box';
    $opts->{min_dx} ||= 1;
    $opts->{dy}     ||= 1;

    join("\n", gjonewicklib::text_plot_newick($tree, $opts));
}

#-------------------------------------------------------------------------------
#  Convert a hash into CSS strings:
#
#     @lines  = css_from_hash(\%hash)
#     $lines  = css_from_hash(\%hash)
#
#-------------------------------------------------------------------------------
sub css_from_hash {
    my $hash = ref $_[0] eq 'HASH' ? $_[0] : \%_;
    
    my @lines;
    while (my ($k, $v) = each %$hash) {
        push @lines, "      $k {";
        while ($v && (my ($kk, $vv) = each %$v)) {
            my $prop = ($vv && ref $vv ne 'ARRAY') ? $vv : join(", ", map { / / ? "\"$_\"" : $_ } @$vv);
            push @lines, "        $kk: $prop;"
        }
        push @lines, "      }";
    }

    @lines = ("  <style type=\"text/css\">",
              "    <!--", @lines,
              "    -->",
              "  </style>");

    wantarray ? @lines : join("\n", @lines). "\n";
}


#-------------------------------------------------------------------------------
#  Get a list of colors:
#
#     @colors  = css_top_colors()
#     @colors  = css_top_colors($ncolor)
#
#-------------------------------------------------------------------------------
sub css_top_colors {
    my $n = $_[0] || 20;
    my @all = qw(blue green red darkcyan slateblue
                 purple #9F7A0A darkorchid royalblue darkorange
                 mediumblue #5C3317 teal #42426F #2F4F2F
                 #856363 #C9960C maroon #666C3F orchid);
    @all[0..$n-1];
}

sub span_css {
    my ($text, $class) = @_;
    return $class ? "<span class=\"$class\">$text</span>" : $text;
}

sub mouseover_javascript {
    # return gjoalign2html::mouseover_JavaScript();
    return '<script language="JavaScript" type="text/javascript" src="http://bioseed.mcs.anl.gov/~fangfang/FIG/Html/css/FIG.js"></script>';
}

sub span_mouseover {
    my ($text, $title, $html) = @_;
    $title ||= "Title bar <i>text</i> goes here";
    $html  ||= "Body text.<br />This can have any <b>HTML</b> tags you like.";
    my $tip = gjoalign2html::mouseover($title, $html, undef, undef);
    return $html ? "<span $tip>$text</span>" : $text;
}

sub span_identical_seqs {
    my ($idents, $opts) = @_;
    return unless $idents && ref $idents eq 'ARRAY' && @$idents;

    my $text  = '('.scalar@$idents. ')';
       $text  = span_css($text,  "collapse");
    my $title = "Identical sequences";
    my @names = map { "<nobr>$_</nobr>" }
                map { join(" ", $_, $opts->{name}->{$_}) } @$idents;

    return span_mouseover($text, $title, join('<br/>', @names));
}

sub span_collapsed_subtree {
    my ($tree, $opts) = @_;
    return unless $tree && ref $tree eq 'ARRAY';

    my @tips    = gjonewicklib::newick_tip_list($tree);
    my %relabel = map { $_ => join(" ", $_, $opts->{name}->{$_}) } @tips;
    my $ntip    = @tips;
       $tree    = gjonewicklib::newick_relabel_tips($tree, \%relabel);
    my @lines   = gjonewicklib::text_plot_newick($tree, { chars => "html_box", width => 1 } );
    my $treestr = join("<br/>", map { "<nobr>$_</nobr>" } @lines);
       $treestr = span_css($treestr, "mono");
    my $title   = span_css("Collapsed Taxa", "mono");

    return span_mouseover(span_css("[$ntip]", "collapse"), $title, $treestr); 
}

sub major_group {
    my ($tax) = @_;
    return undef unless $tax;

    my $group;
    return 'notax' unless $tax->[0];
    if ($tax->[0] =~ /Bacteria/i) {
        return 'actino'      if $tax->[1] =~ /Actinobacteria/i; # high G+C
        return 'firmi'       if $tax->[1] =~ /Firmicutes/i;     # low  G+C
        return 'cyano'       if $tax->[1] =~ /Cyanobacteria/i;    
        return 'spiro'       if $tax->[1] =~ /Spirochaetes/i;
        return 'chlorobi'    if $tax->[1] =~ /Chlorobi/i;
        return 'teneri'      if $tax->[1] =~ /Tenericutes/i;
        if ($tax->[1] =~ /Proteobacteria/i) {
            return 'alpha'   if $tax->[2] =~ /Alpha/i;
            return 'beta'    if $tax->[2] =~ /Beta/i;
            return 'gamma'   if $tax->[2] =~ /Gamma/i;
            return 'delta'   if $tax->[3] =~ /Delta/i;
            return 'epsilon' if $tax->[3] =~ /Epsilon/i;
        } 
    }
    return $group;
}

sub add_link {
    my ($text, $link) = @_;
    return $link ? '<a href="'.$link.'" target="_blank">'.$text.'</a>' : $text;
}

sub peg_link {
    my ($peg, $anno) = @_;

    $anno                         ? "http://anno-3.nmpdr.org/anno/FIG/seedviewer.cgi?page=Annotation&feature=$peg" :
    $ENV{SAS_SERVER} eq 'PSEED'   ? "http://pseed.theseed.org/seedviewer.cgi?pattern=$peg&page=SearchResult&action=check_search" :
    $ENV{SAS_SERVER} eq 'PUBSEED' ? "http://pubseed.theseed.org/seedviewer.cgi?pattern=$peg&page=SearchResult&action=check_search" :
                                    "http://seed-viewer.theseed.org/seedviewer.cgi?pattern=$peg&page=SearchResult&action=check_search";
}

sub add_peg_link {
    my ($text, $peg, $anno) = @_;
    my $link = $anno ? "http://anno-3.nmpdr.org/anno/FIG/seedviewer.cgi?page=Annotation&feature=$peg"
                     : "http://theseed.uchicago.edu/FIG/seedviewer.cgi?page=Annotation&feature=$peg";
    return add_link($text, $link);
}

sub woese_genomes {
    my %hash = (
                575585.3  => 'Acinetobacter calcoaceticus RUH2202',
                655812.3  => 'Aerococcus viridans ATCC 11563',
                380703.5  => 'Aeromonas hydrophila subsp. hydrophila ATCC 7966',
                234826.6  => 'Anaplasma marginale str. St. Maries',
                224308.1  => 'Bacillus subtilis subsp. subtilis str. 168',
                295405.3  => 'Bacteroides fragilis YCH46',
                264462.9  => 'Bdellovibrio bacteriovorus HD100',
                395963.13 => 'Beijerinckia indica subsp. indica ATCC 9039',
                206672.1  => 'Bifidobacterium longum NCC2705',
                224326.49 => 'Borrelia burgdorferi B31',
                262698.3  => 'Brucella abortus biovar 1 str. 9-941',
                331271.8  => 'Burkholderia cenocepacia AU 1054',
                195099.3  => 'Campylobacter jejuni RM1221',
                553178.3  => 'Capnocytophaga gingivalis ATCC 33624',
                638300.3  => 'Cardiobacterium hominis ATCC 15826',
                194439.1  => 'Chlorobium tepidum TLS',
                324602.4  => 'Chloroflexus aurantiacus J-10-fl',
                243365.4  => 'Chromobacterium violaceum ATCC 12472',
                441770.6  => 'Clostridium botulinum A str. ATCC 19397',
                227377.7  => 'Coxiella burnetii RSA 493',
                269798.16 => 'Cytophaga hutchinsonii ATCC 33406',
                243230.17 => 'Deinococcus radiodurans R1',
                207559.3  => 'Desulfovibrio desulfuricans G20',
                891.1     => 'Desulfuromonas acetoxidans',
                546274.4  => 'Eikenella corrodens ATCC 23834',
                218491.3  => 'Erwinia carotovora subsp. atroseptica SCRI1043',
                237727.3  => 'Erythrobacter sp. NAP1',
                83333.1   => 'Escherichia coli K12',
                81764.6   => 'Fervidobacterium nodosum Rt17-B1',
                106370.16 => 'Frankia sp. CcI3',
                553190.4  => 'Gardnerella vaginalis 409-05',
                546270.5  => 'Gemella haemolysans ATCC 10379',
                269799.8  => 'Geobacter metallireducens GS-15',
                321967.8  => 'Lactobacillus casei ATCC 334',
                272623.1  => 'Lactococcus lactis subsp. lactis Il1403',
                169963.1  => 'Listeria monocytogenes EGD-e',
                661410.3  => 'Methylobacterium extorquens DM4',
                83332.12  => 'Mycobacterium tuberculosis H37Rv',
                246197.24 => 'Myxococcus xanthus DK 1622',
                546263.3  => 'Neisseria elongata subsp. glycolytica ATCC 29315',
                228410.6  => 'Nitrosomonas europaea ATCC 19718',
                556268.6  => 'Oxalobacter formigenes HOxBLS',
                272843.6  => 'Pasteurella multocida subsp. multocida str. Pm70',
                563194.3  => 'Pediococcus acidilactici 7_4',
                312153.5  => 'Polynucleobacter necessarius subsp. asymbioticus QLW-P1DMWA-1',
                267747.3  => 'Propionibacterium acnes KPA171202',
                208964.1  => 'Pseudomonas aeruginosa PAO1',
                272942.6  => 'Rhodobacter capsulatus SB1003',
                414684.5  => 'Rhodospirillum centenum SW',
                272947.1  => 'Rickettsia prowazekii str. Madrid E',
                546271.3  => 'Selenomonas sputigena ATCC 35185',
                615.1     => 'Serratia marcescens Db11',
                641147.3  => 'Simonsiella muelleri ATCC 29453',
                504472.5  => 'Spirosoma linguale DSM 74',
                93062.4   => 'Staphylococcus aureus subsp. aureus COL ',
                378806.7  => 'Stigmatella aurantiaca DW4/3-1',
                596322.3  => 'Streptococcus salivarius SK126',
                100226.1  => 'Streptomyces coelicolor A3(2)',
                335541.4  => 'Syntrophomonas wolfei subsp. wolfei str. Goettingen',
                309801.4  => 'Thermomicrobium roseum DSM 5159',
                243274.1  => 'Thermotoga maritima MSB8',
                262724.1  => 'Thermus thermophilus HB27',
                243276.5  => 'Treponema pallidum subsp. pallidum str. Nichols',
                223926.6  => 'Vibrio parahaemolyticus RIMD 2210633',
                955.1     => 'Wolbachia pipientis quinquefasciatus',
                273121.1  => 'Wolinella succinogenes DSM 1740',
                160492.11 => 'Xylella fastidiosa 9a5c',
                630.2     => 'Yersinia enterocolitica 8081',
                264203.5  => 'Zymomonas mobilis subsp. mobilis ZM4'
               );
    wantarray() ? keys %hash : \%hash;
} 

#-------------------------------------------------------------------------------
#  CSS snippets
#-------------------------------------------------------------------------------

sub css_snippet_main {
    { pre => { 'font-size'   => '12px',
               'font-family' => [ 'Menlo', 'DejaVu Sans Mono', 'Andale Mono', 'Courier New', 'monospace' ] },

      a   => { font               => 'inherit',
               color              => 'inherit',
               'background-color' => 'inherit',
               'text-decoration'  => 'inherit' },

     'a:hover' => { 'text-decoration' => 'underline' },

     'table'   => { 'font-size'   => '12px',
                    'font-family' => ['Arial', 'sans-serif'] } }
}

sub css_snippet_top_colors {
    my $c = 'c001';
    my %hash = map { ".".$c++ => { color => $_ } } css_top_colors();

    return \%hash;
}

sub css_snippet_taxonomy {
    { '.archaea'   => { 'background-color' => 'mistyrose' } ,
      '.eukaryota' => { 'background-color' => 'palegreen' } ,
      '.bacteria'  => { } ,
      '.notax'     => { 'color' => 'gray' } ,
      '.actino'    => { 'color' => 'red' } ,
      '.firmi'     => { 'color' => 'blue' } ,
      '.teneri'    => { 'color' => 'darkorange' } ,
      '.cyano'     => { 'color' => 'green' } ,
      '.alpha'     => { 'color' => 'darkorchid' } ,
      '.beta'      => { 'color' => 'purple' } ,
      '.gamma'     => { 'color' => 'slateblue' } ,
      '.delta'     => { 'color' => 'mediumblue' } ,
      '.epsilon'   => { 'color' => 'royalblue' } ,
      '.spiro'     => { 'color' => '#9F7A0A' } ,
      '.chlorobi'  => { 'color' => 'darkcyan' } }
}

sub css_snippet_auxilary {
    { '.strain'   => { 'color'       => 'lightgrey' },
      '.bold'     => { 'font-weight' => 'bold' },
      '.mono'     => { 'font-size'   => '12px',
                       'font-family' => [ 'Menlo', 'DejaVu Sans Mono', 'Andale Mono', 'Courier New', 'monospace' ] },
      '.collapse' => { 'color'       => 'lightgrey',
                       'font-weight' => 'bold' },
      '.textlink' => { 'background-color' => 'lightgrey',
                       'color'            => 'navy'} }
}


#===============================================================================
#  Tree manipulation - property hash for inner nodes
#===============================================================================

sub set_node_property {
    my ($node, $key, $val) = @_;
    verify_node_properties($node);
    my $c1 = gjonewicklib::newick_c1($node);
    $c1->[-1]->{$key} = $val;
}

sub get_node_property {
    my ($node, $key) = @_;
    my $c1  = gjonewicklib::newick_c1($node);
    my $val = $c1->[-1]->{$key} if $c1 && @$c1 && ref $c1->[-1] eq 'HASH';
    return $val;
}

sub remove_node_properties {
    my ($node) = @_;
    my $c1 = gjonewicklib::newick_c1($node);
    pop @$c1 if $c1 && @$c1 && ref $c1->[-1] eq 'HASH';
}

sub verify_node_properties {
    my ($node) = @_;
    my $c1 = gjonewicklib::newick_c1($node);
    return if $c1 && @$c1 && ref $c1->[-1] eq 'HASH'; # ref $c1 should be 'ARRAY' 
    my $prop = {};
    my @new = $c1 ? (@$c1, $prop) : ($prop);
    gjonewicklib::set_newick_c1($node, \@new);
}

sub add_node_properties_to_tree {
    my ($node) = @_;
    verify_node_properties($node);
    add_node_properties_to_tree($_) foreach (newick_desc_list($node));
}

sub remove_node_properties_from_tree {
    my ($node) = @_;
    remove_node_properties($node);
    remove_node_properties_from_tree($_) foreach (newick_desc_list($node));
}

#===============================================================================
#  Read a newick tree from a string
# 
#  $tree = parse_newick_tree_str( $string )
#
#  Taken from gjonewicklib::parse_newick_tree_str(), with one minor differnce:
#
#    Do not change tip labels. Skip the following two lines.
#
#        # $lbl =~ s/''/'/g;
#        # $lbl =~ s/_/ /g;
#
#===============================================================================
sub parse_newick_tree_str
{
    my $s = shift @_;

    my ( $ind, $rootnode ) = parse_newick_subtree( $s, 0 );
    if ( substr( $s, $ind, 1 ) ne ";") { warn "warning: tree missing ';'\n" }
    $rootnode;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Read a subtrees recursively (everything of tree but a semicolon)
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub parse_newick_subtree
{
    my ( $s, $ind ) = @_;

    my $newnode = [];
    my @dlist   = ();
    my ( $lbl, $x, $c1, $c2, $c3, $c4, $c5 );

    ( $ind, $c1 ) = gjonewicklib::getNextTreeChar( $s, $ind );       #  Comment 1
    if ( ! defined( $ind ) ) { gjonewicklib::treeParseError( "missing subtree" ) }
    if ( $c1 && @$c1 ) { gjonewicklib::set_newick_c1( $newnode, $c1 ) }

    if ( substr( $s, $ind, 1 ) eq "(" ) {                #  New internal node
        while ( ! @dlist || ( substr( $s, $ind, 1 ) eq "," ) ) {
            my $desc;
            ( $ind, $desc ) = parse_newick_subtree( $s, $ind+1 );
            if (! $ind) { return () }
            push @dlist, $desc;
        }
        if ( substr( $s, $ind, 1 ) ne ")" ) { gjonewicklib::treeParseError( "missing ')'" ) }

        ( $ind, $c2 ) = gjonewicklib::getNextTreeChar( $s, $ind+1 );   #  Comment 2
        if ( $c2 && @$c2 ) { gjonewicklib::set_newick_c2( $newnode, $c2 ) }
        ( $ind, $lbl ) = parseTreeNodeLabel( $s, $ind ); #  Node label
    }

    elsif ( substr( $s, $ind, 1 ) =~ /[^][(,):;]/ ) {    #  New tip
        ( $ind, $lbl ) = parseTreeNodeLabel( $s, $ind ); #  Tip label
        if (! $ind) { return () }
    }

    @dlist || $lbl || gjonewicklib::treeParseError( "no descendant list or label" );

    if ( @dlist ) { gjonewicklib::set_newick_desc_ref( $newnode, \@dlist ) }
    if ( $lbl   ) { gjonewicklib::set_newick_lbl( $newnode, $lbl ) }

    ( $ind, $c3 ) = gjonewicklib::getNextTreeChar( $s, $ind );         #  Comment 3
    if ( $c3 && @$c3 ) { gjonewicklib::set_newick_c3( $newnode, $c3 ) }

    if (substr( $s, $ind, 1 ) eq ":") {                  #  Branch length
        ( $ind, $c4 ) = gjonewicklib::getNextTreeChar( $s, $ind+1 );   #  Comment 4
        if ( $c4 && @$c4 ) { gjonewicklib::set_newick_c4( $newnode, $c4 ) }
        ( $ind, $x ) = gjonewicklib::parseBranchLength( $s, $ind );
        if ( defined( $x ) ) { gjonewicklib::set_newick_x( $newnode, $x ) }
        ( $ind, $c5 ) = gjonewicklib::getNextTreeChar( $s, $ind );     #  Comment 5
        if ( $c5 && @$c5 ) { gjonewicklib::set_newick_c5( $newnode, $c5 ) }
    }

    ( $ind, $newnode );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Read a Newick tree label
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub parseTreeNodeLabel
{  #  Empty string is permitted
    my ( $s, $ind ) = @_;
    my ( $lbl, $c );

    if ( substr( $s, $ind, 1 ) eq "'") {
        my $ind1 = ++$ind;

        while ( ) {
            if ( ! defined( $c = substr( $s, $ind, 1 ) ) || $c eq "" ) {
                treeParseError( "missing close quote on label '" . substr( $s, $ind1 ) . "'" )
            }
            elsif ( $c ne "'"  )                  { $ind++ }
            elsif ( substr( $s, $ind, 2 ) eq "''" ) { $ind += 2 }
            else                                    { last }
        }

        $lbl = substr( $s, $ind1, $ind-$ind1 );
        # $lbl =~ s/''/'/g;
        $ind++;
    }

    else {
        my $ind1 = $ind;
        while ( defined( $c = substr($s, $ind, 1) ) && $c ne "" && $c !~ /[][\s(,):;]/ ) { $ind++ }
        $lbl = substr( $s, $ind1, $ind-$ind1 );
        # $lbl =~ s/_/ /g;
    }

    ( $ind, $lbl );
}


#-------------------------------------------------------------------------------
#  Tree tip routines: abandoned in favor or hashes: $opts->{key}{@tips} 
#-------------------------------------------------------------------------------

sub set_tree_tip_property {
    my ($opts, $tip, $key, $val) = @_;

    $opts->{tipH}->{$tip}->{$key} = $val;
}

sub tree_tip_property {
    my ($opts, $tip, $key) = @_;

    $opts->{tipH}->{$tip}->{$key};
}

sub assign_unique_labels_for_tips {
    my ($tree, $opts) = @_;

    $opts->{label_}   = "tip000000";
    assign_unique_labels_for_tips_helper($tree, $opts);
    delete $opts->{label_};
}

sub assign_unique_labels_for_tips_helper {
    my ($node, $opts) = @_;
    
    my @desc = gjonewicklib::newick_desc_list($node);
    
    if (@desc) {
        assign_unique_labels_for_tips_helper($_, $opts) for @desc;
    } else {
        my $tip = $opts->{label_}++; # local label for tip
        set_tree_tip_property($opts, $tip, 'id', gjonewicklib::newick_lbl($node));
        gjonewicklib::set_newick_lbl($node, $tip);
    }
}


#-------------------------------------------------------------------------------
#
#  Codes to be organized
#
#-------------------------------------------------------------------------------

sub tree_with_program {
    my ($align, $opts) = @_;
    my ($tree, $stats);

    if ($opts->{program} =~ /raxml/i) {
        ($tree, $stats) = tree_with_raxml($align, $opts);
    } elsif ($opts->{program} =~ /phyml/i) {
        ($tree, $stats) = tree_with_phyml($align, $opts);
    } else {
        ($tree, $stats) = tree_with_fasttree($align, $opts);
    }

    wantarray() ? ($tree, $stats) : $tree;
}

sub eval_tree_with_program {
    my ($align, $treeF, $opts) = @_;
    
    my $defs = { program  => 'fasttree',
                 optimize => 'eval',
                 model    => 'JTT',
                 rate     => 'Gamma',
                 input    => $treeF,
                 # nclasses => 4,
                 treefile => "/tmp/eval_tree.$$.tree"
               };

    @$defs{ keys %$opts } = values %$opts if $opts;
    
    my ($tree, $stats) = tree_with_program($align, $defs);

    wantarray() ? ($stats->{logLk}, $tree) : $stats->{logLk};
}


sub index_html_css {
    return <<End_of_CSS;
    <style type="text/css">
    <!--
      table {
        font-size: 13px;
        font-family: sans-serif;
      }
      a:link {
        color:blue;
        text-decoration:none;
      }
      a:hover {
        color:navy;
        text-decoration:none;
      }
      a:visited {
        text-decoration:none;
      }
      .role {
        width: 250px;
      }
      .seqs {
        white-space:nowrap;
        width: 150px;
      }
      .nseqs {
        float: left;
        text-align: right;
        width: 30%;
      }
      .nfps { 
        float: left;
        text-align: right;
        width: 37%;
      }
      .nfns {
        float: left;
        text-align: right;
        width: 33%;
      }
      .stdev {
        color: black;
      }
    -->
    </style>
End_of_CSS
}

sub complete_html {
    my ($html, $title) = @_;
    $title = "Alignment and Trees" unless $title;
    return ("<html>", "<head>",
            '<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />',
            "<title>$title</title>",
            "</head>", '<body>', index_html_css(),
            @$html, "</body>", "</html>");
}

sub export_eval {
    my $html_dir   = $ENV{HOME}. "/public_html";
    my $export_dir = "$html_dir/eval";
    my $fhtml      = "$export_dir/index.html";
    my $fexp       = "$export_dir/experiments";

    my @progs = ("fasttree", "phyml");
    my @ndels = (1,2,4,8,16,32);

    my @html;
    push @html, "<table border=1>";
    push @html, "  <tr>";
    push @html, "    <th>$_</th>" for ("&nbsp;", "Role", "#Seqs", "Length", "LogLk");
    push @html, "    <th colspan=\"12\">$_</th>" for ("FastTree", "PhyML");
    push @html, "  </tr>";

    push @html, "  <tr>";
    push @html, "    <th colspan=\"5\">&nbsp;</th>";
    for (@progs) {
        push @html, "    <th colspan=\"2\" align=\"center\">$_</th>" for @ndels;
    }
    push @html, "  </tr>";

    my @lines = `cat $fexp`;
    for (@lines) {
        chomp;
        my ($i, $role, $rdir, $subi) = split /\t/;
        my $align = gjoseqlib::read_fasta("$export_dir/aligns/$role.fa");
        my $len   = length $align->[0]->[2];
        my $nseqs = @$align;
        my $fd0   = "$export_dir/$role.fasttree.AT/$role.delta";
        my $lk0   = sprintf "%.3f", [split(/[\t\n]/, `head -n2 $fd0 | tail -n1`)]->[1];

        push @html, "  <tr>";
        push @html, "  <td>$_</td>" for ($i, $role, $nseqs, $len, $lk0);
        
        for my $prog ("fasttree", "phyml") {
            for my $ndel (@ndels) {
                my $nd = $ndel > 1 ? "N$ndel." : "";
                my $dir = "$export_dir/$role.$nd$prog.AT";
                my $fdelta = "$dir/$role.$nd"."delta";
                my $floglk = "$dir/$role.$nd"."logLk.txt";
                
                my $link1 = "http://bioseed.mcs.anl.gov/~fangfang/eval/$role.$nd$prog.AT";
                my $link2 = "$link1/$role.$nd" . "delta";

                my $dmean = '-';
                $dmean = sprintf "%+.3f", [split(/\t/, `grep mean $fdelta`)]->[1] if -e $fdelta;
                $dmean = add_link($dmean, $link2) if -e $fdelta;

                my $stdev;
                $stdev = sprintf "%.2f", [split(/\t/, `grep stdev $fdelta`)]->[1] if -e $fdelta;
                my $margin = '-';
                $margin = sprintf "&plusmn;%.2f", 2 * $stdev if $stdev;
                $margin = span_css($margin, "stdev");
                $margin = add_link($margin, $link1) if -e $fdelta;
                push @html, "  <td align=\"right\" style=\"white-space:nowrap\">$dmean</td><td style=\"white-space:nowrap\">$margin</td>";
            }
        }
        push @html, "  </tr>";
    }

    push @html, "</table>";
    open(HTML, ">", $fhtml) or die "Could not open $fhtml";
    print HTML join("\n", complete_html(\@html)) . "\n";
    close(HTML);
}


sub eval_add_to_alignment {
    my ($alignF, $opts) = @_;

    my $ndels   = $opts->{ndels}   || 1;
    my $nruns   = $opts->{nruns}   || 10;
    my $dir     = $opts->{dir}     || ".";
    my $prog    = $opts->{program} || "fasttree";
    my $realign = $opts->{realign};
    

    my $name  = $alignF;
    $name =~ s/\.(fa|mafft)$//i; $name =~ s/.*\///;
    $name .= ".N$ndels" if $ndels > 1;

    my $atdir = "$dir/$name.$prog.AT";
    -d $atdir || mkdir("$atdir", 0755) or die "Could not mkdir '$atdir'";
    run("cp $alignF $atdir/");

    my $align = gjoseqlib::read_fasta($alignF);
    my $nseqs = @$align; $nruns = $nseqs if $nseqs < $nruns;

    if ($realign) {
        my @seqs = @$align;
        for (@seqs) {
            $_->[2] =~ s/\-//g;
        }
        $align = align_with_mafft(\@seqs, { alg => "linsi" });
        gjoseqlib::print_alignment_as_fasta("$atdir/$name.mafft", $align);
    }

    my $tree;
    my $treeF = "$atdir/$name.tree";
    
    if (defined $opts->{tree}) {
        if (ref($opts->{tree}) eq 'ARRAY') {
            $tree = $opts->{tree};
        } else {
            $tree = gjonewicklib::read_newick_tree($opts->{tree});
        }
        gjonewicklib::writeNewickTree($tree, $treeF);
    } else {
        my $moreopts = { treefile => $treeF,
                         optimize => 'all',
                         search   => 'SPR' };
        my %tmp = %$moreopts;
        @tmp { keys %$opts } = values %$opts if $opts;
        $tree = tree_with_fasttree($align, \%tmp);
    }
    my $lk = eval_tree_with_program($align, $treeF, $opts);

    open(ID, ">$atdir/$name.ids") or die "Could not open $atdir/$name.ids";
    open(LOGLK, ">$atdir/$name.logLk.txt") or die "Could not open $atdir/$name.logLk.txt";    
    open(DELTA, ">$atdir/$name.delta") or die "Could not open $atdir/$name.delta";

    print LOGLK join("\t", "nSeqs", "old A old T") . "\n";
    print LOGLK join("\t", $nseqs, $lk). "\n\n";
    print LOGLK join("\t", " ", "new A new T", "new A old T", "old A new T") . "\n";

    print DELTA join("\t", "nSeqs", "old A old T") . "\n";
    print DELTA join("\t", $nseqs, $lk). "\n\n";
    print DELTA join("\t", " ", "new A new T", "new A old T", "old A new T") . "\n";
    
    my (%done, @rems, @dels, $ko, $id);
    my (@deltas, @deltas_nAoT, @deltas_oAnT);
    for my $i (1 .. $nruns) {
        my %seen = {};

        if ($ndels == 1) {
            do { $ko = int(rand($nseqs)) } while ($done{$ko}++);
            $seen{$ko}++;
        } else {                # multiple deletions
            for (1..$ndels) {
                do { $ko = int(rand($nseqs)) } while ($seen{$ko}++);
            }
        }
        
        @dels = map  { my @seq = @{$align->[$_]}; $seq[2] =~ s/-//g; [@seq]; }
            grep { $seen{$_} } keys %seen;

        @rems = map  { $align->[$_] }
            grep { !$seen{$_} } (0 .. $nseqs-1);

        my $new_align = \@rems;
        foreach my $seq (@dels) {
            $new_align = gjoalignment::add_to_alignment_v2($seq, $new_align, { trim => 0, silent => 1 });  
        }
        gjoseqlib::print_alignment_as_fasta("$atdir/$name.$i.fa", $new_align);

        print ID join("\t", $i, map { $_->[0] } @dels). "\n";
        
        my $new_treeF = "$atdir/$name.$i.tree";
        my $new_opts  = { %$opts }; $new_opts->{treefile} = $new_treeF;

        my ($new_tree, $new_stats) = tree_with_fasttree($new_align, $new_opts);

        $new_opts->{treefile} = "$atdir/$name.$i.$prog.tree";
        my $new_lk = eval_tree_with_program($new_align, $new_treeF, $new_opts);

        $new_opts->{treefile} = "$atdir/$name.$i.$prog.nAoT.tree";
        my $lk_nAoT = eval_tree_with_program($new_align, $treeF, $new_opts);
        
        $new_opts->{treefile} = "$atdir/$name.$i.$prog.oAnT.tree";
        my $lk_oAnT = eval_tree_with_program($align, $new_treeF, $new_opts);

        my $delta      = sprintf "%+9.3f", $new_lk  - $lk;
        my $delta_nAoT = sprintf "%+9.3f", $lk_nAoT - $lk;
        my $delta_oAnT = sprintf "%+9.3f", $lk_oAnT - $lk;

        print LOGLK join("\t", $i, $new_lk, $lk_nAoT, $lk_oAnT) . "\n";

        print DELTA join("\t", $i, $delta, $delta_nAoT, $delta_oAnT) . "\n";

        push @deltas, $delta;
        push @deltas_nAoT, $delta_nAoT;
        push @deltas_oAnT, $delta_oAnT;
        # last if $i >= 2;
    }

    print DELTA "\n";
    print DELTA join("\t", "mean", mean(@deltas), mean(@deltas_nAoT), mean(@deltas_oAnT)) . "\n";
    print DELTA join("\t", "stdev", stdev(@deltas), stdev(@deltas_nAoT), stdev(@deltas_oAnT)) . "\n";

    close(DELTA);
    close(LOGLK);
    close(ID);

}


sub eval_add_to_alignment_full {
    my ($alignF, $opts) = @_;

    my $ndels = $opts->{ndels}   || 1;
    my $nruns = $opts->{nruns}   || 10;
    my $dir   = $opts->{dir}     || ".";
    my $prog  = $opts->{program} || "fasttree";

    my $name  = $alignF;
    $name =~ s/\.fa$//i; $name =~ s/.*\///;
    $name .= ".N$ndels" if $ndels > 1;
    $name .= ".full";

    my $atdir = "$dir/$name.$prog.AT";
    -d $atdir || mkdir("$atdir", 0755) or die "Could not mkdir '$atdir'";
    run("cp $alignF $atdir/");

    my $align = gjoseqlib::read_fasta($alignF);
    my $nseqs = @$align; $nruns = $nseqs if $nseqs < $nruns;

    my $tree;
    my $treeF = "$atdir/$name.tree";
    
    if (defined $opts->{tree}) {
        if (ref($opts->{tree}) eq 'ARRAY') {
            $tree = $opts->{tree};
        } else {
            $tree = gjonewicklib::read_newick_tree($opts->{tree});
        }
        gjonewicklib::writeNewickTree($tree, $treeF);
    } else {
        my $moreopts = { treefile => $treeF,
                         optimize => 'all',
                         search   => 'SPR' };
        my %tmp = %$moreopts;
        @tmp { keys %$opts } = values %$opts if $opts;
        $tree = tree_with_fasttree($align, \%tmp);
    }
    my $lk = eval_tree_with_program($align, $treeF, $opts);

    my @treeFs = ($treeF);
    my @aligns = ($align);

    open(ID, ">$atdir/$name.ids") or die "Could not open $atdir/$name.ids";
    open(LOGLK, ">$atdir/$name.logLk.txt") or die "Could not open $atdir/$name.logLk.txt";    
    open(DELTA, ">$atdir/$name.delta") or die "Could not open $atdir/$name.delta";

    my (%done, @rems, @dels, $ko, $id);
    my (@deltas, @deltas_nAoT, @deltas_oAnT);
    for my $i (1 .. $nruns) {
        my %seen = {};

        if ($ndels == 1) {
            do { $ko = int(rand($nseqs)) } while ($done{$ko}++);
            $seen{$ko}++;
        } else {                # multiple deletions
            for (1..$ndels) {
                do { $ko = int(rand($nseqs)) } while ($seen{$ko}++);
            }
        }
        
        @dels = map  { my @seq = @{$align->[$_]}; $seq[2] =~ s/-//g; [@seq]; }
            grep { $seen{$_} } keys %seen;

        @rems = map  { $align->[$_] }
            grep { !$seen{$_} } (0 .. $nseqs-1);

        print ID join("\t", $i, map { $_->[0] } @dels). "\n";

        my $new_align = \@rems;
        foreach my $seq (@dels) {
            $new_align = gjoalignment::add_to_alignment_v2($seq, $new_align, { trim => 0, silent => 1 });  
        }
        gjoseqlib::print_alignment_as_fasta("$atdir/$name.$i.fa", $new_align);

        my $new_treeF = "$atdir/$name.$i.tree";
        my $new_opts  = { %$opts }; $new_opts->{treefile} = $new_treeF;
        my $new_tree  = tree_with_fasttree($new_align, $new_opts);
        
        $aligns[$i] = $new_align;
        $treeFs[$i] = $new_treeF;
    }

    my (%logLkH, %deltaH);

    print LOGLK join("\t", 'A\T', map { sprintf "     %d   ", $_ } 0..$nruns) . "\n";
    print DELTA join("\t", 'A\T', map { sprintf "     %d   ", $_ } 0..$nruns) . "\n";
        
    for my $i (0 .. $nruns) {
        print LOGLK "$i\t";
        print DELTA "$i\t";
        for my $j (0 .. $nruns) {
            my $new_treeF = "$atdir/$name.$i.$j.tree";
            my $new_opts  = { %$opts }; $new_opts->{treefile} = $new_treeF;
            my $new_lk    = eval_tree_with_program($aligns[$i], $treeFs[$j], $new_opts);
            my $delta     = sprintf "%+.5f", $new_lk  - $lk;
            print LOGLK "$new_lk\t";
            print DELTA "$delta\t";
        }
        print LOGLK "\n";
        print DELTA "\n";
    }

    close(DELTA);
    close(LOGLK);
    close(ID);
}

sub mean {
    my $s;
    $s += $_ for @_;
    sprintf "%+8f", $s / @_;
}

sub stdev {
    my $m = mean(@_);
    my $s;
    $s += ($_ - $m) * ($_ - $m) for @_;
    sprintf "%9f", sqrt $s / @_; 
}

#===============================================================================
#  Align sequences with muscle and return the alignment, or alignment and tree.
#
#     \@align                           = align_with_mafft( \@seqs )
#     \@align                           = align_with_mafft( \@seqs, \%opts )
#     \@align                           = align_with_mafft( \%opts )
#   ( \@align, $newick-tree-as-string ) = align_with_mafft( \@seqs )
#   ( \@align, $newick-tree-as-string ) = align_with_mafft( \@seqs, \%opts )
#   ( \@align, $newick-tree-as-string ) = align_with_mafft( \%opts )
#
#  If input sequences are not supplied, they must be included as an in or in1
#  option value.
#
#  Options:
#
#     add       =>  $seq      #  Add one sequence to \@ali1 alignment
#     algorithm =>  linsi, einsi, ginsi, nwnsi, nwns, fftnsi, fftns (d)
#                             #  Algorithms in descending order or accuracy
#     in        => \@seqs     #  Input sequences; same as in1, or \@seqs
#     in1       => \@ali1     #  Input sequences; same as in, or \@seqs
#     in2       => \@ali2     #  Align \@seqs with \@ali2; same as profile, or seed
#     profile   => \@ali2     #  Align \@seqs with \@ali2; same as in2, or seed
#     seed      => \@ali2     #  Align \@seqs with \@ali2; same as in2, or profile
#     version   =>  $bool     #  Return the program version number, or undef
#
#  Many of the program flags can be used as keys (without the leading --).
#===============================================================================
sub align_with_mafft
{
    my( $seqs, $opts );
    if ( $_[0] && ref( $_[0] ) eq 'HASH' ) {
        $opts = shift;
    } else {
        ( $seqs, $opts ) = @_;
    }

    $opts = {} if ! $opts || ( ref( $opts ) ne 'HASH' );

    my $add      = $opts->{ add }      || undef;
    my $profile  = $opts->{ profile }  || $opts->{ in2 } || $opts->{ seed } || undef;
    $seqs   ||= $opts->{ seqs }     || $opts->{ in }  || $opts->{ in1 };
    my $version  = $opts->{ version }  || 0;

    my $mafft = SeedAware::executable_for( $opts->{ mafft } || $opts->{ program } || 'mafft' );
    
    if ( $version ) {
        return undef if ! open( MAFFT, "$mafft --help |" );
        my @info = <MAFFT>;
        close( MAFFT );
        $version = $info[2];    # second line of MAFFT usage info
        return $version;
    }

    my %prog_val  = map { $_ => 1 }
        qw( aamatrix
            bl
            ep
            groupsize
            jtt
            lap
            lep
            lepx
            LOP
            LEXP
            maxiterate
            op
            partsize
            retree
            tm
            weighti
         );

    my %prog_flag = map { $_ => 1 }
        qw( 6merpair
            amino
            auto
            clustalout
            dpparttree
            fastapair
            fastaparttree
            fft
            fmodel
            genafpair
            globalpair
            inputorder
            localpair
            memsave
            nofft
            noscore
            nuc
            parttree
            quiet
            reorder
            treeout
         );

    my $degap = ! ( $add || $profile );
    my $tree  = ! ( $add || $profile );

    my $tmpdir = SeedAware::location_of_tmp( $opts );
    my $tmpin  = SeedAware::new_file_name( "$tmpdir/seqs",  'fasta' );
    my $tmpin2 = SeedAware::new_file_name( "$tmpdir/seqs2", 'fasta' );
    my $tmpout = SeedAware::new_file_name( "$tmpdir/ali",   'fasta' );

    if ( ! ( $seqs && ref($seqs) eq 'ARRAY' && @$seqs && ref($seqs->[0]) eq 'ARRAY' ) ) {
        print STDERR "gjoalignment::align_with_mafft() called without sequences\n";
        return undef;
    }

    my ( $id, $seq, %comment );
    my @clnseq = map { ( $id, $seq ) = @$_[0,2];
                       $comment{ $id } = $_->[1] || '';
                       $seq =~ tr/A-Za-z//cd if $degap; # degap
                       [ $id, '', $seq ]
                   }
        @$seqs;
    gjoseqlib::print_alignment_as_fasta( $tmpin, \@clnseq );

    #  Adding one sequence is a special case of profile alignment

    if ( $add ) {
        $profile = [ $add ]; $degap = 1;
    }

    if ( $profile ) {
        if ( ! ( ref($profile) eq 'ARRAY' && @$profile && ref($profile->[0]) eq 'ARRAY' ) ) {
            print STDERR "gjoalignment::align_with_mafft() requested to do profile alignment without sequences\n";
            return undef;
        }

        my @clnseq2 = map { ( $id, $seq ) = @$_[0,2];
                            $comment{ $id } = $_->[1] || '';
                            $seq =~ tr/A-Za-z//cd if $degap; # degap
                            [ $id, '', $seq ]
                        }
            @$profile;

        gjoseqlib::print_alignment_as_fasta( $tmpin2, \@clnseq );
    }

    my @params = $profile ? ( '--seed', $tmpin, '--seed', $tmpin2, '/dev/null')
                          : ( '--treeout',                         $tmpin,    );

    my $algorithm = lc( $opts->{ algorithm } || $opts->{ alg } );
    if ( $algorithm ) {
        delete $opts->{ $_ } for qw( localpair genafpair globalpair nofft fft retree maxiterate );

        if ( $algorithm eq 'linsi' || $algorithm eq 'l' ) {
            $opts->{ localpair }  = 1; $opts->{ maxiterate } = 1000;
        } elsif ( $algorithm eq 'einsi' || $algorithm eq 'e' ) {
            $opts->{ genafpair }  = 1; $opts->{ maxiterate } = 1000;
        } elsif ( $algorithm eq 'ginsi' || $algorithm eq 'g' ) {
            $opts->{ globalpair } = 1; $opts->{ maxiterate } = 1000;
        } elsif ( $algorithm eq 'nwnsi'  ) {
            $opts->{ retree }     = 2; $opts->{ maxiterate } = 2;   $opts->{ nofft } = 1;
        } elsif ( $algorithm eq 'nwns'   ) {
            $opts->{ retree }     = 2; $opts->{ maxiterate } = 0;   $opts->{ nofft } = 1;
        } elsif ( $algorithm eq 'fftnsi' ) {
            $opts->{ retree }     = 2; $opts->{ maxiterate } = 2;   $opts->{ fft }   = 1;
        } elsif ( $algorithm eq 'fftns'  ) {
            $opts->{ retree }     = 2; $opts->{ maxiterate } = 0;   $opts->{ fft }   = 1;
        }
    }

    foreach ( keys %$opts ) {
        @params = ("--$_", @params)               if $prog_flag{ $_ };
        @params = ("--$_", $opts->{$_}, @params)  if $prog_val{ $_ };
    }

    my $redirects = { stdout => $tmpout, stderr => '/dev/null' };
    SeedAware::system_with_redirect( $mafft, @params, $redirects );
    
    my @ali = &gjoseqlib::read_fasta( $tmpout );
    foreach $_ ( @ali ) { $_->[1] = $comment{$_->[0]} }

    my $treestr;
    my $treeF  = "input.tree";  # mafft uses a hardcoded guide tree
    if ( $tree && open( TREE, "<$treeF" ) ) {
        $treestr = join( "", <TREE> ); close( TREE );
    }
    if ( $opts->{ treeout } ) {
        SeedAware::system_with_redirect( "cp", $treeF, $opts->{ treeout } );
    }

    unlink( $tmpin, $tmpout,
            ( $profile ? $tmpin2 : () ),
            ( $tree    ? $treeF  : () )
          );

    return wantarray ? ( \@ali, $treestr ) : \@ali;
}

sub guess_alignment_format {
    my ($align) = @_;
    my $format;
    open ALN, $align or die "Could not open $align";
    while (<ALN>) {
        chomp;
        next unless $_;
        if (/^>/) {
            $format = "fasta"; 
        } elsif (/\d+\s+\d+/) {
            $format = "phylip"; 
        } else {
            $format = "unrecognized";
        }
        last;
    }
    return $format;
}

sub guess_type {
    local $_ = shift;
    return undef unless $_;
    tr/A-Za-z//cd;              #  only letters
    (tr/ACGTUacgtu// > (0.5 * length)) ? 'n' : 'p';
}


sub gd_plot_tree {
    my ($tree, $file, $opts) = @_;

    $file .= ".png" unless $file =~ /\.png$/;
    unlink $file if -s $file;
    gd_tree::newick_gd_png($tree, { bkg_color => [255,255,255], file => $file });
}

sub html_tree_css_old {
    return <<End_of_CSS;
  <style type="text/css">
    <!--
      pre {
        font-size: 12px;
        font-family: Menlo, "DejaVu Sans Mono", "Andale Mono", "Courier New", monospace;
      }
      table {
        font-size: 12px;
        font-family: sans-serif;
      }
      .mono {
        font-size: 12px;
        font-family: Menlo, "DejaVu Sans Mono", "Andale Mono", "Courier New", monospace;
      }
      .strain {
        color: lightgrey;
      }
      .consolidated {
        color: lightgrey;
        font-weight: bold;
      }
      .archaea {
        background-color: mistyrose;
      }
      .eukaryota {
        background-color: palegreen;
      }
      .bacteria {
      }
      .notax {
        color: gray;
      }
      .actino {
        color: red;
      }
      .firmi {
        color: blue;
      }
      .teneri {
        color: darkorange;
      }
      .cyano {
        color: green;
      }
      .alpha {
        color: darkorchid;
      }
      .beta {
        color: purple;
      }
      .gamma {
        color: slateblue;
      }
      .delta {
        color: mediumblue;
      }
      .epsilon {
        color: royalblue;
      }
      .spiro {
        color: #9F7A0A;
      }
      .chlorobi {
        color: darkcyan;
      }
      a {
        color: inherit;
        background-color: inherit;
        font: inherit;
        text-decoration: inherit;
      }
      a:hover {
        text-decoration: underline;
      }      
    -->
  </style>
End_of_CSS
}


# options: title...
sub plot_newick_with_js {
    my ($tree, $file, $opts) = @_;
    my $title = $opts->{title} || "Tree";

    my $css    = html_tree_css();
    my $legend = html_tree_legend($tree, $opts);
    my $js     = mouseover_javascript();
    my @lines  = gjonewicklib::text_plot_newick($tree, $opts);
    my $body   = join("\n", @lines);

    open(HTML, ">",$file) or die "Could not open $file";
    print HTML <<"End_of_Page";
<html>
<head>
<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />
<title>$title</title>
$css
</head>
<body>
$js
<pre>
$body
$legend
</pre>
</body>
</html>
End_of_Page
}



sub shorten_branch_confidence_str {
    my ($node) = @_;
    my $ndesc;
    if ($ndesc = gjonewicklib::newick_n_desc($node)) {
        my $label = gjonewicklib::newick_lbl($node);
        # print "label = $label";
        $label =~ s/([01]\.[0-9]{2})[0-9]+/$1/; 
        # print "   new   = $label\n";
        gjonewicklib::set_newick_lbl($node, $label);
        for (my $i = 1; $i <= $ndesc; $i++) {
            my $desc  = gjonewicklib::newick_desc_i($node, $i);
            shorten_branch_confidence_str($desc);
        }
    }
}

# options: nwords - number of matching prefix words
# dim_strain = undef (D)
# links_to_genes = undef (D), $linkHash
# color_by = domain (D), 
# taxonomy = taxnomyHash
# pegs = toPegH
# functions = toRoleH
sub consolidate_tree {
    my ($tree, $opts) = @_;            
    my $nwords     = $opts->{nwords}   || 2; # same species and genus
    my $dim_strain = $opts->{dim_strain};

    consolidate_tree_decorate($tree, $nwords);

    my ($keep, $labelH) = consolidate_tree_keep_tips($tree, $opts);

    dim_strain_name($labelH) if $dim_strain;
    color_by_taxonomy($labelH, $opts) if $opts->{taxonomy} && $opts->{pegs};
    add_function_mouseover($labelH, $opts) if $opts->{functions};

    my $newtree = gjonewicklib::rooted_newick_subtree($tree, @$keep);
    if ($newtree) {
        $newtree = gjonewicklib::aesthetic_newick_tree($newtree);
        $newtree = gjonewicklib::newick_relabel_tips($newtree, $labelH);
        consolidate_tree_undecorate($newtree);
        return $newtree;
    }
    # return old tree if consolidation makes tree too small
    $tree = gjonewicklib::newick_relabel_tips($tree, $labelH);
    consolidate_tree_undecorate($tree);
    return $tree;
}

sub span_consolidated_subtree {
    my ($ncons, $lines) = @_;
    my $treestr = join("<br/>", map { "<nobr>$_</nobr>" } @$lines);
    $treestr = span_css($treestr, "mono");
    my $title = span_css("Consolidated Taxa", "mono");
    return span_mouseover(span_css("[$ncons]", "consolidated"), $title, $treestr); 
}

sub dim_strain_name {
    my ($labelH) = @_;
    while (my ($key, $val) = each %$labelH) {
        if ($val =~ /(\S+)\s+(\S+)\s+(\S.*)/) {
            $labelH->{$key} = "$1 $2 ". span_css($3, "strain");
        }
    }
}

sub domain {
    return lc $_[0]->[0];
}

sub color_by_taxonomy {
    my ($labelH, $opts) = @_;
    my $colorby   = $opts->{color_by} || "domain";
    my $pegH      = $opts->{pegs};
    my $taxonomyH = $opts->{taxonomy};
    while (my ($key, $val) = each %$labelH) {
        if ($key =~ /.*\(([.0-9a-zA-Z]{5,10})\)/) {
            my $abbrev  = $1;
            my $peg = $pegH->{$abbrev};
            my $org = ($peg =~ /(\d+\.\d+)/, $1);
            my $tax = $taxonomyH->{$org};
            my $grp = major_group($tax);
            # print join("\t", $abbrev, $peg, $org, @$tax) . "\n";
            if ($val =~ /(\S+)\s+(\S+)\s+(\S.*)/) {
                my ($genus, $species, $extra) = ($1, $2, $3);
                my $gs = add_peg_link("$genus $species", $peg);
                if ($colorby =~ /taxonomy/i && $grp) {
                    $labelH->{$key} = span_css(span_css($gs, domain($tax)), $grp) ." ". span_css($extra, "strain");
                } else {
                    $labelH->{$key} = span_css($gs, domain($tax)) ." ". span_css($extra, "strain");
                }
                # print join("\t", $grp, "'$genus $species'", @$tax[1..4])."\n" if $tax->[0] ne 'Archaea' && $tax->[0] ne 'Eukaryota';
            }
        }
    }
}

sub add_function_mouseover {
    my ($labelH, $opts) = @_;
    my $roleH     = $opts->{functions};
    my $pegH      = $opts->{pegs};
    my $taxonomyH = $opts->{taxonomy};
    while (my ($key, $val) = each %$labelH) {
        if ($key =~ /.*\(([.0-9a-zA-Z]{5,10})\)/) {
            my $abbrev = $1;
            my $role  = $roleH->{$abbrev};
            my $peg   = $pegH->{$abbrev};
            my $org   = ($peg =~ /(\d+\.\d+)/, $1);
            my $tax   = $taxonomyH->{$org};
            # print join("\t", $abbrev, $role, $peg, $org, @$tax[0..2]) . "\n";
            my $spc   = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
            my $roles = join("@<br/>$spc", map { "<nobr>$_</nobr>" } split(/@\s*/, $role));
            my $html  = "<b>Function</b><br/>$spc<nobr>$roles</nobr>";
            $html .= '<br/>'. join("<br/>$spc", "<b>Taxonomy</b>", map { "<nobr>$_</nobr>" } @$tax[0..5]) if $tax && $tax->[0];
            my $mouseover = span_mouseover($abbrev, 'Features', $html);
            $val =~ s/$abbrev/$mouseover/;
            $labelH->{$key} = $val;
        }
    }    
}

# opts{ java }
sub consolidate_tree_keep_tips {
    my ($node, $opts) = @_;
    my (@keep, %lblH);

    my $c1  = gjonewicklib::newick_c1($node);
    my $ncons = $c1->[-1];
    my $minx  = $c1->[-2];
    my $label = $c1->[-3];

    my $new_lbl = "$label ";

    my $ndesc;
    if ($ndesc = gjonewicklib::newick_n_desc($node)) {
        if (length($label) > 0) {
            @keep = ( $label );
            if ($opts->{html}) {
                my $subtips = gjonewicklib::newick_tip_list($node);
                my $subtree = gjonewicklib::rooted_newick_subtree($node, $subtips);
                # my $subtree = gjonewicklib::copy_newick_tree($node);
                # gjonewicklib::set_newick_x($subtree, 0);
                $subtree = gjonewicklib::aesthetic_newick_tree($subtree);
                # print join("\n", gjonewicklib::text_plot_newick($subtree))."\n";
                my $lines = gjonewicklib::text_plot_newick($subtree, { chars => "html_box", width => 1 } );
                $new_lbl .= span_consolidated_subtree($ncons, $lines);
            } else {
                $new_lbl .= "[$ncons]";
            }
            %lblH = ( $label => $new_lbl );
        } else {
            for (my $i = 1; $i <= $ndesc; $i++) {
                my $desc  = gjonewicklib::newick_desc_i($node, $i);
                my ($d_keep, $d_lblH) = consolidate_tree_keep_tips($desc, $opts);
                @keep = (@keep, @$d_keep);
                %lblH = (%lblH, %$d_lblH);
            }
        }
    } else {
        @keep = ( gjonewicklib::newick_lbl($node) );
        %lblH = ( $label => $new_lbl );
    }
    return (\@keep, \%lblH);
}

sub consolidate_tree_decorate {
    my ($node, $nwords) = @_;
    my ($label, $minx, $ncons);
    my $ndesc;
    if ($ndesc = gjonewicklib::newick_n_desc($node)) {
        for (my $i = 1; $i <= $ndesc; $i++) {
            my $desc = gjonewicklib::newick_desc_i($node, $i);
            consolidate_tree_decorate($desc, $nwords);
            my $desc_c1  = gjonewicklib::newick_c1($desc);
            my $desc_n   = $desc_c1->[-1];
            my $desc_x   = $desc_c1->[-2];
            my $desc_lbl = $desc_c1->[-3];
            if ($i == 1) {
                $label = $desc_lbl;
                $minx  = $desc_x;
                $ncons = $desc_n;
            } else {
                my @words1  = split(/\s+/, $label);
                my @words2  = split(/\s+/, $desc_lbl);
                # print join("\t", "words1 = ", @words1) . "\n";
                # print join("\t", "words2 = ", @words2) . "\n";
                my $prefix1 = join(" ", @words1[0 .. $nwords-1]);
                my $prefix2 = join(" ", @words2[0 .. $nwords-1]);
                # print "p1 = $prefix1\n";
                # print "p2 = $prefix2\n";
                if ($prefix1 ne $prefix2) {
                    $label = undef;
                    $minx  = undef;
                    $ncons = undef;
                } else {
                    $ncons += $desc_n;
                    if ($desc_x < $minx) {
                        $label = $desc_lbl;
                        $minx  = $desc_x;
                    }
                }
            }
        }
        $minx += gjonewicklib::newick_x($node);
    } else {
        $label = gjonewicklib::newick_lbl($node);
        $minx  = gjonewicklib::newick_x($node);
        $ncons = 1;
    }
    my $c1 = gjonewicklib::newick_c1($node);
    my @nc = $c1 ? (@$c1, $label, $minx, $ncons) : ($label, $minx, $ncons);
    gjonewicklib::set_newick_c1($node, \@nc);

}

sub consolidate_tree_undecorate {
    my ($node) = @_;

    my $c1 = gjonewicklib::newick_c1($node);
    if ($c1 && @$c1) {
        pop @$c1;
        pop @$c1 if @$c1;
        pop @$c1 if @$c1;
    }
    gjonewicklib::set_newick_c1($node, \@$c1);

    my $ndesc;
    if ( $ndesc = gjonewicklib::newick_n_desc( $node ) ) {
        for (my $d = 1; $d <= $ndesc; $d++) {
            consolidate_tree_undecorate(gjonewicklib::newick_desc_i($node, $d));
        }
    }
}

sub run {
    system($_[0]) == 0 or confess("FAILED: $_[0]");
}

1;
