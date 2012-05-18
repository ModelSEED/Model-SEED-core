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

package AlignTree;

use strict;

use Carp;     
use Data::Dumper;

use SeedAware;
use SeedUtils;

use ffxtree;
use gjoseqlib;
use gjoalignment;
use gjoalignandtree;
use gjoparseblast;
use representative_sequences;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw( align_sequences
                  trim_alignment
                  psiblast_search
                  make_tree );


#-------------------------------------------------------------------------------
#
#   @align = align_sequences( \@seqs, \%opts )
#  \@align = align_sequences( \@seqs, \%opts )
#   @align = align_sequences( \%opts )            # \@seqs = $opts{seqs}
#  \@align = align_sequences( \%opts )            # \@seqs = $opts{seqs}
#
#  Options:
#
#     tool         => program  # MAFFT (d), Muscle or clustal
#     clustal_ends => bool     # use clustal to align ends (zero end gap penalty) (D = 0)
#
#     Other options supported in align_with_clustal, align_with_muscle or align_with_mafft
#
#-------------------------------------------------------------------------------

sub align_sequences {
    my ($seqs, $opts);

    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $opts = $_[0];
        $seqs = $opts->{seqs};
    } else {
        ($seqs, $opts) = @_;
    }
    $opts->{version} or $seqs && ref $seqs eq 'ARRAY' && @$seqs
        or die "align_sequences called with invalid sequences.\n";

    my $program;

    $opts->{tool} ||= 'mafft';

    $opts->{muscle} = "/home/fangfang/bin/muscle" if -x "/home/fangfang/bin/muscle";
    $opts->{mafft}  = "/home/fangfang/bin/mafft"  if -x "/home/fangfang/bin/mafft";

    if    ($opts->{tool} =~ /muscle/i)  { $program = \&gjoalignment::align_with_muscle  }
    elsif ($opts->{tool} =~ /mafft/i)   { $program = \&gjoalignment::align_with_mafft   }
    elsif ($opts->{tool} =~ /clustal/i) { $program = \&gjoalignment::align_with_clustal }

    if ($opts->{version}) {
        if ($opts->{tool} =~ /clustal/i) { # version option not supported in gjoalignment::align_with_clustal
            my $clustal = SeedAware::executable_for($opts->{clustalw} || $opts->{program} || 'clustalw');
            my $tmpdir  = SeedAware::location_of_tmp($opts);
            my $tmpF    = SeedAware::new_file_name("$tmpdir/version", '');

            SeedAware::system_with_redirect($clustal, "--version", {stdout => $tmpF});

            open(F, $tmpF) or die "Could not open $tmpF";
            my @info = <F>;
            close(F);
            unlink($tmpF);
            my $version = $info[3]; # fourth line of Clustal usage info
            chomp($version);
            return $version;
        }
        return $program->($seqs, $opts);
    }

    my $ali = @$seqs > 1 ? $program->($seqs, $opts) : $seqs;

    if ($opts->{clustal_ends} && $opts->{tool} != ~/clustal/i && @$ali > 1) {
        my $opts2 = { global_coords => 1 };
        trim_ali_to_conserved_domains($ali, $opts2);
        my ($b, $e) = ($opts2->{global_beg}, $opts2->{global_end});
        # print STDERR "b, e, l = $b, $e, ". length($ali->[0]->[2])."\n";
        if (defined $b && defined $e && $b < $e) {
            my %inner;
            my @padded = @$ali;
            my $padstr = 'PADDINGPADDING';
            for (@padded) {
                $inner{$_->[0]} = substr($_->[2], $b, $e-$b+1);
                substr($_->[2], $b, $e-$b+1) = $padstr;
            }
            $ali = gjoalignment::align_with_clustal(@padded);
            for (@$ali) {
                $_->[2] =~ s/$padstr/$inner{$_->[0]}/e;
            }
        }
    }

    wantarray ? @$ali : $ali;
}


#-------------------------------------------------------------------------------
#
#   @trimmed_ali = trim_ali_to_conserved_domains( \@ali, \%opts )
#  \@trimmed_ali = trim_ali_to_conserved_domains( \@ali, \%opts )
#  
#  Options
#   
#     win_size        => size    # size of sliding window used in scoring domain conservation
#     domain_conserv  => thresh  # min mean domain conservation (D = 0.3)
#     residue_conserv => thresh  # min residule conservation for trimmed end sites (D = 0.1)
#     global_coords   => bool    # return coordinates of the internal region
#                                  between the relatively conserved end domains:
#                                    $opts->{global_beg} = first site
#                                    $opts->{global_end} = last site
#
#-------------------------------------------------------------------------------

sub trim_ali_to_conserved_domains {
    my ($ali, $opts) = @_;

    my $winsize = $opts->{win_size}        || 10;
    my $domain  = $opts->{domain_conserv}  || 0.3;
    my $residue = $opts->{residue_conserv} || 0.1;

    my $conserv = residue_conserv_scores($ali);
    my $len = length($ali->[0]->[2]);

    my ($b, $e);
    my ($s1, $s2);
    my ($r1, $r2);
    for ($b = 0; $b < $len; $b++) {
        $s1 += $conserv->[$b];
        $s1 -= $conserv->[$b-$winsize] if $b >= $winsize;
        last if $s1 >= $winsize * $domain && $b+1 >= $winsize;
    }
    for ($e = $len-1; $e > $b; $e--) {
        $s2 += $conserv->[$e];
        $s2 -= $conserv->[$e+$winsize] if $e+$winsize < $len;
        last if $s2 >= $winsize * $domain && $len-$e >= $winsize;
    }
    if ($opts->{global_coords}) {
        $opts->{global_beg} = $b+1;
        $opts->{global_end} = $e-1;
    }
    $b = max($b-$winsize+1, 0);      $b++ while $conserv->[$b] < $residue;
    $e = min($e+$winsize-1, $len-1); $e-- while $conserv->[$e] < $residue;

    my @ali2 = map { [@$_[0,1], substr($_->[2], $b, $e-$b+1)] } @$ali;

    wantarray ? @ali2 : \@ali2;
}

#-------------------------------------------------------------------------------
#
#  Calculate conservation scores for a protein alignment:
#
#   @conserv = residue_conserv_scores( \@ali);
#  \@conserv = residue_conserv_scores( \@ali);
#
#  The function returns an array of scores that correspond to the
#  degree of conservation of each column in a protein alignment.
#
#  Scores are in the range [0, 1] (1 indicates a column with all idential AAs)
#
#  This metric is based on ClustalX's conservation score (Thompson,
#  NAR 1997): One vector per sequence is defined for an alignment
#  site.  The vectors are defined in the space of amino acids using a
#  substitution matrix. A mean vector is then calculated for the site
#  and the final score is the average euclidean distance to the mean
#  vector.
# 
#  It is unclear how the original method converts a distance to a
#  similarity score. Here we use the following simple conversion:
#   
#    sim = min( 0, (1 - distance/MAX_DISTANCE) )
#
#  where MAX_DISTANCE is hardcoded to 10.
#
#-------------------------------------------------------------------------------

sub residue_conserv_scores {
    my ($ali) = @_;

    my @seq   = map { uc $_->[2] } @$ali;
    my $len   = length($seq[0]);
    my $nseq  = scalar @seq;
    my $chars = qr/^[A-Za-z]$/;

    my ($aa_list, $blosum62) = gjoalign2html::raw_blosum62();
    my $n_aa   = scalar @$aa_list;
    my $aa_str = join('', @$aa_list);
    my %aa_index = map { $_ => index($aa_str, $_) } @$aa_list;

    my @conserv;

    for (my $i = 0; $i < $len; $i++) {
        my %cnt;
        my $nongap;
        my @col = map { substr($_, $i, 1) } @seq;
        foreach (@col) { if (/$chars/) { $cnt{$_}++; $nongap++ } }
        if ($nongap == 0) {
            push @conserv, 0;
            next;
        }
        my @center;
        my $ind;
        my @dist;
        my $total;
        for my $ia (0..$n_aa-1) {
            for my $c (keys %cnt) {
                $ind = $aa_index{$c};
                $center[$ia] += $cnt{$c} * $blosum62->[$ind]->[$ia];
            }
            $center[$ia] /= $nongap;
            for my $c (keys %cnt) {
                $ind = $aa_index{$c};
                $dist[$ia] += $cnt{$c} * ($blosum62->[$ind]->[$ia] - $center[$ia]) ** 2;
            }
            $total += $dist[$ia];
        }
        $total  = sqrt($total/$nongap);
        $total  = 1 - $total/10;
        $total  = 0 if $total < 0;
        $total *= ($nongap / $nseq);

        push @conserv, $total;
    }

    wantarray ? @conserv : \@conserv;
}


#-------------------------------------------------------------------------------
#   @conserved_regions = conserved_regions_in_ali( \@align, \%opts)
#  \@conserved_regions = conserved_regions_in_ali( \@align, \%opts)
# 
#  Options:
#
#     conserv    => HASH      # precomputed conservation data
#     sort       => BOOL      # return regions sort by conservation 
#     thresh     => conserve  # threshold for average site convervation score (D = 0.6)
#     win_min    => size      # minimum window size (D = 4)
#     win_max    => size      # maximum window size (D = 10)
#
#-------------------------------------------------------------------------------

sub conserved_regions_in_ali {
    my ($ali, $opts) = ffxtree::process_input_args_w_ali(@_);

    my $win_min = $opts->{win_min} || 4;
    my $win_max = $opts->{win_max} || 10;
    my $thresh  = $opts->{thresh}  || 0.6;
    my $conserv = $opts->{conserv} || AlignTree::residue_conserv_scores($ali);
    my $sort    = $opts->{sort};
    
    my @cands;
    my %cov;
    my @sum;
    my @coords;

    my $len = length($ali->[0]->[2]);
    for (my $i = 1; $i <= $len; $i++) { # 1-based coordinates
        $sum[$i] = $sum[$i-1] + $conserv->[$i-1];
    }

    for (my $b = 1; $b <= $len-$win_min + 1; $b++) {
        for (my $e = $b+$win_min-1; $e < $b+$win_max && $e <= $len; $e++) {
            my $score = sprintf "%.3f", ($sum[$e] - $sum[$b-1]) / ($e - $b + 1);
            push @cands, [$b, $e, $score] if $score >= $thresh;
        }
    }

    # @cands = sort { $b->[2] <=> $a->[2] } @cands if $sort;
    @cands = sort { $b->[2] <=> $a->[2] } @cands;
    # return @cands;

    for my $cand (@cands) {
        my ($b, $e, $score) = @$cand;
        my $seen;
        $seen += $cov{$_} for $b..$e;
        next if $seen;

        push @coords, $cand;
        $cov{$_} = 1 for $b..$e;
    }

    wantarray ? @coords : \@coords;
}

#-------------------------------------------------------------------------------
#
#   @align = trim_alignment( \@align, \%opts )
#  \@align = trim_alignment( \@align, \%opts )
#   @align = trim_alignment( \%opts )            # input \@align = $opts{ali}
#  \@align = trim_alignment( \%opts )            # input \@align = $opts{ali}
#
#  Options:
#
#     align_opts    => HASH    #  options for all alignment operations in trimming. Use Clustal by default.
#     fract_cov     => fract   #  fraction of sequences to be covered in initial trimming of ends (D: 0.75)
#     fract_ends    => fract   #  minimum fraction of ends to be considered significant for uncov cutoff (D = 0.1)
#     keep_def      => bool    #  do not append trimming coordinates to description fields in seqs
#     log_dir       => dir     #  directory for log files 
#     log_prefix    => string  #  prefix for log file names
#     max_reps_sim  => thresh  #  threshold used to collapse seqs into representatives (D = 0.9)
#     single_round  => bool    #  if set to false, additional rounds of psiblast are attempted to incorporate seqs with multiple hsps.
#     skip_psiblast => bool    #  trim to median ends only
#     to_domain     => bool    #  trim to end conserved domains
#     use_reps      => bool    #  first collapse seqs into representatives
#     win_size      => size    #  size of sliding window used in calculating uncov cutoff (D = 10)
#
#     domain_conserv  => thresh  # min mean domain conservation (D = 0.3)
#     residue_conserv => thresh  # min residule conservation for trimmed end sites (D = 0.1)
#
#-------------------------------------------------------------------------------

sub trim_alignment {
    my ($ali, $opts);

    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $opts = $_[0];
        $ali  = $opts->{ali} || $opts->{seqs};
    } else {
        ($ali, $opts) = @_;
    }
    $ali && ref $ali eq 'ARRAY' && @$ali
        or die "trim_alignment called with invalid alignment.\n";

    my $skip_psiblast = $opts->{skip_psiblast} ? 1 : 0;
    my $single_round  = $opts->{single_round}  ? 1 : 0;
    my $to_domain     = $opts->{to_domain}     ? 1 : 0;
    my $log_dir       = $opts->{log_dir}      || SeedAware::location_of_tmp();
    my $keep_log      = $opts->{keep_log}     || $opts->{log_dir} ? 1 : 0;
    my $log_prefix    = $opts->{log_prefix};
    my $use_reps      = $opts->{use_reps}     || $opts->{max_reps_sim} ? 1 : 0;
    my $max_reps_sim  = $opts->{max_reps_sim} || 0.90;
    my $fract_cov     = $opts->{fract_cov}    || 0.75;
    my $fract_ends    = $opts->{fract_ends}   || 0.10;
    my $win_size      = $opts->{win_size}     || 10;
    my $keep_def      = $opts->{keep_def};
    my $align_opts    = $opts->{align_opts};

    my $trim0 = $to_domain ? trim_ali_to_conserved_domains($ali, $opts) :
        gjoalignandtree::trim_align_to_median_ends($ali, {begin => 1, end => 1, fract_cov => $fract_cov});

    if (!$keep_def && $skip_psiblast) {
        my %full = map { $_->[0] => $_->[2] } @$ali;
        for (@$trim0) {
            my $s0 = $full{$_->[0]};  $s0 =~ tr/A-Za-z//cd;    #  remove gaps
            my $s  = $_->[2];         $s  =~ tr/A-Za-z//cd;   

            my $l = length($s0);
            my $b = index(lc $s0, lc $s) + 1;
            my $e = $b + length($s) - 1;
            $_->[1] .= " ($b-$e/$l)" if $b > 1 || $e < $l;
        }
    }
    
    return wantarray ? @$trim0 : $trim0 if $skip_psiblast;

    SeedUtils::verify_dir($log_dir);
    my $log_stderr = $keep_log ? SeedAware::new_file_name("$log_dir/$log_prefix" . "psiblast.stderr") : "/dev/null";
    my $log_report = $keep_log ? SeedAware::new_file_name("$log_dir/$log_prefix" . "psiblast.report") : "/dev/null";

    my $reps               = $use_reps ? representative_sequences::rep_seq_2($trim0, {max_sim => $max_reps_sim}) : [@$trim0];
    my $db                 = gjoseqlib::pack_sequences($ali);
    my $profile            = align_sequences($reps, $align_opts);
    my $blast              = gjoalignandtree::blastpgp($db, $profile, {stderr => $log_stderr});
    my ($trimmed, $report) = process_psiblast_v2($blast, $opts);
    
    my $report_string      = join("\n", map { join "\t", @$_ } values %$report) . "\n";

    print_string($log_report, $report_string) if $keep_log;

    my $new_ali = align_sequences($trimmed, $align_opts);
    return wantarray ? @$new_ali : $new_ali if $single_round;

    my @to_trim = grep { $report->{$_->[0]} =~ /multiple hsps/ } @$trim0;

    my $round = 2;
    while (@to_trim >= max(2, @$ali/10)) {
        my $log_stderr  = $keep_log ? SeedAware::new_file_name("$log_dir/$log_prefix" . "psiblast.stderr.$round") : "/dev/null";
        my $log_report  = $keep_log ? SeedAware::new_file_name("$log_dir/$log_prefix" . "psiblast.report.$round") : "/dev/null";
        my $blast       = gjoalignandtree::blastpgp($db, \@to_trim, {stderr => $log_stderr});
        my ($trm, $rpt) = process_psiblast_v2($blast, $opts);
        my @new_hits    = grep { $report->{$_->[0]} =~ /multiple hsps/ } @$trm;
        @to_trim        = grep { $rpt->{$_->[0]}    =~ /multiple hsps/ } @$trm; 

        push @$trimmed, $_ for @new_hits;
    }
    
    $new_ali = align_sequences($trimmed, $align_opts);
    wantarray ? @$new_ali : $new_ali;
}


#-------------------------------------------------------------------------------
#
#    \@seq             = psiblast_search( $db, $profile, \%opts )
#  ( \@seq, \%report ) = psiblast_search( $db, $profile, \%opts )
#    \@seq             = psiblast_search( $profile, \%opts )
#  ( \@seq, \%report ) = psiblast_search( $profile, \%opts )
#    \@seq             = psiblast_search( \%opts )
#  ( \@seq, \%report ) = psiblast_search( \%opts )
#
#     $profile can be $profile_file_name or \@profile_seqs
#     $db      can be $db_file_name      or \@db_seqs, or
#              'SEED', 'PSEED' or 'PPSEED', for protein seqs in complete genomes in annotator's SEED, PSEED or PUBLIC-PSEED
#
#     If supplied as file, profile is pseudoclustal
#
#     Report records:
#
#         [ $sid, $scr, $e_value, $slen, $status,
#                 $frac_id, $frac_pos,
#                 $q_uncov_n_term, $q_uncov_c_term,
#                 $s_uncov_n_term, $s_uncov_c_term ]
#
#  Options:
#
#     e_value       =>  $max_e_value    #  maximum blastpgp E-value (D = 0.01)
#     incremental   =>  bool            #  expand an initial set with multiple rounds of psiblast
#     max_e_val     =>  $max_e_value    #  maximum blastpgp E-value (D = 0.01)
#     max_q_uncov   =>  $aa_per_end     #  maximum unmatched query (D = min{20, qlen/3})
#     max_q_uncov_c =>  $aa_per_end     #  maximum unmatched query, c-term (D = min{20, qlen/3})
#     max_q_uncov_n =>  $aa_per_end     #  maximum unmatched query, n-term (D = min{20, qlen/3})
#     min_ident     =>  $frac_ident     #  minimum fraction identity (D = 0.15)
#     min_positive  =>  $frac_positive  #  minimum fraction positive scoring (D = 0.20)
#     min_frac_cov  =>  $frac_cov       #  minimum fraction coverage of query and subject sequence (D = 0.20)
#     min_q_cov     =>  $frac_cov       #  minimum fraction coverage of query sequence (D = 0.50)
#     min_s_cov     =>  $frac_cov       #  minimum fraction coverage of subject sequence (D = 0.20)
#     max_reps_sim  =>  $thresh         #  threshold used to collapse seqs into representatives (D = 0.8)
#     nresult       =>  $max_seq        #  maximim matching sequences (D = 5000)
#     nthread       =>  $n_thread       #  number of blastpgp threads (D = 2)
#     query         =>  $q_file_name    #  query sequence file (D = most complete)
#     query         => \@q_seq_entry    #  query sequence (D = most complete)
#     stderr        =>  $file           #  blastpgp stderr (D = /dev/stderr)
#
#  Options for incremental search:
#
#     max_reps_sim      =>  $thresh     #  threshold used to collapse seqs into representatives (D = 0.9)
#     min_seqs_for_reps =>  $n          #  only use representative seqs if number of seqs exceeds this threshold (D = 100)
#     stop_round        =>  $n          #  for incremental search, stop after a specified number of psiblast rounds (D = unlimited)
#     use_reps          =>  bool        #  collapse profile seqs into representatives before submitting to psiblast
#
#  If supplied, query must be identical to a profile sequence, but no gaps.
#
#-------------------------------------------------------------------------------

sub psiblast_search {
    my ($db, $profile, $opts);

    if    (@_ >= 2 && ref $_[1] eq 'ARRAY') { ($db, $profile, $opts) = @_ }
    elsif (@_ >= 1 && ref $_[0] eq 'ARRAY') { ($profile, $opts)      = @_ }
    elsif (@_ == 1 && ref $_[0] eq 'HASH')  { ($opts)                = @_ }

    $opts->{nresult} ||= 5000;
    $opts->{nthread} ||= 2;
    $opts->{stderr}  ||= '/dev/null';

    $profile ||= $opts->{profile};
    $db      ||= $opts->{db} || 'SEED';

    # my $org_dir = "/home/fangfang/FIGdisk/FIG/Data/Organisms";
    # my $org_dir = ${FIG_Config::data};  # does not work on bio-big
    my $org_dir = "/vol/public-pseed/FIGdisk/FIG/Data/Organisms"; # complete genomes only
    my $psi_dir = $ENV{PsiblastDB} || "/home/fangfang/WB/PsiblastDB";

    if (ref $db ne 'ARRAY') {
        if ($db =~ /^(\d+\.\d+)$/) { $db = "$org_dir/$1/Features/peg/fasta" }
        elsif (uc $db eq 'PPSEED') { $db = "$psi_dir/public-pseed.complete" }
        elsif (uc $db eq 'PSEED')  { $db = "$psi_dir/ppseed.NR" }
        elsif (uc $db eq 'SEED')   { $db = "$psi_dir/SEED.complete.fasta" }
    }

    my $inc = $opts->{incremental} || $opts->{inc};

    my ($hits, $report, $history) = $inc ? incremental_psiblast_search($db, $profile, $opts)
                                         : gjoalignandtree::extract_with_psiblast($db, $profile, $opts);
    
    wantarray ? ($hits, $report, $history) : $hits;
}


sub db_name_to_file {
    my ($db) = @_;
    my $org_dir = "/vol/public-pseed/FIGdisk/FIG/Data/Organisms"; # complete genomes only
    my $psi_dir = "/home/fangfang/WB/PsiblastDB/";
    if ($db =~ /^(\d+\.\d+)$/) { $db = "$org_dir/$1/Features/peg/fasta" }
    elsif (uc $db eq 'PPSEED') { $db = "$psi_dir/public-pseed.complete" }
    elsif (uc $db eq 'PSEED')  { $db = "$psi_dir/ppseed.NR" }
    elsif (uc $db eq 'SEED')   { $db = "$psi_dir/SEED.complete.fasta" }
    return $db;
}

#-------------------------------------------------------------------------------
#
#  Incremental psiblast search from a small set of initial sequences,
#  which may be unaligned.
#  
#    \@seq                        = incremental_psiblast_search( $db, $profile, \%opts )
#  ( \@seq, \%report, \@history ) = incremental_psiblast_search( $db, $profile, \%opts )
#
#  Options
#
#     max_query_nseq    => $n        # stop when the number of query sequences exceeds this threshold
#     max_reps_sim      => $thresh   # threshold used to collapse seqs into representatives (D = 0.95)
#     min_seqs_for_reps => $n        # only use representative seqs if number of seqs exceeds this threshold (D = 10)
#     stop_round        => $n        # stop after a specified number of psiblast rounds (D = unlimited)
#     use_reps          => bool      # always collapse profile seqs into representatives before submitting to psiblast
#
#  Other options only affect the final round of psiblast. 
#
#  Report records are documented in psiblast_search().
#
#  History consists a list 4-tuples, corresponding to search status
#  at each psiblast round:
#    
#     [ profile_length, num_starting_seqs, num_trimmed_reps, num_psiblast_hits ]
#  
#  The psiblast hits at the end of each round are aligned, trimmed,
#  and sorted.  The top hits are then selected to form the set of
#  profile sequences for the next round.  The algorithm tries to
#  expand the set cautiously. Unless the psiblast hits share high
#  identity (~75%) with the profile, the set grows by no more than a
#  factor of 2 each round.  If neither stop_round nor max_query_nseq
#  is specified, the process runs to convergence or until the number
#  of profile sequences reaches 500.
#
#-------------------------------------------------------------------------------

sub incremental_psiblast_search {
    my ($db, $profile, $opts) = @_;

    my $stop_round        = $opts->{stop_round};
    my $max_query_nseq    = $opts->{max_query_nseq}    || 500;
    my $max_reps_sim      = $opts->{max_reps_sim}      || 0.95;
    my $min_reps_seqs     = $opts->{min_seqs_for_reps} || 10;
    my $nthread           = $opts->{nthread}           || 2;
    my $fast              = $opts->{fast_trimming}     || $opts->{fast} ? 1 : 0;
    my $use_reps          = $opts->{use_reps}          || $opts->{max_reps_sim} ? 1 : 0;

    my $initial_set_keep  = 0.8;
    my $significant_score = 150;  # 150 = ~ (+ 75% id + %80 pos - 25 uncov)
    my $expansion_factor  = 2;    # query set doubles each round
    my $frac_id_weight    = 100;
    my $frac_pos_weight   = 100;
    my $uncov_penalty_q   = 0.2;
    my $uncov_penalty_s   = 0.02;

    my @history;
    my @prof = @$profile;

    my $opts2 = { tool => 'mafft', auto => 1, 'clustal_ends' => !$fast };                                                                      # align
    my $opts3 = { query => $opts->{query}, e_value => 0.01, max_q_uncov => 500, nresult => 5000, stderr => '/dev/null', nthread => $nthread }; # psiblast
    my $opts4 = $fast || $initial_set_keep >= 1 ? { to_domain => 1, skip_psiblast => 1 } : { align_opts => $opts2 };                           # trim

    # in case profile seqs are unaligned
    my @lens = sort { $a <=> $b } map { length $_->[2] } @$profile;
    if ($lens[0] != $lens[-1]) {  
        my $reps  = $use_reps && @prof >= $min_reps_seqs ? representative_sequences::rep_seq_2(\@prof, {max_sim => $max_reps_sim}) : [@prof];
        my $ali   = align_sequences($reps, $opts2);
        my $trim  = trim_alignment($ali, $opts4);
        my $redo  = (@$trim / @$ali) < $initial_set_keep;
        $trim     = trim_alignment($ali, { skip_psiblast => 1 }) if $redo;            
        @prof     = @$trim;

        my $record = [ length $ali->[0]->[2], scalar @$profile, scalar @$trim ];
        push @history, $record;
        print STDERR join("\t", @$record). "\n";
    } 

    $max_query_nseq = min($max_query_nseq, $opts->{nresult}) if $opts->{nresult} > 0;
    my @seqs = @$profile;
    my $query;
    my $i = 0;
    while (@seqs < $max_query_nseq) {
        my ($hits, $report) = gjoalignandtree::extract_with_psiblast($db, \@prof, $opts3);
        my $record = [ length $prof[0]->[2], scalar @seqs, scalar @prof, scalar keys %$report ];
        push @history, $record;
        print STDERR join("\t", @$record)."\n";
        last unless @$hits > 0;

        my %score;
        for (keys %$report) {
            my ($scr, $exp, $slen, $status, $frac_id, $frac_pos, $uncov_q1, $uncov_q2, $uncov_s1, $uncov_s2) = @{$report->{$_}}[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
            next unless $status =~ /included/i;
            my $uncov_q = $uncov_q1 + $uncov_q2;
            my $uncov_s = $uncov_s1 + $uncov_s2;
            $score{$_}  = $frac_id * $frac_id_weight + $frac_pos * $frac_pos_weight
                          - $uncov_q * $uncov_penalty_q - $uncov_s * $uncov_penalty_s; 
        }
        my @keep;
        for (sort { $score{$b} <=> $score{$a} } keys %score) {
            last if @keep / @prof >= $expansion_factor && $score{$_} < $significant_score;
            push @keep, $_;
        }
        my %seen;
        $seen{$_} = 1 for @keep;
        @seqs     = grep { $seen{$_->[0]} } @$hits;

        my $qid   = $opts3->{query_used}->[0];
        my $reps  = $use_reps && @seqs >= $min_reps_seqs ? representative_sequences::rep_seq_2(\@seqs, {max_sim => $max_reps_sim, keep_id => [$qid]}) : [@seqs];
        my $ali   = align_sequences($reps, $opts2);
        my $trim  = trim_alignment($ali, $opts4);

        my ($query) = grep { $_->[0] eq $qid } @$trim;
        $opts3->{query} = $query;
        # print STDERR '$reps = '. Dumper($reps);
        # print STDERR '$query = '. Dumper($query);
        # print STDERR "hits, seqs, trim = ". scalar@$hits. "\t". scalar@seqs. "\t". scalar@$trim . "\n";

        last if @$trim <= @prof || @$trim >= $max_query_nseq || ($stop_round && ++$i >= $stop_round);

        @prof = @$trim;
    }

    my ($hits, $report) = gjoalignandtree::extract_with_psiblast($db, \@prof, $opts); 
    my $record = [ length $prof[0]->[2], scalar @seqs, scalar @prof, scalar @$hits ];
    push @history, $record;
    print STDERR join("\t", @$record). "\n";

    wantarray ? ($hits, $report, \@history) : $hits;
}


#-------------------------------------------------------------------------------
#
#  Blast wrapper
#
#-------------------------------------------------------------------------------

sub blast {
    my ($db, $query, $opts);

    if    (@_ >= 2 && ref $_[1] eq 'ARRAY') { ($db, $query, $opts) = @_ }
    elsif (@_ >= 1 && ref $_[0] eq 'ARRAY') { ($query, $opts)      = @_ }
    elsif (@_ == 1 && ref $_[0] eq 'HASH')  { ($opts)              = @_ }

    $db    ||= $opts->{db} || $opts->{seqs} || db_name_to_file($db);
    $query ||= $opts->{query};
    $query   = [ grep { $_->[0] eq $query } @$db ]->[0] if $db && (ref $db eq 'ARRAY') && @$db > 0;

    my $tmp = SeedAware::location_of_tmp( $opts );

    my ( $dbfile, $rm_db );
    if ( defined $db && ref $db )
    {
        ref $db eq 'ARRAY'
            && @$db
            || print STDERR "blast requires one or more database sequences.\n"
               && return undef;
        $dbfile = SeedAware::new_file_name( "$tmp/blast_db" );
        gjoseqlib::print_alignment_as_fasta( $dbfile, $db );
        $rm_db = 1;
    }
    elsif ( defined $db && -f $db )
    {
        $dbfile = $db;
    }
    else
    {
        die "blastpgp requires database.";
    }
    verify_db( $dbfile, 'P' );  # protein
    

    my ( $qfile, $rm_query );
    if ( defined $query && ref $query )
    {
        ref $query eq 'ARRAY' && @$query == 3
            or print STDERR "blast invalid query sequence.\n"
               and return undef;

        $qfile = SeedAware::new_file_name( "$tmp/blast_query" );
        gjoseqlib::print_alignment_as_fasta( $qfile, [$query] );
        $rm_query = 1;
    }
    elsif ( defined $query && -f $query )
    {
        $qfile = $query;
        ( $query ) = gjoseqlib::read_fasta( $qfile );
    }
    else
    {
        die "blast requires query.";
    }

    my $e_val  = $opts->{ e_value }  || $opts->{ max_e_val } || $opts->{ max_e_value }            ||    0.01;
    my $n_cpu  = $opts->{ n_thread } || $opts->{ nthread } || $opts->{ n_cpu } || $opts->{ ncpu } ||    2;
    my $nkeep  = $opts->{ n_result } || $opts->{ nresult }                                        || 1000;
    my $prog   = $opts->{ program  } || $opts->{ blast_program } || 'blastp';
    my $stderr = $opts->{ stderr }   || '/dev/null';

    my $blastall = SeedAware::executable_for( 'blastall' )
        or print STDERR "Could not find executable for program 'blastall'.\n"
            and return undef;

    my @cmd = ( $blastall,
                '-p' => $prog,
                '-d' => $dbfile,
                '-i' => $qfile,
                '-e' => $e_val,
                '-b' => $nkeep,
                '-v' => $nkeep,
                '-F' => 'F'
              );
    push @cmd, ( '-a' => $n_cpu ) if $n_cpu;
    
    my $blastfh = SeedAware::read_from_pipe_with_redirect( @cmd, { stderr => $stderr } )
           or print STDERR "Failed to open: '" . join( ' ', @cmd ), "'.\n"
              and return undef;

    my $out = gjoparseblast::blast_hsp_list( $blastfh, 1 );  
    close $blastfh;

    if ( $rm_db )
    {
        my @files = grep { -f $_ } map { ( $_, "$_.psq", "$_.pin", "$_.phr" ) } $dbfile;
        unlink @files if @files;
    }
    unlink $qfile if $rm_query;

    if ($opts->{m8} && $out && @$out > 0) {
        my @records = map {
                            my ($qid, $qdef, $qlen, $sid, $sdef, $slen, $scr,
                                $e_val, $p_n, $p_val, $n_mat, $n_id, $n_pos, $n_gap,
                                $dir, $q1, $q2, $qseq, $s1, $s2, $sseq) = @$_;
                            join("\t", $qid, $sid, sprintf("%.2f", 100 * $n_id / $n_mat),
                                 $n_mat, $n_mat - $n_id - $n_gap, $n_gap, $q1, $q2,
                                 $s1, $s2, $e_val, $scr, $qlen, $slen) ."\n";
        } @$out;
        $out = join('', @records);
    }

    return $out;
}



#-------------------------------------------------------------------------------
#
#  Incremental psiblast search from a small set of initial sequences,
#  which may be unaligned.
#  
#    \@seq                        = incremental_psiblast_search( $db, $profile, \%opts )
#  ( \@seq, \%report, \@history ) = incremental_psiblast_search( $db, $profile, \%opts )
#
#  Options
#
#     max_reps_sim      => $thresh   # threshold used to collapse seqs into representatives (D = 0.9)
#     min_seqs_for_reps => $n        # only use representative seqs if number of seqs exceeds this threshold (D = 100)
#     stop_round        => $n        # stop after a specified number of psiblast rounds (D = unlimited)
#     use_reps          => bool      # always collapse profile seqs into representatives before submitting to psiblast
#
#  Other options only affect the final round of psiblast. 
#
#  Report records are documented in psiblast_search().
#
#  History consists a list 4-tuples, corresponding to search status
#  at each psiblast round:
#    
#     [ profile_length, num_starting_seqs, num_trimmed_reps, num_psiblast_hits ]
#  
#  The psiblast hits at the end of each round are aligned, trimmed,
#  and sorted.  The top hits are then selected to form the set of
#  profile sequences for the next round.  The algorithm tries to
#  expand the set cautiously. Unless the psiblast hits share high
#  identity (~75%) with the profile, the set grows by no more than a
#  factor of 2 each round.  If stop_round is not specified, the
#  process runs to convergence or until the number of profile
#  sequences reaches 500.
#
#-------------------------------------------------------------------------------

sub incremental_psiblast_search_0 {
    my ($db, $profile, $opts) = @_;

    my $stop_round        = $opts->{stop_round};
    my $max_reps_sim      = $opts->{max_reps_sim}      || 0.9;
    my $min_reps_seqs     = $opts->{min_seqs_for_reps} || 100;
    my $use_reps          = $opts->{use_reps}          || $opts->{max_reps_sim} ? 1 : 0;

    my $max_nseq_clustal  = 100;
    my $initial_set_keep  = 0.8;
    my $max_query_nseq    = 500;
    my $significant_score = 150;  # 150 = ~ (+ 75% id + %80 pos - 25 uncov)
    my $expansion_factor  = 2;    # query set doubles each round
    my $frac_id_weight    = 100;
    my $frac_pos_weight   = 100;
    my $uncov_penalty     = 0.2;

    my @history;
    my @prof = @$profile;

    # in case profile seqs are unaligned
    my @lens = sort { $a <=> $b } map { length $_->[2] } @$profile;
    if ($lens[0] != $lens[-1]) {  
        my $reps  = $use_reps && @prof >= $min_reps_seqs ? representative_sequences::rep_seq_2(\@prof, {max_sim => $max_reps_sim}) : [@prof];
        my $opts2 = @$reps < $max_nseq_clustal ? { tool => 'clustal' } : { tool => 'mafft' };
        my $ali   = align_sequences($reps, $opts2);
        my $trim  = trim_alignment($ali, { align_opts => $opts2 });
        my $redo  = (@$trim / @$ali) < $initial_set_keep;
        $trim     = trim_alignment($ali, { skip_psiblast => 1 }) if $redo;
        @prof     = @$trim;

        my $record = [ length $ali->[0]->[2], scalar @$profile, scalar @$trim ];
        push @history, $record;
        print STDERR join("\t", @$record). "\n";
    } 

    my $opts3 = { e_value => 0.01, max_q_uncov => 1000, nresult => 1000, stderr => '/dev/null' };

    $max_query_nseq = min($max_query_nseq, $opts->{nresult}) if $opts->{nresult} > 0;
    my @seqs = @$profile;
    my $i = 0;
    while (@seqs < $max_query_nseq) {
        my ($hits, $report) = gjoalignandtree::extract_with_psiblast($db, \@prof, $opts3);
        my $record = [ length $prof[0]->[2], scalar @seqs, scalar @prof, scalar keys %$report ];
        push @history, $record;
        print STDERR join("\t", @$record)."\n";
        my %score;
        for (keys %$report) {
            my ($scr, $exp, $status, $frac_id, $frac_pos, $uncov_q1, $uncov_q2) = @{$report->{$_}}[1, 2, 4, 5, 6, 7, 8];
            next unless $status =~ /included/i;
            my $uncov = $uncov_q1 + $uncov_q2;
            $score{$_} = $frac_id * $frac_id_weight + $frac_pos * $frac_pos_weight - $uncov * $uncov_penalty; 
        }
        my @keep;
        for (sort { $score{$b} <=> $score{$a} } keys %score) {
            last if @keep / @prof >= $expansion_factor && $score{$_} < $significant_score;
            push @keep, $_;
        }
        my %seen;
        $seen{$_} = 1 for @keep;
        @seqs     = grep { $seen{$_->[0]} } @$hits;
        my $reps  = $use_reps && @seqs >= $min_reps_seqs ? representative_sequences::rep_seq_2(\@seqs, {max_sim => $max_reps_sim}) : [@seqs];
        my $opts2 = @$reps < $max_nseq_clustal ? { tool => 'clustal' } : { tool => 'mafft' };
        my $ali   = align_sequences($reps, $opts2);
        my $trim  = trim_alignment($ali, { align_opts => $opts2 });

        last if @$trim <= @prof || ($stop_round && ++$i >= $stop_round);
        # last if subset_ratio([map($_->[0], @$trim)], [map($_->[0], @$profile)]) < $initial_set_keep;

        @prof = @$trim;
    }

    my ($hits, $report) = gjoalignandtree::extract_with_psiblast($db, \@prof, $opts);
    my $record = [ length $prof[0]->[2], scalar @seqs, scalar @prof, scalar @$hits ];
    push @history, $record;
    print STDERR join("\t", @$record). "\n";

    wantarray ? ($hits, $report, \@history) : $hits;
}


#-------------------------------------------------------------------------------
#  [ S1 \cap S2 ] / [ S2 ]
#-------------------------------------------------------------------------------
sub subset_ratio {
    my ($set1, $set2) = @_;
    my %seen; $seen{$_}++ for @$set2;
    my $cnt; $seen{$_} && $cnt++ for @$set1;
    return @$set1 ? $cnt / @$set1 : 0;
}


#-------------------------------------------------------------------------------
#
#  Options:
#
#     keep_def      =>  bool            #  do not append trimming coordinates to description fields in seqs
#     fract_ends    =>  $fract_ends     #  minimum fraction of ends to be considered significant for uncov cutoff (D = 0.1)
#     max_q_uncov   =>  $aa_per_end     #  maximum unmatched query (D = min{20, qlen/3})
#     max_q_uncov_c =>  $aa_per_end     #  maximum unmatched query, c-term (D = min{20, qlen/3})
#     max_q_uncov_n =>  $aa_per_end     #  maximum unmatched query, n-term (D = min{20, qlen/3})
#     min_ident     =>  $frac_ident     #  minimum fraction identity (D = 0.15)
#     min_positive  =>  $frac_positive  #  minimum fraction positive scoring (D = 0.20)
#     min_q_cov     =>  $aa_covered     #  minimum number of query characters covered (D = max{10, qlen/5})
#     win_size      =>  size            #  size of sliding window used in calculating uncov cutoff (D = 10)
#
#-------------------------------------------------------------------------------

sub process_psiblast_v2 {
    my ( $blast, $opts ) = @_;

    $blast && ref $blast eq 'ARRAY' or return ();
    $opts  && ref $opts  eq 'HASH'  or $opts = {};

    my( $qid, $qdef, $qlen, $qhits ) = @{ $blast->[0] };

    my $keep_def      = $opts->{ keep_def }      || $opts->{ keep_seq_def } ? 1 : 0;  
    my $fract_ends    = $opts->{ fract_ends }    || $opts->{ fraction_ends } || 0.1;               # fraction of sequences ending in window
    my $max_q_uncov_c = $opts->{ max_q_uncov_c } || $opts->{ max_q_uncov }   || min(20, $qlen/3);
    my $max_q_uncov_n = $opts->{ max_q_uncov_n } || $opts->{ max_q_uncov }   || min(20, $qlen/3);
    my $min_q_cov     = $opts->{ min_q_cov }     || $opts->{ min_nongaps }   || max(10, $qlen/5);
    my $min_ident     = $opts->{ min_ident }     ||  0.15;
    my $min_pos       = $opts->{ min_positive }  ||  0.20;
    my $win_size      = $opts->{ win_size }      || $opts->{ window_size }   || 10;

    my (@uncov1, @uncov2);

    foreach my $sdata ( @$qhits ) {
        my( $sid, $sdef, $slen, $hsps ) = @$sdata;
        if ( one_real_hsp($hsps) ) {
#            [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#               0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
            my( $q1, $q2, $s1, $s2 ) = ( @{ $hsps->[0] } )[9, 10, 12, 13];
            push @uncov1, [ $q1-1,     $s1-1     ];
            push @uncov2, [ $qlen-$q2, $slen-$s2 ];
        }
    }

    my $q1_cut = calc_uncov_cut(\@uncov1, $fract_ends, $win_size) + 1;
    my $q2_cut = $qlen - calc_uncov_cut(\@uncov2, $fract_ends, $win_size);

    my (@trimmed, %report, $status);

    foreach my $sdata ( @$qhits ) {
        my( $sid, $sdef, $slen, $hsps ) = @$sdata;

        if ( one_real_hsp($hsps) ) {

            my $hsp0 = $hsps->[0];
            my ($scr, $exp, $nmat, $nid, $npos, $q1, $q2, $qseq, $s1, $s2, $sseq) = (@$hsp0)[ 0, 1, 4, 5, 6, 9, 10, 11, 12, 13, 14 ];

            my $uncov1 = $q1 <= $q1_cut ? 0 : $q1 - $q1_cut;
            my $uncov2 = $q2 >= $q2_cut ? 0 : $q2_cut - $q2;
      
            if    ( $q1-1     > $max_q_uncov_n ) { $status = 'missing start' }
            elsif ( $qlen-$q2 > $max_q_uncov_c ) { $status = 'missing end' }
            elsif ( $nid  / $nmat < $min_ident ) { $status = 'low identity' }
            elsif ( $npos / $nmat < $min_pos )   { $status = 'low positives' }
            else {
                my ($t1, $t2, $s1t, $s2t);
                
                ($sseq, $t1) = trim_5( $q1_cut - $q1, $qseq, $sseq );
                ($sseq, $t2) = trim_3( $q2 - $q2_cut, $qseq, $sseq );

                $s1t = $s1 + $t1;
                $s2t = $s2 - $t2;
                    
                $sseq =~ s/-+//g;

                if ( length $sseq < $min_q_cov )   {
                    $status = 'tiny coverage'
                } else {
                    $sdef .= " ($s1t-$s2t/$slen)" if !$keep_def && ($s1t > 1 || $s2t < $slen );
                    push @trimmed, [ $sid, $sdef, $sseq ];
                    $status = 'included';
                }
            }

            my $frac_id  = sprintf("%.3f", $nid/$nmat);
            my $frac_pos = sprintf("%.3f", $npos/$nmat);

            $report{ $sid } = [ $sid, $scr, $exp, $slen, $status, $nid/$nmat, $npos/$nmat, $q1-1, $qlen-$q2, $s1-1, $slen-$s2 ];

        } else {    $status = 'multiple hsps' }
    }

    wantarray ? ( \@trimmed, \%report ) : \@trimmed;
}

sub trim_5 {
    my ( $ntrim, $qseq, $sseq ) = @_;
    return $sseq if $ntrim <= 0;
    my ( $to_trim ) = $qseq =~ /^(([^-]-*){$ntrim})/;
    my $trimmed = substr( $sseq, length($to_trim) );
    wantarray ? ( $trimmed, length($to_trim) ) : $trimmed;
}


sub trim_3 {
    my ( $ntrim, $qseq, $sseq ) = @_;
    return $sseq if $ntrim <= 0;
    my ( $to_trim ) = $qseq =~ /((-*[^-]){$ntrim})$/;
    my $trimmed = substr( $sseq, 0, length($sseq) - length($to_trim) );
    wantarray ? ( $trimmed, length($to_trim) ) : $trimmed;
}

#-------------------------------------------------------------------------------
#
#  Allow fragmentary matches inside of the highest-scoring hsp:
#
#-------------------------------------------------------------------------------

sub one_real_hsp {
    my ( $hsps ) = @_;
    return 0 if ! ( $hsps && ( ref( $hsps ) eq 'ARRAY' ) && @$hsps );
    return 1 if  @$hsps == 1;

    my ( $q1_0, $q2_0 ) = ( @{ $hsps->[0] } )[9, 10];
    for ( my $i = 1; $i < @$hsps; $i++ )
    {
        my ($q1, $q2) = ( @{ $hsps->[$i] } )[9, 10];
        return 0 if $q1 < $q1_0 || $q2 > $q2_0;
    }

    return 1;
}

#-------------------------------------------------------------------------------
#
#  Calculate the best cutoff from an array of uncov numbers:
#     
#    1. Sort the uncov numbers
#    2. Use a sliding window to count the instances of uncovs in a specified range
#    3. Look for the first significant peak of uncovs from the highest uncov
#
#-------------------------------------------------------------------------------

sub calc_uncov_cut {
    my ($uncovs, $thresh, $winsize) = @_;
    return undef unless $uncovs && ref $uncovs eq 'ARRAY' && @$uncovs;

    my @uncov = sort { $a->[0] <=> $b->[0] } @$uncovs;
    return $uncov[0]->[0] if $uncov[0]->[0] == $uncov[-1]->[0];

    $thresh  ||= 0.10;
    $winsize ||= 10;

    my $min_count = int($thresh * @uncov) + 1;
    my $imax = $uncov[-1]->[0];

    my $j1 = @uncov - 1;
    my $j2 = @uncov - 1;
    my $cnt = 0;
    my $max_cnt = 0;      # maximum seqs in uncov window range
    my $i_of_max_cnt;     # center of moving window

    for (my $i = $imax; $j2 >= 0 && $i >= 0; $i--) {
        while ($j1 >= 0 && $uncov[$j1]->[0] >= $i - $winsize) {
            $cnt++;
            $j1--;
        }
        while ($j2 >= 0 && $uncov[$j2]->[0] > $i + $winsize) {
            $cnt--;
            $j2--;
        }
        if ($cnt > $max_cnt) {
            $max_cnt = $cnt;
            $i_of_max_cnt = $i;
        }
        last if ($cnt < $max_cnt && $max_cnt >= $min_count);   # just past peak
    }
    if ($max_cnt >= $min_count) {
        return ($i_of_max_cnt > $winsize) ? $i_of_max_cnt - $winsize : 0;
    }    

    return calc_uncov_cut($uncovs, $thresh, max($winsize+1, int($winsize*1.43))); 
}

sub print_string {
    my ( $fh, $close, $unused ) = gjoseqlib::output_filehandle( shift ); 
    ( unshift @_, $unused ) if $unused;                       # modeled after gjoseqlib::print_alignment_as_fasta

    my $str = shift;
    return unless $str;
    
    print $fh $str;
    close $fh if $close;
}



#-------------------------------------------------------------------------------
#
#     $tree            = make_tree( \@ali, \%opts )
#   ( $tree, \%stats ) = make_tree( \@ali, \%opts )
#     $tree            = make_tree( \%opts )           # \@ali = $opts{ali}
#   ( $tree, \%stats ) = make_tree( \%opts )           # \@ali = $opts{ali}
#
#  Options:
#
#     bootstrap  => n                     # bootstrap samples (D = 0) 
#     tool       => program               # fasttree (d), phyml, raxml
#
#     params     => parameter string for tree tool
#                   (can be superseded by the following common options)
#
#     search     => topolog_search_method # NNI (d), SPR
#     model      => substitution_model    # nt: HKY85, JC69, K80, F81, F84, TN93
#                                         # aa: LG, JTT, WAG, MtREV, Dayhoff, DCMut
#     rate       => rate_distribution     # Gamma (d), Uniform 
#     nclasses   => num_subst_categories  # 4 (d)
#     optimize   => all (d, topology && brlen && parameters), eval (optimize model parameters only)
#     input      => input tree            # tree file name
#     nproc      => number of processors to use for bootstrap 
#     
#     Option default values depend the tool used. See details in:
#       ffxtree:: tree_with_fasttree, tree_with_phyml, tree_with_raxml
#
#-------------------------------------------------------------------------------

sub make_tree {
    my ($ali, $opts) = ffxtree::process_input_args_w_ali(@_);

    return unless @$ali >= 3;

    my $program;

    $opts->{tool} ||= 'fasttree';

    if    ($opts->{tool} =~ /fasttree/i) { $program = \&ffxtree::tree_with_fasttree;  $opts->{fasttree} = "/home/fangfang/bin/fasttree" }
    elsif ($opts->{tool} =~ /phyml/i)    { $program = \&ffxtree::tree_with_phyml;     $opts->{phyml}    = "/home/fangfang/bin/phyml" }
    elsif ($opts->{tool} =~ /raxml/i)    { $program = \&ffxtree::tree_with_raxml;     $opts->{raxml}    = "/home/fangfang/bin/raxmlHPC" }

    my $nb = $opts->{bootstrap};
    my $np = $opts->{nproc};
    my $in = $opts->{input};

    my ($tree, $stats);

    if ($nb > 0 && $in) {
        $tree = $in;
    } else {
        ($tree, $stats) = $program->($ali, $opts);
    }
    
    if ($nb > 0) {
        my @samples = map { my $a = gjoalignment::bootstrap_sample($ali); $a } 1..$nb;
        my @trees;

        if ($np >= 2) {
            eval {require Proc::ParallelLoop};
            my $tmpdir = SeedAware::location_of_tmp($opts);
            my @output = map { SeedAware::new_file_name("$tmpdir/tree_pareach_$_", 'newick') } 1..$nb;
            my @tuples; push @tuples, [$samples[$_], $output[$_], $opts] for 0..$nb-1;
            Proc::ParallelLoop::pareach(\@tuples, sub { my ($a, $f, $o) = @{$_[0]}; $o->{treefile} = $f; my $t = $program->($a, $o);}, { Max_Workers => $np });
            @trees = map { gjonewicklib::read_newick_tree($_) } @output;
            unlink $_ for grep { -e $_ } @output;
        } else {
            @trees = map { my $t = $program->($_, $opts); $t } @samples;
        }

        $tree = gjonewicklib::reroot_newick_to_midpoint_w($tree) unless $in;
        $tree = gjophylip::bootstrap_label_nodes($tree, \@trees);
    }

    wantarray() ? ($tree, $stats) : $tree;
}


sub pfam_scan {
    my ($seqs, $opts) = ffxtree::process_input_args_w_ali(@_);

    $seqs = gjoseqlib::pack_sequences($seqs);

    my $ncpu    = $opts->{ncpu} || 2;
    my $scan    = "/home/fangfang/bin/pfam_scan.pl";
    my $pfamdir = "/home/fangfang/Pfam";
    my $tmpdir  = SeedAware::location_of_tmp($opts);
    my $tmpin   = SeedAware::new_file_name("$tmpdir/pfam_input_seqs", 'fa');

    gjoseqlib::print_alignment_as_fasta($tmpin, $seqs);

    my @lines   = SeedAware::run_gathering_output($scan, '-fasta', $tmpin, '-dir', $pfamdir, '-cpu', $ncpu);
    
    my %pfam;
    for (@lines) {
        next if /^#/ || /^\s/;
        my ($id, $fam) = @{[split(/\s+/)]}[0,6];
        if ($pfam{$id}) {
            push @{$pfam{$id}}, $fam;
        } else {
            $pfam{$id} = [$fam];
        }
    }

    [ map { $pfam{$_} ? [ $_, $pfam{$_} ] : () } map { $_->[0] } @$seqs ];
}

sub print_pfam {
    my ($pfam) = @_;

    # print STDERR '$pfam = '. Dumper($pfam);
    
    my @lines = map { $_->[0] ."\t". join(" ", @{$_->[1]} ) } @$pfam;

    print join("\n", @lines). "\n";
    # wantarray ? @lines : join("\n", @lines). "\n";
}



#-------------------------------------------------------------------------------
#
#  Obsolete routines
#
#-------------------------------------------------------------------------------

sub psiblast_search_old {
    my ($profile, $opts) = @_;

    my $min_ident     = $opts->{ min_ident }    ||  0.15;
    $opts->{ e_value } ||= $opts->{ max_e_val } ||= 0.01;

    # print STDERR Dumper($opts);

    my $dir = "/home/fangfang/WB/tmpsvr";
    my $logdir = "$dir/logs";

    my $complete = "/home/fangfang/WB/svr_complete.fasta";       # db      (fasta or gjo seqs)

    my %trimmedH;
    my %rejectedH;

    my $i      = 1;
    my $suffix = -s "$dir/trim2-$i" ? "-$i" : "";
    my $fprof  = "$dir/trim2$suffix";


    # print "Running psiblast, querying trim2$suffix against complete genomes...\n";

    my $blast = gjoalignandtree::blastpgp($complete, $profile, { max_exp => $opts->{e_value}, stderr => "$logdir/psiblast2$suffix.stderr" });
    my($qid, $qdef, $qlen, $qhits) = @$blast;
    my @trimmed;

    open  PSI, ">$logdir/psiblast2$suffix.dump" or die "could not open psiblast2$suffix.dump\n";
    print PSI Dumper($blast);
    close PSI;

    my $rej = "$dir/psiblast2$suffix.rejects";
    open REJ, ">$rej" or die "Could not open $rej";

    my @scores;

    my $max_uncov = 20;
    my $max_s_uncov = min($qlen*5, 500);
    foreach my $sdata (@$qhits) {
        my($sid, $sdef, $slen, $hsps) = @$sdata;
        my $explanation;

        # if (@$hsps == 1) 
        if ( one_real_hsp($hsps) ) {
            # [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
            #     0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
            my($scr, $nmat, $nid, $q1, $q2, $qseq, $s1, $s2, $sseq) = (@{$hsps->[0]})[0, 4, 5, 9, 10, 11, 12, 13, 14];

            if (($q1-1) + ($qlen-$q2) > 2 * $max_uncov) {
                $explanation = [ $sid, "short coverage", $q1, $qlen-$q2, $s1, $slen-$s2 ];
            } elsif ($s1-1 + $slen-$s2 > $max_s_uncov) {
                $explanation = [ $sid, "long subject", $q1, $qlen-$q2, $s1, $slen-$s2 ];
            } elsif ($nid / $nmat < $min_ident) {
                $explanation = [ $sid, "low identity", $nid / $nmat ];
            } else {
                $sseq =~ s/-+//g;
                my $entry = [$sid, $sdef, $sseq];
                push(@trimmed, $entry);
                $trimmedH{$sid} = [$entry, $scr] unless $trimmedH{$sid} && $trimmedH{$sid}->[1] >= $scr;
            }
        } else {
            $explanation = [ $sid, "multiple hsps" ];
        }
        if ($explanation) {
            print REJ join("\t", @$explanation)."\n";
            $rejectedH{$sid} ||= $explanation;
        }
    }
    close REJ;
    # &gjoseqlib::print_alignment_as_fasta("$dir/trim2$suffix-complete", \@trimmed);    
    # printf "trim2$suffix-complete contains %d sequences\n", &num_seqs_in_fasta("$dir/trim2$suffix-complete");

    return \@trimmed;

}

sub trim_alignment_old {
    my ($ali, $opts) = @_;
    my $rv;

    my $profile;

    # my $dir = SeedAware::location_of_tmp( $opts );
    my $dir = "/home/fangfang/WB/tmpsvr";

    my $logdir = "$dir/logs";
    &SeedUtils::verify_dir($logdir);

    my $trim1 = gjoalignandtree::trim_align_to_median_ends($ali, { begin => 1, end => 1 });
    my $reps = [@$trim1];

    my (@trims, %rejectH, %successH);

    my $i    = 0;
    my $nseq = @$trim1;

    while (@$trim1 >= 0.1 * $nseq && ($i == 0 || @$trim1 >= 2)) {
        $i++;
        my $suffix = $i > 1 ? "-$i" : "";

        # print "Running psiblast, querying trim1 [$i] against reps-0.8...\n";

        my $blast = gjoalignandtree::blastpgp($reps, $trim1, { stderr => "$logdir/psiblast1.stderr$suffix" });
        open  PSI, ">$logdir/psiblast1.dump$suffix" or die "could not open psiblast1.dump$suffix\n";
        print PSI Dumper($blast);
        close PSI;

        my $opts = {};
        my ( $trimmed, $reject, $scoreH ) = process_psiblast1( $blast, $opts );
        
        push @trims, [ $_->[0], $_, $scoreH->{$_->[0]}, $i ] for @$trimmed;
        $successH{$_->[0]} = 1 for @$trimmed;
        push @{$rejectH{$_->[0]}}, $_ for @$reject;
               
        my $rej = "$dir/psiblast1.rejects$suffix";
        open REJ, ">", $rej or die "Could not open $rej";
        foreach ( @$reject ) {
            print REJ join( "\t", @$_ ), "\n";
            # print "REJ\t", join( "\t", @$_ ), "\n";
        }
        close REJ;

        # foreach (@$trimmed) {
            # print "GOOD\t", join("\t", $_->[0], $_->[2])."\n";
        # }
        # print "\n";

        &gjoseqlib::print_alignment_as_fasta("$dir/trim1-reps-0.8$suffix", $trimmed);    
        # printf "trim1-reps-0.8$suffix contains %d sequences\n", scalar@$trimmed;
        $profile = [@$trimmed];

        my $ntrim1 = @$trim1;

        # take only the rejected seqs marked as multiple hsps
        my %multiple = map { $_->[0] => 1 } grep { $_->[1] =~ /multiple/i } @$reject;
        @$trim1 = grep { $multiple{$_->[0]} } @$trim1;

        # previous (wrong): take all the rejected seqs
        # @$trim1 = grep { !$successH{$_->[0]} } @$trim1;

        # take all the rejected seqs except tiny ones
        # my %nontiny = map { $_->[0] => 1 } grep { $_->[1] !~ /tiny/i } @$reject;
        # @$trim1 = grep { $nontiny{$_->[0]} } @$trim1;

        last if $ntrim1 == @$trim1;
    }

    if ($i > 1) {
        run("mv $dir/trim1-reps-0.8 $dir/trim1-reps-0.8-1");
        run("mv $dir/psiblast1.rejects $dir/psiblast1.rejects-1");

        my %seen;
        @trims = grep { !$seen{$_->[0]}++ } sort { $b->[2] <=> $a->[2] } @trims;

        my @fhs;
        foreach my $j (1 .. $i) {
            open($fhs[$j], ">$dir/trim1-reps-0.8-$j-ids") or die "Could not open $dir/trim1-reps-0.8-$j-ids";
        }
        foreach my $trm (@trims) {
            my $j = $trm->[3];
            my $fh = $fhs[$j];
            print $fh join("\t", $trm->[0], $trm->[2])."\n";
        }
        close $_ for @fhs[1..$i];

        @trims = map { $_->[1] } @trims;
        &gjoseqlib::print_alignment_as_fasta("$dir/trim1-reps-0.8", \@trims);    
        $profile = [@trims];
        
        printf "After merging, trim1-reps-0.8 contains %d sequences\n", &num_seqs_in_fasta("$dir/trim1-reps-0.8");
        
        my $rej = "$dir/psiblast1.rejects";
        open REJ, ">", $rej or die "Could not open $rej";
        for (grep { @{$rejectH{$_}} == $i } keys %rejectH) {
            print REJ map { join("\t", @$_), "\n" } @{$rejectH{$_}};
        }
        close REJ;
    }

    # my $profile1 = &gjoseqlib::read_fasta("$dir/trim1-reps-0.8");
    my $profile1 = $profile;
    my $align2 = &gjoalignment::align_with_mafft($profile1);
    my $trim2 = &gjoalignandtree::trim_align_to_median_ends($align2, { begin  => 1, end => 1 } );

    return $trim2;
}


sub process_psiblast1 {
    my ( $blast, $opts ) = @_;

    $blast && ref $blast eq 'ARRAY' or return ();
    $opts  && ref $opts  eq 'HASH'  or $opts = {};

    my( $qid, $qdef, $qlen, $qhits ) = @$blast;

    my $fract_ends = $opts->{ fract_ends } || $opts->{ fraction_ends } || 0.1;  # fraction of sequences ending in window
    my $max_uncov  = $opts->{ max_uncov }  || $opts->{ max_uncovered } || 20 > $qlen/3 ? ($qlen/3 + 1) : 20;
    my $min_cov    = $opts->{ min_cov }    || $opts->{ min_nongaps }   || 10 < $qlen/5 ? ($qlen/5 + 1) : 10;
    my $win_size   = $opts->{ win_size }   || $opts->{ window_size }   || 10;

    # print "max_uncovered = $max_uncov\n";

    my @uncov1;
    my @uncov2;
    foreach my $sdata ( @$qhits )
    {
        my( $sid, $sdef, $slen, $hsps ) = @$sdata;
        # if ( @$hsps == 1 )
        if ( one_real_hsp($hsps) )
        {
#            [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#               0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
            my( $q1, $q2, $s1, $s2 ) = ( @{ $hsps->[0] } )[9, 10, 12, 13];
            push @uncov1, [ $q1-1,     $s1-1     ];
            push @uncov2, [ $qlen-$q2, $slen-$s2 ];
        }
    }

    my $q1_cut = calc_uncov_cut(\@uncov1, $fract_ends, $win_size) + 1;
    my $q2_cut = $qlen - calc_uncov_cut(\@uncov2, $fract_ends, $win_size);

    # print $qlen - $q2_cut, "\n";
    # print "q1_cut  = $q1_cut   q2_cut = $q2_cut   qlen = $qlen\n";

    my @trimmed;
    my @rejected;
    my %scoreH;
    foreach my $sdata ( @$qhits ) {
        my( $sid, $sdef, $slen, $hsps ) = @$sdata;
        # if ( @$hsps == 1 )
        if ( one_real_hsp($hsps) ) {
            my( $scr, $q1, $q2, $qseq, $s1, $s2, $sseq ) = ( @{ $hsps->[0] } )[ 0, 9 .. 14 ];
            my $uncov1 = $q1 <= $q1_cut ? 0 : $q1 - $q1_cut;
            my $uncov2 = $q2 >= $q2_cut ? 0 : $q2_cut - $q2;
            if ( $uncov1 <= $max_uncov  && $uncov2 <= $max_uncov ) {
                $sseq = trim_5( $q1_cut - $q1, $qseq, $sseq );
                $sseq = trim_3( $q2 - $q2_cut, $qseq, $sseq );
                $sseq =~ s/-+//g;
                if ( length($sseq) >= $min_cov ) {
                    push @trimmed, [ $sid, $sdef, $sseq ];
                    $scoreH{$sid} = $scr;
                } else {
                    push @rejected, [ $sid, 'tiny coverage', $uncov1, $uncov2, $s1-1, $slen-$s2, length($sseq) ];
                }
            } else {
                push @rejected, [ $sid, 'short coverage', $uncov1, $uncov2, $s1-1, $slen-$s2 ];
            }
        } else {
            push @rejected, [ $sid, 'multiple hsps' ];
        }
    }
    return wantarray ? ( \@trimmed, \@rejected, \%scoreH ) : \@trimmed;
}


1;
