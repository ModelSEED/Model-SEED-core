package representative_sequences;

#
# This is a SAS component
#
use strict;
use gjoparseblast;
use gjoseqlib;
use SeedAware;
use Data::Dumper;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( representative_sequences
                  rep_seq_2
                  rep_seq
                  n_rep_seqs
                );


#===============================================================================
#  Build or add to a set of representative sequences (if you do not want an
#  enrichment of sequences around a focus sequence (called the reference), this
#  is probably the subroutine that you want).
#
#    \@reps = rep_seq( \@reps, \@new, \%options );
#    \@reps = rep_seq(         \@new, \%options );
#
#  or
#
#    ( \@reps, \%representing ) = rep_seq( \@reps, \@new, \%options );
#    ( \@reps, \%representing ) = rep_seq(         \@new, \%options );
#
#  or
#
#    \@reps = rep_seq_2( \@reps, \@new, \%options );
#    \@reps = rep_seq_2(         \@new, \%options );
#
#  or
#
#    ( \@reps, \%representing ) = rep_seq_2( \@reps, \@new, \%options );
#    ( \@reps, \%representing ) = rep_seq_2(         \@new, \%options );
#
#  Construct a representative set of related sequences:
#
#    \@repseqs = representative_sequences( $ref, \@seqs, $max_sim, \%options );
#
#  or
#
#    ( \@repseqs, \%representing, \@low_sim ) = representative_sequences( $ref,
#                                                 \@seqs, $max_sim, \%options );
#
#  Output:
#
#    \@repseqs  Reference to the list of retained (representative subset)
#               of sequence entries.  Sequence entries have the form
#               [ $id, $def, $seq ]
#
#    \%representing
#               Reference to a hash in which the keys are the ids of the
#               representative sequences, for which the corresponding value
#               is a list of ids of other sequences that are represented by
#               that representive.
#
#
#  Arguments (only \@seqs is required):
#
#    $ref       A reference sequence as [ $id, $def, $seq ].  If present, the
#               reference sequence defines a focal point for the analysis.  A
#               representative sequence from each lineage in its vicinity will
#               be retained, even though they are more similar than max_sim to
#               the reference, or to each other.  The reference will always be
#               included in the representative set.  A limit is put on the
#               similarity of lineages retained by the reference sequence with
#               the max_ref_sim option (default = 0.99).  The reference sequence
#               should not be repeated in the set of other sequences.  (Only
#               applies to representative_sequences; there is no equivalent for
#               rep_seq_2.)
#
#    \@reps     In rep_seq_2, these sequences will each be placed in their own
#               cluster, regardless of their similarity to one another.  Each
#               remaining sequence is added to the cluster to which it is
#               most similar, unless it is less simililar than max_sim, in
#               which case it represents a new cluster.
#
#    \@seqs     Set of sequences to be pruned.  If there is no reference
#               sequence, the fist sequence in this list will be the starting
#               point for the analysis and will be retained, but all sequences
#               more similar than max_sim to it will be removed (in contrast to
#               a reference sequence, which retains a representative of each
#               lineage in its vicinity).  Sequences that fail the E-value test
#               relative to the reference (or the fist sequence if there is no
#               reference) are dropped.
#
#    $max_sim   (representative_sequences only; an option for rep_seq_2)
#               Sequences with a higher similarity than max_sim to an existing
#               representative sequence will not be included in the @reps
#               output.  Their ids are associated with the identifier of the
#               sequence representing them in \%representing.  The details of
#               the behaviour are modified by other options. (default = 0.80)
#
#    \%options  Key => Value pairs that modify the behaviour:
#
#        by_size    (rep_seq and rep_seq_2 only)
#                   By default, sequences are analyzed in input order.  This
#                   option set to true will sort from longest to shortest.
#
#        logfile    Filehandle for a logfile of the progress.  As each
#                   sequence is analyzed, its disposition in recorded.
#                   In representative_sequences(), the id of each new
#                   representative is followed by a tab separated list of the
#                   ids that it represents.  In rep_seq_2(), as each sequence
#                   is analyzed, it is recorded, followed by the id of the
#                   sequence representing it, if it is not the first member
#                   of a new cluster.  Autoflush is set for the logfile.
#                   If the value supplied is not a reference to a GLOB, then
#                   the log is sent to STDOUT (which is probably not what you
#                   want in most cases).  The behavior is intended to aid in
#                   following prgress, and in recovery of interupted runs.
#
#        max_ref_sim (representative_sequences only)
#                   Maximum similarity of any sequence to the reference.  If
#                   max_ref_sim is less than max_sim, it is silently reset to
#                   max_sim.  (default = 0.99, because 1.0 can be annoying)
#
#        max_e_val  Maximum E-value for blastall.  Probably moot, but will help
#                   with performance.  (default = 0.01)
#
#        max_sim    Sequences with a higher similarity than max_sim to a
#                   retained sequence will be deleted.  The details of the
#                   behaviour is modified by other options. (default = 0.80)
#                   (a parameter for representative_sequences, but an option
#                   for rep_seq_2).
#
#        n_query    (rep_seq and rep_seq_2 only)
#                   Blast serveral sequences at a time to decrease process
#                   creation overhead.  (default = 1)
#
#        rep_seq_2  (rep_seq only)
#                   Use rep_seq_2() behavior (only on representative in the
#                   blast database per cluster.
#
#        save_tmp   Do not delete temporary files upon completion (for debug)
#
#        sim_meas   Measure similarity for inclusion or exclusion by
#                  'identity_fraction' (default), 'positive_fraction', or
#                  'score_per_position'
#
#        save_exp   (representative_sequences only)
#                   When there is a reference sequence, lineages more similar
#                   than max_sim will be retained near the reference.  The
#                   default goal is to save one member of each lineage.  If
#                   the initial representative of the lineage is seq1, we
#                   pose the question, "Are there sufficiently deep divisions
#                   within the lineage to seq1 that it they might be viewed
#                   as independent?  That is, might there be another sequence,
#                   seq2 that so different from seq1 that we might want to see
#                   it also?
#
#                                +---------------------- ref
#                                |
#                             ---+ +-------------------- seq1
#                                +-+
#                                  +-------------------- seq2
#
#                   Without any special treatment, if the similarity of seq1
#                   to ref ( S(seq1,ref) ) is greater than max_sim, seq1 would
#                   be the sole representative of thelineage containing both
#                   seq1 and seq2, because the similarity of seq1 to seq2
#                   ( S(seq1,seq2) ) is greater than S(seq1,ref).  This can
#                   be altered by the value of save_exp.  In terms of
#                   similarity, seq2 will be discarded if:
#
#                       S(seq1,seq2) > S(seq1,ref) ** save_exp, and
#                       S(seq1,seq2) > S(seq2,ref) ** save_exp
#
#                   The default behavior described above occurs when save_exp
#                   is 1.  If save_exp < 1, then greater similarities between
#                   seq1 and seq2 are allowed.  Reasonable values of save_exp
#                   are roughly 0.7 to 1.0.  (At save_exp = 0, any similarity
#                   would be allowed; yuck.)
#
#        stable     (representative_sequences only; always true for rep_seq_2)
#                   If true (not undef, '', or 0), then the representatives
#                   will be chosen from as early in the list as possible (this
#                   facilitates augmentation of an existing list).
#
#        tmp        Location for temporary blast files.
#
#-------------------------------------------------------------------------------
#
#  Diagram of the pruning behavior of representative_sequences():
#
#  0.5       0.6       0.7       0.8       0.9       1.0   Similarity
#   |---------|---------|---------|---------|---------|
#                       .
#                       .                            +  A
#                       .                        +---+
#                       .                        |   +  B
#                       .                    +---+
#                       .                    |   +----  C
#                       .         +----------+
#                       .         |          +--------  D
#                       .         |
#                     +-----------+ +-----------------  E
#                     | .         +-+
#                     | .           +-----------------  F
#    +----------------+ .
#    |                | . +---------------------------  G
#    |                +---+
#    |                  . |     +---------------------  H
#  --+                  . +-----+
#    |                  .       +---------------------  I
#    |                  .
#    |                +-------------------------------  J
#    +----------------+ .
#                     | . +---------------------------  K
#                     +---+
#                       . +---------------------------  L
#                       .
#   |---------|---------|---------|---------|---------|
#  0.5       0.6       0.7       0.8       0.9       1.0   Similarity
#
#  In the above tree and max_sim = 0.70 and max_ref_sim = 0.99:
#
#      With no reference sequence, and A first in the list, the representative
#      sequences will be A, G, J and K.
#
#      With A as the reference sequence and save_exp left at its default, the
#      representative sequences will be A, C, D, E, G, J and K.  B is excluded
#      because it is more similar than max_ref_sim to A.
#
#      With A as the reference sequence and save_exp = 0.8, the representative
#      sequences will be A, C, D, E, F (comparably similar to A and E), G,
#      H (comparably similar to A and G), J and K.  The sequence L will be
#      represented by K because L is much closer to K than to A.
#
#  This oversimplifies the choice of representative of a cluster of related
#  sequences.  For example, whether G, H or I would represent the group of
#  three actually depends on relative clock speed (slower is better) and
#  sequence coverage (more complete is better).  The actual order is by BLAST
#  bit score (possibly combining independent segments).
#
#  In addition, this discussion is in terms of a tree, but the calculations
#  are based on a (partial) set of pairwise sequence similarities.  Thus, the
#  precise behavior is hard to predict, but should be similar to that described
#  above.
#
#-------------------------------------------------------------------------------
#
#  To construct a representative set of sequences relative to a reference
#  sequence:
#
#    1. Prioritize sequences for keeping, from highest to lowest scoring
#             relative to reference, as measured by blast score (bits).
#             When stable is set, priority is from first to last in input file
#             (a reference sequence should not be supplied).
#
#    2. Based on the similarity of each sequence to the reference and save_exp,
#             compute sequence-specific values of max_sim:
#
#         max_sim( seq_i ) = exp( save_exp * ln( seq_i_ref_sim ) )
#
#    3. Examine the next prioritized sequence (seq1).
#
#    4. If seq1 has been vetoed, go to 7.
#
#    5. Mark seq1 to keep.
#
#    6. Use blast to find similarities of seq1 to other sequences.
#
#    7. For each similar sequence (seq2):
#
#        7a. Skip if seq2 is marked to keep, or marked for veto
#
#        7b. Compute the maximum simiarity of seq1 and seq2 for retaining seq2:
#
#            max_sim_1_2 = max( max_sim, max_sim( seq1 ), max_sim( seq2 ) )
#
#        7c. If similarity of seq1 and seq2 > max_sim, veto seq2
#
#        7d. Next seq2
#
#    8. If there are more sequences to examine, go to 3.
#
#    9. Collect the sequences marked for keeping.
#
#===============================================================================

#===============================================================================
#  Build or add to a set of representative sequences.  The difference of
#  rep_seq_2 and rep_seq is that rep_seq can have multiple representatives
#  in the blast database for a given group.  This helps prevent fragmentation
#  of clusters.
#
#    \@reps = rep_seq( \@reps, \@new, \%options );
#    \@reps = rep_seq(         \@new, \%options );
#
#  or
#
#    ( \@reps, \%representing ) = rep_seq( \@reps, \@new, \%options );
#    ( \@reps, \%representing ) = rep_seq(         \@new, \%options );
#
#  January 28, 2011:
#
#  rep_seq_2() is now implimented by the option: rep_seq_2 => 1
#
#  The code now allows batching of multiple blast queries to see if that
#  helps cut down on process creation overhead:  n_query => n (D = 64)
#
#===============================================================================

sub rep_seq
{
    # Are there options?

    my $options = ( $_[-1] && ref $_[-1] eq 'HASH' ) ? pop @_ : {};

    my ( $reps, $seqs ) = @_ < 2 ? ( [], shift ) : @_;

    $reps && ref $reps eq 'ARRAY'
        or print STDERR "Representative sequences for rep_seq() must be an ARRAY reference.\n"
            and return undef;
    
    $seqs && ref $seqs eq 'ARRAY'
        or print STDERR "Sequences for rep_seq() must be an ARRAY reference.\n"
            and return undef;

    # ---------------------------------------# Default values for options

    my $n_query   = 64;                    # Blast sequences one-by-one
    my $by_size   = undef;                 # Analyze sequences in order provided
    my $max_sim   = 0.80;                  # Retain 80% identity of less
    my $logfile   = undef;                 # Log file of sequences processed
    my $max_e_val = 0.01;                  # Blast E-value to decrease output
    my $sim_meas  = 'identity_fraction';   # Use sequence identity as measure
    my $keep_id   = [];
    my $keep_gid  = [];
    my $rep_seq_2 = 0;                     # Not call to rep_seq_2;

    #  Two questionable decisions:
    #     1. Be painfully flexible on option names.
    #     2. Silently fix bad parameter values.

    foreach ( keys %$options )
    {
        my $value = $options->{ $_ };

        if    ( m/by_?size/i )              #  add longest to shortest
        {
            $by_size = 1;
        }
        elsif ( m/keep_?gid/i )
        {
            $keep_gid = $value if $value && ref( $value ) eq 'ARRAY';
        }
        elsif ( m/keep_?id/i )
        {
            $keep_id = $value  if $value && ref( $value ) eq 'ARRAY';
        }
        elsif ( m/^log/i )                  #  logfile
        {
            next if ! $value;
            $logfile = ( ref $value eq "GLOB" ? $value : \*STDOUT );
            select( ( select( $logfile ), $| = 1 )[0] );  #  autoflush on
        }
        elsif ( m/max/i && m/sim/i )        #  max(imum)_sim(ilarity)
        {
            $value += 0;
            $value  = 0 if $value < 0;
            $value  = 1 if $value > 1; 
            $max_sim = $value;
        }
        elsif ( m/max/i || m/[ep]_?val/i )  #  Other "max" tests must come first
        {
            $value += 0;
            $value  = 0 if $value < 0;
            $max_e_val = $value;
        }
        elsif ( m/n_?quer/i )
        {
            $n_query = $value || 1;
        }
        elsif ( m/^rep_seq_2$/ )            #  rep_seq_2 behavior
        {
            $rep_seq_2 = $value;
        }
        elsif ( m/sim/i || m/meas/i )       #  sim(ilarity)_meas(ure)
        {
            $sim_meas = standardize_similarity_measure( $value );
        }
        elsif ( m/save_?te?mp/i )           #  group temporary files
        {
            $options->{ savetmp } = 1;
        }
        else
        {
            # print STDERR "WARNING: rep_seq bad option ignored: '$_' => '$value'\n";
        }
    }

    #  Check sequence ids for duplicates:

    my $reps2 = [];
    my $seen  = {};

    foreach ( @$reps )
    {
        my $id = $_->[0];
        if ( $seen->{ $id }++ )
        {
            print STDERR "Duplicate sequence id '$id' skipped by rep_seq\n";
        }
        else
        {
            push @$reps2, $_;
        }
    }

    my %keep_gid_hash = map { $_ => 1 } @$keep_gid;
    my %keep_id_hash  = map { $_ => 1 } @$keep_id;

    #  Filter sequences to be added;

    my $seqs2 = [];
    foreach ( @$seqs )
    {
        my $id = $_->[0];
        if ( $seen->{ $id }++ )
        {
            print STDERR "Duplicate sequence id '$id' skipped by rep_seq\n";
        }
        elsif ( $keep_id_hash{ $id } || ( $id =~ /^(fig\|\d+\.\d+)\./ && $keep_gid_hash{ $1 } ) )
        {
            push @$reps2, [ @$_ ];
            $seen->{ $id }++
        } 
        else 
        {
            push @$seqs2, [ @$_ ];
        }
    }

    #
    #  Do the analysis.
    #
    #  Begin by eliminating indels from the input sequences
    #
    $reps2 = &gjoseqlib::pack_sequences( $reps2 ) || $reps2;
    $seqs2 = &gjoseqlib::pack_sequences( $seqs2 ) || $seqs2;

    if ( $by_size )
    {
        @$seqs2 = sort { length( $b->[2] ) <=> length( $a->[2] ) } @$seqs2;
    }

    #  If no preexisting representatives, then take first sequence:

    ( $reps2 && @$reps2 ) or ( @$reps2 = ( shift @$seqs2 ) );

    if ( $logfile ) { foreach ( @$reps2 ) { print $logfile "$_->[0]\n" } }

    #  Search each rep sequence against itself to get max_bpp

    my $tmp_dir = &SeedAware::location_of_tmp( $options );
    $tmp_dir or print STDERR "Unable to locate temporary file directory.\n"
             and return;

    my $db = SeedAware::new_file_name( "$tmp_dir/tmp_blast_db" );
    my $protein = are_protein( $reps2 );

    my %max_bpp;   # Used in evaluating bit per position score
    if ( $sim_meas =~ /^sc/ )
    {
        foreach my $entry ( @$reps2 )
        {
            $max_bpp{ $entry->[0] } = self_bpp( $db, $entry, $protein, $options );
        }
    }

    my $naln = $n_query + 9;   # Alignments to make
    my $self = 0;              # Self match is never wanted
    my $prog = $protein ? 'blastp' : 'blastn';
    my $blast_opt = [ -e => $max_e_val,
                      -v => $naln,
                      -b => $naln,
                      -F => 'F',
                      -a =>  2
                    ];
    push @$blast_opt, qw( -r 1 -q -1 ) if ! $protein;

    #  List of whom is represented by a sequence:

    my %group = map { $_->[0] => [] } @$reps2;

    #  Groups can have more than one representative in the blast database:

    my $rep4blast = [ @$reps2 ];                        # initial reps
    my %group_id  = map { $_->[0] => $_->[0] } @$reps2; # represent self

    #  When we add multiple sequences to blast db at of time, we need to
    #  know which are really in there as reps of groups.

    my %match_ok = map { $_->[0] => 1 } @$reps2;        # hash of blast reps

    #  Search each sequence against the database.

    my ( $bpp_max, $sid, $gid );
    my $newdb = 1;

    while ( @$seqs2 )
    {
        $n_query = @$seqs2 if @$seqs2 < $n_query;  #  Number to blast
        my @queries = splice @$seqs2, 0, $n_query;

        #  Is it time to rebuild a BLAST database?

        if ( $newdb || $n_query > 1 )
        {
            my $last = pop @queries;
            make_blast_db( $db, [ @$rep4blast, @queries ], $protein );
            push @queries, $last;
            $newdb = 0  if $n_query == 1;
        }

        #  Do the blast analysis.  Returned records are of the form:
        #
        #        0    1     2     3    4     5     6     7      8     9     10     11
        #     [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ]
        #
        #  $tophit = [ $score, $blast_record, $surething ]

        my @results = top_blast_per_subject_2( $prog, $db, \@queries, $self, $blast_opt, $options );

        foreach my $result ( @results )
        {
            my ( $qid, $hits ) = @$result;

            my ( $tophit ) = sort { $b->[0] <=> $a->[0] }
                             map  { in_group( $_, $max_sim, $sim_meas, $max_bpp{ $_->[3] } ) }
                             grep { $match_ok{ $_->[3] } }
                             @$hits;

            my $entry = shift @queries;

            # It matches an existing representative

            if ( $tophit )
            {
                $sid = $tophit->[1]->[3];        # id of the best matching sequence
                $gid = $group_id{ $sid };        # look up representative for group
                push @{ $group{ $gid } }, $qid;  # add sequence to list in group
                $group_id{ $qid } = $gid;        # record group for id
                print $logfile "$qid\t$gid\n" if $logfile;

                # Add sequence to blast database if it is not a 'surething'

                if ( ! $tophit->[2] && ! $rep_seq_2 )
                {
                    push @$rep4blast, $entry;
                    $match_ok{ $qid } = 1;
                    $max_bpp{ $qid } = self_bpp( $db, $entry, $protein, $options ) if $sim_meas =~ /^sc/;
                    $newdb = 1;
                }
            }

            # It is a new representative

            else
            {
                push @$reps2, $entry;
                push @$rep4blast, $entry;
                $match_ok{ $qid } = 1;
                $group{ $qid } = [];
                $group_id{ $qid } = $qid;   #  represent self
                $max_bpp{ $qid } = self_bpp( $db, $entry, $protein, $options ) if $sim_meas =~ /^sc/;
                $newdb = 1;
                print $logfile "$qid\n" if $logfile;
            }
        }
    }

    if ( $protein ) { unlink $db, "$db.psq", "$db.pin", "$db.phr" }
    else            { unlink $db, "$db.nsq", "$db.nin", "$db.nhr" }

    #  Return the surviving sequence entries, and optionally the hash of
    #  ids represented by each survivor:

    wantarray ? ( $reps2, \%group ) : $reps2;
}


#===============================================================================
#  Caluculate sequence similarity according to the requested measure, and return
#  empty list if lower than max_sim.  Otherwise, return the hit and and
#  whether the hit is really strong:
#
#     [ $score, $hit, $surething ] = in_group( $hit, $max_sim, $measure, $bpp_max )
#     ()                           = in_group( $hit, $max_sim, $measure, $bpp_max )
#
#  $hit is a structure with blast information:
#
#  [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ]
#
#  The surething is the similarity for which $max_sim is 4 standard deviations
#  lower.
#===============================================================================

sub in_group
{
    my ( $hit, $max_sim, $measure, $bpp_max ) = @_;

    my $n = $hit->[8];           # aligned positions
    return () if ( $n <= 0 );

    my $m;                       # matched positions

    if    ( $measure =~ /^sc/ ) { $m = $hit->[ 6] / ( $bpp_max || 2 ) } # score/pos
    elsif ( $measure =~ /^po/ ) { $m = $hit->[10] }  # positives
    else                        { $m = $hit->[ 9] }  # identities

    return () if $m < ( $max_sim * $n );

    my $u      = ( $n > $m ) ? ( $n - $m ) : 0;           #  differing positions
    my $stddev = sqrt( $m * $u / $n );
    my $conf   = 4;                      # standard deviations for "surething"
    $max_sim   = 0.01 if $max_sim < 0.01;
    my $surething = ( $u + $conf * $stddev ) <= ( ( 1 - $max_sim ) * $n ) ? 1 : 0;

    [ $m/$n, $hit, $surething ]
}


#===============================================================================
#  Build or add to a set of representative sequences.
#
#    \@reps = rep_seq_2( \@reps, \@new, \%options );
#    \@reps = rep_seq_2(         \@new, \%options );
#
#  or
#
#    ( \@reps, \%representing ) = rep_seq_2( \@reps, \@new, \%options );
#    ( \@reps, \%representing ) = rep_seq_2(         \@new, \%options );
#
#  Make the behavior of just one representative per group an option of
#  rep_seq(), unifying the codes.
#===============================================================================

sub rep_seq_2
{
    # Are there options?

    my $options = ( $_[-1] && ref $_[-1] eq 'HASH' ) ? pop @_ : {};
    $options->{ rep_seq_2 } = 1;

    rep_seq( @_, $options );
}


#===============================================================================
#  Construct a representative set of related sequences:
#
#    \@repseqs = representative_sequences( $ref, \@seqs, $max_sim, \%options );
#
#  or
#
#    ( \@repseqs, \%representing, \@low_sim ) = representative_sequences( $ref,
#                                                 \@seqs, $max_sim, \%options );
#
#===============================================================================
sub representative_sequences {
    my $seqs = ( shift @_ || shift @_ );  #  If $ref is undef, shift again
    ref( $seqs ) eq "ARRAY"
        or die "representative_sequences called with bad first argument\n";

    my ( $ref, $use_ref );
    if ( ! ref( $seqs->[0] ) )  #  First item was sequence entry, not list of entries
    {
        $ref = $seqs;
        $seqs = shift @_;
        ref( $seqs ) eq "ARRAY"
            and ref( $seqs->[0] ) eq "ARRAY"
            or die "representative_sequences called with bad sequences list\n";
        $use_ref = 1;
    }
    else                        #  First item was list of entries, split off first
    {
        ref( $seqs->[0] ) eq "ARRAY"
            or die "representative_sequences called with bad sequences list\n";
        $ref = shift @$seqs;
        $use_ref = 0;
    }

    my $max_sim = shift @_;
    my $options;

    #  Undocumented feature: skip max_sim (D = 0.8)

    if ( ref( $max_sim ) eq "HASH" )
    {
        $options = $max_sim;
        $max_sim = undef;
    }

    #  If the above did not give us options, get them now:

    $options ||= ( shift @_ ) || {};

    # ---------------------------------------# Default values for options

    $max_sim      ||= 0.80;                  # Retain 80% identity of less
    my $logfile     = undef;                 # Log file of sequences processed
    my $max_ref_sim = 0.99;                  # Get rid of identical sequences
    my $max_e_val   = 0.01;                  # Blast E-value to decrease output
    my $sim_meas    = 'identity_fraction';   # Use sequence identity as measure
    my $save_exp    = 1.0;                   # Don't retain near equivalents
    my $stable      = 0;                     # Pick reps input order

    #  Two questionable decisions:
    #     1. Be painfully flexible on option names.
    #     2. Silently fix bad parameter values.

    foreach ( keys %$options )
    {
        my $value = $options->{ $_ };
        if    ( m/^log/i )                  #  logfile
        {
            next if ! $value;
            $logfile = ( ref $value eq "GLOB" ? $value : \*STDOUT );
            select( ( select( $logfile ), $| = 1 )[0] );  #  autoflush on
        }
        elsif ( m/ref/i )                   #  max_ref_sim
        {
            $value += 0;
            $value  = 0 if $value < 0;
            $value  = 1 if $value > 1; 
            $max_ref_sim = $value;
        }
        elsif ( m/max/i && m/sim/i )        #  max(imum)_sim(ilarity)
        {
            $value += 0;
            $value  = 0 if $value < 0;
            $value  = 1 if $value > 1; 
            $max_sim = $value;
        }
        elsif ( m/max/i || m/[ep]_?val/i )  #  Other "max" tests must come first
        {
            $value += 0;
            $value  = 0 if $value < 0;
            $max_e_val = $value;
        }
        elsif ( m/sim/i || m/meas/i )       #  sim(ilarity)_meas(ure)
        {
            $sim_meas = standardize_similarity_measure( $value );
        }
        elsif ( m/sav/i || m/exp/i )        #  save_exp(onent)
        {
            $value += 0;
            $value  = 0 if $value < 0;
            $value  = 1 if $value > 1; 
            $save_exp = $value;
        }
        elsif ( m/stab/i )                  #  stable order
        {
            $stable = $value ? 1 : 0;
        }
        else
        {
            # print STDERR "WARNING: representative_sequences bad option ignored: '$_' => '$value'\n";
        }
    }

    #  Silent sanity check.  This should not happen, as it is almost equivalent
    #  to making no reference sequence.

    $max_ref_sim = $max_sim if ( $max_ref_sim < $max_sim );

    #  Do the analysis
    #  Begin by eliminating indels from the input sequences
    #
    ($ref) = &gjoseqlib::pack_sequences($ref);
    $seqs  = &gjoseqlib::pack_sequences($seqs);

    my $ref_id  = $ref->[0];

    #  Build a list of the ids (without ref) and an index for the sequence entries:

    my @seq_id = map { $_->[0] } @$seqs;
    my $seq_ind = { map { @{$_}[0] => $_ } ( $ref, @$seqs ) };

    #  Make a lookup table of the sequence number, for use in reording
    #  sequences later:

    my $n = 0;
    my %ord = ( map { @$_[0] => ++$n } @$seqs );

    #  Build blast database (it includes the reference):

    my $protein = are_protein( $seqs );

    my $tmp_dir = &SeedAware::location_of_tmp( $options );
    $tmp_dir or print STDERR "Unable to locate temporary file directory\n"
             and return;

    my $db = SeedAware::new_file_name( "$tmp_dir/tmp_blast_db" );
    make_blast_db( $db, [ $ref, @$seqs ], $protein );

    #  Search query against new database

    my $max  = 3 * @$seqs;  # Alignments to keep
    my $self = 1;           # Keep self match (for its bit score)

    my $blast_opt = [ -e => $max_e_val,
                      -v => $max,
                      -b => $max,
                      -F => 'F',
                      -a =>  2
                    ];

    #  Do the blast analysis.  Returned records are of the form:
    #
    #        0    1     2     3    4     5     6     7      8     9     10     11
    #     [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ]

    my $prog = $protein ? 'blastp' : 'blastn';
    push @$blast_opt, qw( -r 1 -q -1 ) if ! $protein;
    my @ref_hits = top_blast_per_subject( $prog, $db, $ref, $self, $blast_opt, $options );

    #  First hit is always a perfect match, so we get bits per position:
    #  This is only used if the measure is bits per position

    my $ref_bpp = $ref_hits[0]->[6] / $ref_hits[0]->[8];

    #  Remove self match (might not be first if there are identical sequences):

    my %hit = ();
    @ref_hits = grep { my $sid = $_->[3]; $hit{ $sid } = 1; ( $sid ne $ref_id ) } @ref_hits;

    my %group = ();
    $group{ $ref_id } = [];
    my %veto = ();
    my $n_to_do = @ref_hits;
    my $rebuild_d_n  = 40;
    my $last_rebuild = 1.5 * $rebuild_d_n;
    my $rebuild = ( $n_to_do > $last_rebuild ) ? $n_to_do - $rebuild_d_n : 0;

    #  Sequence-specific maximum similarities:

    my %max_sim = map { ( $_ => $max_sim ) } @seq_id; 

    foreach ( @ref_hits )
    {
        my $id = $_->[3];
        my $sim = seq_similarity( $_, $sim_meas, $ref_bpp );

        if ( $sim > ( $use_ref ? $max_ref_sim : $max_sim ) )
        {
            $veto{ $id } = 1;
            push @{ $group{ $ref_id } }, $id;   #  Log the sequences represented
            $n_to_do--;
        } 
        else
        {
            my $max_sim_i = exp( $save_exp * log( $sim ) );
            $max_sim{ $id } = $max_sim_i if ( $max_sim_i > $max_sim );
        }
    }


    if ( $logfile )
    {
        print $logfile join( "\t", $ref_id, @{ $group{ $ref_id } } ), "\n";
    }

    #  Search each sequence against the database.
    #  If the order is to be stable, reorder hits to match input order.

    my ( $id1, $seq1, $max_sim_1, $id2, $max_sim_2, $bpp_max );
    my @ids_to_do = map { $_->[3] } @ref_hits;
    @ids_to_do = sort { $ord{ $a } <=> $ord{ $b } } @ids_to_do if $stable;

    while ( $id1 = shift @ids_to_do )
    {
        next if $veto{ $id1 };

        #  Is it time to rebuild a smaller BLAST database?  This helps
        #  significantly in the overall performance.

        if ( $n_to_do <= $rebuild )
        {
            if ( $protein ) { unlink $db, "$db.psq", "$db.pin", "$db.phr" }
            else            { unlink $db, "$db.nsq", "$db.nin", "$db.nhr" }
            make_blast_db( $db, [ map { $seq_ind->{ $_ } } # id to sequence entry
                                  grep { ! $veto{ $_ } }   # id not vetoed
                                  ( $id1, @ids_to_do )     # remaining ids
                                ],
                           $protein
                         );
            $rebuild = ( $n_to_do > $last_rebuild ) ? $n_to_do - $rebuild_d_n : 0;
        }

        $n_to_do--;
        $group{ $id1 } = [];

        $max_sim_1 = $max_sim{ $id1 };
        $bpp_max = undef;
        foreach ( top_blast_per_subject( $prog, $db, $seq_ind->{$id1}, $self, $blast_opt, $options ) )
        {
            $bpp_max ||= $_->[6] / $_->[8];
            $id2 = $_->[3];
            next if ( $veto{ $id2 } || $group{ $id2 } );
            $max_sim_2 = $max_sim{ $id2 };
            $max_sim_2 = $max_sim_1 if ( $max_sim_1 > $max_sim_2 );
            if ( seq_similarity( $_, $sim_meas, $bpp_max ) > $max_sim_2 )
            {
                $veto{ $id2 } = 1;
                push @{ $group{ $id1 } }, $id2;  #  Log the sequences represented
                $n_to_do--;
            }
        }

        if ( $logfile )
        {
            print $logfile join( "\t", $id1, @{ $group{ $id1 } } ), "\n";
        }
    }

    if ( $protein ) { unlink $db, "$db.psq", "$db.pin", "$db.phr" }
    else            { unlink $db, "$db.nsq", "$db.nin", "$db.nhr" }

    #  Return the surviving sequence entries, and optionally the hash of
    #  ids represented by each survivor:

    my $kept = [ $ref, grep { $group{ $_->[0] } } @$seqs ];

    wantarray ? ( $kept, \%group, [ grep { ! $hit{ $_->[0] } } @$seqs ] ) : $kept;
}


#===============================================================================
#  Try to figure out the sequence similarity measure that is being requested:
#
#     $type = standardize_similarity_measure( $requested_type )
#
#===============================================================================

sub standardize_similarity_measure
{   my ( $req_meas ) = @_;
    return ( ! $req_meas )          ? 'identity_fraction'
         : ( $req_meas =~ /id/i )   ? 'identity_fraction'
         : ( $req_meas =~ /sc/i )   ? 'score_per_position'
         : ( $req_meas =~ /spp/i )  ? 'score_per_position'
         : ( $req_meas =~ /bit/i )  ? 'score_per_position'
         : ( $req_meas =~ /bpp/i )  ? 'score_per_position'
         : ( $req_meas =~ /tiv/i )  ? 'positive_fraction'
         : ( $req_meas =~ /pos_/i ) ? 'positive_fraction'
         : ( $req_meas =~ /ppp/i )  ? 'positive_fraction'
         :                            'identity_fraction';
}


#===============================================================================
#  Caluculate sequence similarity according to the requested measure:
#
#     $similarity = seq_similarity( $hit, $measure, $bpp_max )
#
#  $hit is a structure with blast information:
#
#  [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ] 
#===============================================================================

sub seq_similarity
{   my ( $hit, $measure, $bpp_max ) = @_;
    return  ( @$hit < 11 )        ? undef
          : ( $measure =~ /^sc/ ) ? $hit->[ 6] / ( $hit->[8] * ( $bpp_max || 2 ) )
          : ( $measure =~ /^po/ ) ? $hit->[10] /   $hit->[8]
          :                         $hit->[ 9] /   $hit->[8]
}


#===============================================================================
#  Caluculate self similarity of a sequence in bits per position:
#
#     $max_bpp = self_bpp( $db_name, $entry, $protein, $optoins )
#
#===============================================================================

sub self_bpp
{
    my ( $db, $entry, $protein, $options ) = @_;

    #  Build blast database:

    make_blast_db( $db, [ $entry ], $protein );

    #  Search sequence against the database

    my $self = 1;  # Self match is what we need

    my $prog = $protein ? 'blastp' : 'blastn';
    my $blast_opt = [ -v =>  1,
                      -b =>  1,
                      -F => 'F',
                      -a =>  2
                     ];
    push @$blast_opt, ( -r => 1, -q => -1 ) if ! $protein;

    #  Do the blast analysis.  Returned records are of the form:
    #
    #        0    1     2     3    4     5     6     7      8     9     10     11
    #     [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ]

    my ( $hit ) = top_blast_per_subject( $prog, $db, $entry, $self, $blast_opt, $options );
    # print STDERR join( ", ", @$hit ), "\n";

    #  First hit is always a perfect match, so we get bits per position:
    #  This is only used if the measure is bits per position

    $hit->[6] / $hit->[8];
}


#===============================================================================
#  Make a blast databse from a set of sequence entries.  The type of database
#  (protein or nucleic acid) is quessed from the sequence data.
#
#     make_blast_db( $db_filename, \@seq_entries, $protein )
#
#  Sequence entries have the form: [ $id, $def, $seq ]
#===============================================================================

sub make_blast_db
{
    my ( $db, $seqs, $protein ) =  @_;

    my $formatdb = &SeedAware::executable_for( 'formatdb' )
        or print STDERR "Could not find exectuable file for 'formatdb'.\n"
            and return 0;

    $db or print STDERR "Bad database file name '$db'.\n"
            and return 0;

    $seqs && ref $seqs eq 'ARRAY' && @$seqs
        or print STDERR "Bad sequences.\n"
            and return 0;

    gjoseqlib::print_alignment_as_fasta( $db, $seqs );
    -f $db or print STDERR "Failed to write sequences to '$db'.\n"
            and return 0;

    my @param = ( -p => ( $protein ? 'T' : 'F' ),
                  -i => $db
                );

    ! system( $formatdb, @param );
}


#===============================================================================
#  The type of data (protein or nucleic acid) is quessed from the sequences.
#
#     are_protein( \@seq_entries )
#
#  Sequence entries have the form: [ $id, $def, $seq ]
#===============================================================================

sub are_protein
{
    my ( $seqs ) =  @_;
    my  ( $nt, $aa ) = ( 0, 0 );
    foreach ( @$seqs )
    {
        my $s = $_->[2];
        $nt += $s =~ tr/ACGTacgt//d;
        $aa += $s =~ tr/A-Za-z//d;
    }
    ( $nt < 3 * $aa ) ? 1 : 0;
}


#===============================================================================
#  Blast a subject against a datbase, saving only top hit per subject
#
#  Return:
#
#   [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ] 
#
#===============================================================================

sub top_blast_per_subject
{
    my $opts = $_[-1] && ref $_[-1] eq 'HASH' ? pop : {};

    my ( $prog, $db, $query, $self, $blast_opt, $sort, $no_merge ) = @_;

    my $tmp_dir = &SeedAware::location_of_tmp( $opts );
    $tmp_dir
        or print STDERR "Unable to locate temporary file directory.\n"
            and return;

    my $blastall = &SeedAware::executable_for( 'blastall' )
        or print STDERR "Could not find exectuable file for 'blastall'.\n"
            and return 0;

    my $query_file = &SeedAware::new_file_name( "$tmp_dir/tmp_blast_query", '.seq' );

    gjoseqlib::print_alignment_as_fasta( $query_file, [ $query ] );

    $blast_opt ||= [];
    my @blast_cmd = ( $blastall, '-p', $prog, '-d', $db, '-i', $query_file, @$blast_opt );

    open( BPIPE, '-|', @blast_cmd ) or die "Could not open blast pipe\n";
    my $sims = integrate_blast_segments( \*BPIPE, $sort, $no_merge, $self );
    close BPIPE;
    unlink $query_file;

    my $pq = "";  #  Previous query id
    my $ps = "";  #  Previous subject id
    my $keep;

    grep { $keep = ( $pq ne $_->[0] ) || ( $ps ne $_->[3] );
           $pq = $_->[0];
           $ps = $_->[3];
           $keep && ( $self || ( $pq ne $ps ) );
         } @$sims;
}


#===============================================================================
#  Blast queries against a datbase, saving only top hit per subject
#
#  Return:
#
#   ( [ qid, hits ], ... )
#
#   hits = [ [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ],
#            ...
#          ]
#
#===============================================================================

sub top_blast_per_subject_2
{
    my $opts = $_[-1] && ref $_[-1] eq 'HASH' ? pop : {};

    my ( $prog, $db, $queries, $self, $blast_opt, $sort, $no_merge ) = @_;

    my $tmp_dir = &SeedAware::location_of_tmp( $opts );
    $tmp_dir
        or print STDERR "Unable to locate temporary file directory.\n"
            and return;

    my $blastall = &SeedAware::executable_for( 'blastall' )
        or print STDERR "Could not find exectuable file for 'blastall'.\n"
            and return 0;

    my $query_file = &SeedAware::new_file_name( "$tmp_dir/tmp_blast_query", '.seq' );

    gjoseqlib::print_alignment_as_fasta( $query_file, $queries );

    $blast_opt ||= [];
    my @cmd = ( $blastall,
                -p => $prog,
                -d => $db,
                -i => $query_file,
                @$blast_opt
              );

    my $redirect = { stderr => '/dev/null' };
    my $pipe = SeedAware::read_from_pipe_with_redirect( @cmd, $redirect )
         or die "Could not open blast pipe\n";
    my $sims = integrate_blast_segments( $pipe, $sort, $no_merge, $self );
    close $pipe;

    unlink $query_file;

    my @qids  = map { $_->[0] } @$queries;
    my %qhits = map { $_ => [] } @qids;
    my %seen;
    foreach ( @$sims )
    {
        my $qid = $_->[0];
        my $sid = $_->[3];
        next if $seen{ "$qid\t$sid" }++;
        next if $qid eq $sid && ! $self;
        push @{ $qhits{ $qid } }, $_;
    }

    map { [ $_, $qhits{ $_ } ] } @qids;
}


#===============================================================================
#  Read output of rationalize blast and assemble minimally overlapping segments
#  into a total score for each subject sequence.  For each query, sort matches
#  into user-chosen order (D = total score):
#
#      @sims = integrate_blast_segments_0( \*FILEHANDLE, $sort_order, $no_merge )
#     \@sims = integrate_blast_segments_0( \*FILEHANDLE, $sort_order, $no_merge )
#
#  Allowed sort orders are 'score', 'score_per_position', 'identity_fraction',
#  and 'positive_fraction' (matched very flexibly).
#
#  Returned sims (e_val is only for best HSP, not any composite):
#
#     [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ] 
#
#  There is a strategic decision to not read the blast output from memory;
#  it could be enormous.  This cuts the flexibility some.
#===============================================================================
#
#  coverage fields:
#
#  [ scr, e_val, n_mat, n_id, n_pos, n_gap, dir, [ intervals_covered ] ] 
#
#===============================================================================

sub integrate_blast_segments_0
{
    my ( $fh, $order, $no_merge, $self ) = @_;
    $fh ||= \*STDIN;
    ( ref( $fh ) eq "GLOB" ) || die "integrate_blast_segments called without a filehandle\n";

    $order = ( ! $order )         ? 'score'
           : ( $order =~ /sc/i )  ? ( $order =~ /p/i ? 'score_per_position' : 'score' )
           : ( $order =~ /bit/i ) ? ( $order =~ /p/i ? 'score_per_position' : 'score' )
           : ( $order =~ /spp/i ) ? 'score_per_position'
           : ( $order =~ /id/i )  ? 'identity_fraction'
           : ( $order =~ /tiv/i ) ? 'positive_fraction'
           :                        'score';

    my $max_frac_overlap = 0.2;

    my ( $qid, $qdef, $qlen, $sid, $sdef, $slen );
    my ( $scr, $e_val, $n_mat, $n_id, $n_pos, $n_gap );
    my ( $ttl_scr, $ttl_mat, $ttl_id, $ttl_pos, $ttl_gap );
    my @sims  = ();
    my @qsims = ();
    my $coverage = undef;
    my $record;

    while ( $_ = next_blast_record( $fh, $self ) )
    {
        chomp;
        if    ( $_->[0] eq 'Query=' )
        {
            if ( $coverage )
            {
                push @qsims, [ $sid, $sdef, $slen, @$coverage[ 0 .. 5 ] ];
                $coverage = undef;
            }
            if ( @qsims ) { push @sims, order_query_sims( $qid, $qdef, $qlen, \@qsims, $order ) }
            ( undef, $qid, $qdef, $qlen ) = @$_;
            $sid = undef;
            @qsims = ();
        }
        elsif ( $_->[0] eq '>' )
        {
            if ( $coverage )
            {
                push @qsims, [ $sid, $sdef, $slen, @$coverage[ 0 .. 5 ] ];
                $coverage = undef;
            }
            next if ! $qid;
            ( undef, $sid, $sdef, $slen ) = @$_;
        }
        elsif ( $_->[0] eq 'HSP' && $sid )
        {
            shift @$_;  # discard HSP
            $coverage = integrate_HSP( $coverage, $_, $max_frac_overlap, $no_merge );
        }
    }

    if ( $coverage ) { push @qsims, [ $sid, $sdef, $slen, @$coverage[ 0 .. 5 ] ] }

    if ( @qsims ) { push @sims, order_query_sims( $qid, $qdef, $qlen, \@qsims, $order ) }

    wantarray ? @sims : \@sims;
}


#===============================================================================
#  Read blast output and assemble minimally overlapping segments into a total
#  for each subject sequence.  For each query, sort matches into user-chosen
#  order (D = total score):
#
#      @sims = integrate_blast_segments( \*FILEHANDLE, $sort_order, $no_merge )
#     \@sims = integrate_blast_segments( \*FILEHANDLE, $sort_order, $no_merge )
#
#  Allowed sort orders are 'score', 'score_per_position', 'identity_fraction',
#  and 'positive_fraction' (matched very flexibly).
#
#  Returned sims (e_val is only for best HSP, not any composite):
#
#     [ qid, qdef, qlen, sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ] 
#
#  There is a strategic decision to not read the blast output from memory;
#  it could be enormous.  This cuts the flexibility some.
#===============================================================================
#
#  coverage fields:
#
#  [ scr, e_val, n_mat, n_id, n_pos, n_gap, dir, [ intervals_covered ] ] 
#
#===============================================================================

sub integrate_blast_segments
{
    my ( $fh, $order, $no_merge, $self ) = @_;

    $fh ||= \*STDIN;
    ( ref( $fh ) eq "GLOB" ) || die "integrate_blast_segments called without a filehandle\n";

    $order = ( ! $order )         ? 'score'
           : ( $order =~ /sc/i )  ? ( $order =~ /p/i ? 'score_per_position' : 'score' )
           : ( $order =~ /bit/i ) ? ( $order =~ /p/i ? 'score_per_position' : 'score' )
           : ( $order =~ /spp/i ) ? 'score_per_position'
           : ( $order =~ /id/i )  ? 'identity_fraction'
           : ( $order =~ /tiv/i ) ? 'positive_fraction'
           :                        'score';

    my $max_frac_overlap = 0.2;

    my @sims  = ();
    my $qdata;
    while ( defined( $qdata = next_blast_query( $fh, $self ) ) )
    {
        my ( $qid, $qdef, $qlen, $qmatch ) = @$qdata;
        my @qsims = ();
        foreach my $sdata ( @$qmatch )
        {
            my ( $sid, $sdef, $slen, $smatch ) = @$sdata;
            my $coverage = undef;
            foreach my $hsp ( @$smatch )
            {
                $coverage = integrate_HSP( $coverage, $hsp, $max_frac_overlap, $no_merge );
            }

            push @qsims, [ $sid, $sdef, $slen, @$coverage[ 0 .. 5 ] ];
        }

        push @sims, order_query_sims( $qid, $qdef, $qlen, \@qsims, $order ) if @qsims;
    }

    wantarray ? @sims : \@sims;
}


#===============================================================================
#
#  Try to integrate non-conflicting HSPs for the same subject sequence.  The
#  conflicts are only assessed from the standpoint of the query, at least for
#  now.  We could track the subject sequence coverage as well (to avoid a direct
#  repeat in the query from matching the same subject twice).
#
#    $new_coverage = integrate_HSP( $coverage, $hsp, $max_frac_overlap, $no_merge )
#
#                 0      1     2      3     4      5     6             7
#  $coverage = [ scr, e_val, n_mat, n_id, n_pos, n_gap, dir, [ intervals_covered ] ]
#
#      $coverage should be undefined at the first call; the function intiallizes
#      all of the fields from the first HSP.  scr, n_mat, n_id, n_pos, and n_gap
#      are sums over the combined HSPs.  e_val is based only of the first HSP.
#
#            0     1      2      3      4      5      6     7      8    9  10   11  12  13  14
#  $hsp = [ scr, e_val, n_seg, e_val2, n_mat, n_id, n_pos, n_gap, dir, s1, e1, sq1, s2, e2, sq2 ]
#
#  $max_frac_overlap  Amount of the new HSP that is allowed to overlap already
#                     incorporated HSPs
#
#  $no_merge          Disable the merging of multiple HSPs.  The structure will
#                     be filled in from the first HSP and left unchanged though
#                     subsequence calls.  This simplifies the program structure.
#
#  Fitting a new HSP into covered intervals:
#
#   1                                                              qlen
#   |---------------------------------------------------------------| query
#           ------------                ---------------               covered
#                     -------------                                   new match
#                     l           r
#
#===============================================================================

sub integrate_HSP
{
    my ( $coverage, $hsp, $max_frac_overlap, $no_merge ) = @_;

    my ( $scr, $e_val, undef, undef, $n_mat, $n_id, $n_pos, $n_gap, $dir, $s1, $e1 ) = @$hsp;

    #  Ignore frame; just use direction of match:

    $dir = substr( $dir, 0, 1 );

    #  Orient by left and right ends:

    my ( $l, $r ) = ( $e1 > $s1 ) ? ( $s1, $e1 ) : ( $e1, $s1 );

    #  First HSP for the subject sequence:

    if ( ! $coverage )
    {
        return [ $scr, $e_val, $n_mat, $n_id, $n_pos, $n_gap, $dir, [ [ $s1, $e1 ] ] ];
    }

    #  Not first; must be same direction to combine (also test no_merge here):

    return $coverage  if ( $no_merge || ( $dir ne $coverage->[6] ) );

    #  Not first; must fall in a gap of query sequence coverage:

    my @intervals = @{ $coverage->[7] };
    my $max_overlap = $max_frac_overlap * ( $r - $l + 1 );
    my $prev_end = 0;
    my $next_beg = $intervals[0]->[0];
    my @used = ();
    while ( $next_beg <= $l )      # *** Sequential search could be made binary
    {
        $prev_end = $intervals[0]->[1];
        push @used, scalar shift @intervals;
        $next_beg = @intervals ? $intervals[0]->[0] : 1e10;
    }

    my $overlap = ( ( $l <= $prev_end ) ? ( $prev_end - $l + 1 ) : 0 )
                + ( ( $r >= $next_beg ) ? ( $r - $next_beg + 1 ) : 0 );
    return $coverage  if ( $overlap > $max_overlap );

    #  Okay, we have passed the overlap test.  We need to integrate the
    #  match into the coverage description.  Yes, I know that this counts
    #  the overlap region.  We could pro rate it, but that is messy too:

    $coverage->[0] += $scr;
    $coverage->[2] += $n_mat;
    $coverage->[3] += $n_id;
    $coverage->[4] += $n_pos;
    $coverage->[5] += $n_gap;

    #  Refigure the covered intervals, fusing intervals separated by a
    #  gap of less than 10:

    my $min_gap = 10;
    if ( $l <= $prev_end + $min_gap )
    {
        if ( @used ) { $l = $used[-1]->[0]; pop @used }
        else         { $l = 1 }
    }
    if ( $r >= $next_beg - $min_gap )
    {
        if ( @intervals ) { $r = $intervals[0]->[1]; shift @intervals }
        else              { $r = 1e10 }
    }

    $coverage->[7] = [ @used, [ $l, $r ], @intervals ];

    return $coverage;
}


#===============================================================================
#  Sort the blast matches by the desired criterion:
#
#     @sims = order_query_sims(  $qid, $qdef, $qlen, \@qsims, $order )
#
#  Allowed sort orders are 'score', 'score_per_position', 'identity_fraction',
#  and 'positive_fraction'
#
#  @qsims fields:
#
#        0    1     2     3     4      5     6      7      8
#     [ sid, sdef, slen, scr, e_val, n_mat, n_id, n_pos, n_gap ]
#
#===============================================================================

sub order_query_sims
{   my ( $qid, $qdef, $qlen, $qsims, $order ) = @_;

    my @sims;
    if ( $order eq 'score_per_position' )
    {
        @sims = map { [ $_->[5] ? $_->[3]/$_->[5] : 0, $_ ] } @$qsims;
    }
    elsif ( $order eq 'identity_fraction' )
    {
        @sims = map { [ $_->[5] ? $_->[6]/$_->[5] : 0, $_ ] } @$qsims;
    }
    elsif ( $order eq 'positive_fraction' )
    {
        @sims = map { [ $_->[5] ? $_->[7]/$_->[5] : 0, $_ ] } @$qsims;
    }
    else  # Default is by 'score'
    {
        @sims = map { [ $_->[3], $_ ] } @$qsims;
    }

    map { [ $qid, $qdef, $qlen, @{$_->[1]} ] } sort { $b->[0] <=> $a->[0] } @sims;
}


###############################################################################

sub n_rep_seqs
{
    my(%args) = (ref($_[0]) eq 'HASH') ? %{$_[0]} : @_;

    my($seqs)          = $args{seqs}          || return undef;
    my($reps)          = $args{reps}          || undef;
    my($max_iden)      = $args{max_iden}      || 0.9;      # we don't keep seqs more than 90% identical
    my($max_rep)       = $args{max_rep}       || 50;       # maximum number of seqs in returned set

    if ($args{by_size}) { $seqs = [sort { length($b->[2]) <=> length($a->[2]) } @$seqs] };

    my($lost) = {};
    my($repseqs,$representing) = &rep_seq_2($reps ? $reps : (), $seqs, { max_sim => $max_iden });
    if ($max_rep >= @$repseqs)
    {
	return ($repseqs,$representing);
    }
    my $n_rep = $reps ? @$reps : 0;
    my $incr = $max_iden / 2;
#   print STDERR "max_iden=$max_iden, ", scalar @$repseqs,"\n";
    my $iterations_left = 7;

    my @seqs2;
    while ($iterations_left && ($max_rep != @$repseqs))
    {
	if ($max_rep > @$repseqs)
	{
	    $max_iden += $incr;
	}
	else
	{
	    @seqs2 = @$repseqs[$n_rep..(@$repseqs - 1)];
	    &add_to_lost($lost,$representing);
	    $max_iden -= $incr;
	}
	($repseqs,$representing) = &rep_seq_2($reps ? $reps : (), \@seqs2, { max_sim => $max_iden });
#	print STDERR "max_iden=$max_iden, ", scalar @$repseqs,"\n";
	$iterations_left--;
	$incr = $incr / 2;
    }

    foreach my $id (keys(%$lost))
    {
	my $rep_by = $lost->{$id};
	while ($lost->{$rep_by})
	{
	    $rep_by = $lost->{$rep_by};
	}
	push(@{$representing->{$rep_by}},$id);
    }
    return ($repseqs,$representing);
}

sub add_to_lost {
    my($lost,$representing) = @_;

    foreach my $id (keys(%$representing))
    {
	my $x = $representing->{$id};
	foreach my $lost_id (@$x)
	{
	    $lost->{$lost_id} = $id;
	}
    }
}

###############################################################################

1;
