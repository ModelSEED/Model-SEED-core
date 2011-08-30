package gjoparseblast;

# This is a SAS component
#

#===============================================================================
#  This is a set of functions for reading blast output from a file, a pipe or
#  an array reference (D = \*STDIN), and providing various perl interfaces.
#
#  BEWARE:  When used with an array reference, the same array cannot be used
#           twice as the program does not know to reset the counter.
#
#  The output data are equivalent to those provided by the rationalize_blast
#  script, but can read directly from blastall, without an intermediate file
#  or a shell.  It is possible to gather all the output at once, to gather
#  it a query at a time, to gather it a subject sequence at a time, to
#  gather it an HSP at a time, or to read it record-by-record (as it is
#  provided by the rationalize_blast script).  The flexible granulatity of
#  access is intended to faciliate the prossessing of large streams of
#  output without loading it all into memory.
#
#  The 'self' option enables returning matches with query_id eq subject_id.
#  These are normally discarded (matching the behavior of ratonalize_blast).
#
#===============================================================================
#
#  Structured collection of all blast output:
#
#     @output = structured_blast_output( $input, $self )
#    \@output = structured_blast_output( $input, $self )
#
#     Output is clustered heirarchically by query, by subject and by hsp.  The
#     highest level is query records:
#
#     [ qid, qdef, qlen, [ [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                          [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                          ...
#                        ]
#     ]
#
#     hsp_data:
#
#     [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#        0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
#
#-------------------------------------------------------------------------------
#
#  Flattened collection of all blast output, one record per HSP:
#
#      @hsps = blast_hsp_list( $input, $self )
#     \@hsps = blast_hsp_list( $input, $self )
#
#     Output records are all of the form:
#
#     [ qid qdef qlen sid sdef slen scr e_val p_n p_val n_mat n_id n_pos n_gap dir q1 q2 qseq s1 s2 sseq ]
#        0   1    2    3   4    5    6    7    8    9    10    11   12    13   14  15 16  17  18 19  20
#
#-------------------------------------------------------------------------------
#
#  Collection of all blast output in the record types of rationalize_blast
#  (Query=, > and HSP):
#
#      @records = blast_record_list( $input, $self )
#     \@records = blast_record_list( $input, $self )
#
#     There are 3 record types:  'Query=', '>' and 'HSP', with fields:
#
#     [ 'Query='  query_id  query_def  query_len ]
#          0         1          2          3
#
#     [   '>'     sbjct_id  sbjct_def  sbjct_len ] 
#          0         1          2          3
#
#     [ 'HSP' scr exp p_n p_val n_mat n_id n_sim n_gap dir q1 q2 qseq s1 s2 sseq ]
#         0    1   2   3    4     5    6     7     8    9  10 11  12  13 14  15
#
#-------------------------------------------------------------------------------
#
#  Blast output one query at a time:
#
#     $query_results = next_blast_query( $input, $self )
#
#     Query record structure is defined above (see structured_blast_output)
#
#-------------------------------------------------------------------------------
#
#  Blast output one subject sequence at a time:
#
#     $subject_results = next_blast_subject( $input, $self )
#
#     Output fields are:
#
#     [ qid, qdef, qlen, sid, sdef, slen, [ hsp_data, hsp_data, ... ] ]
#
#     hsp_data is defined above (see structured_blast_output)
#
#-------------------------------------------------------------------------------
#
#  Blast output one HSP at a time:
#
#     $hsp = next_blast_hsp( $input, $self )
#
#     HSP record fields are defined above (see blast_hsp_list)
#
#-------------------------------------------------------------------------------
#
#  Blast output one record (Query=, > and HSP) at a time:
#
#     $record = next_blast_record( $input, $self )
#
#     Record types and fields are defined above (see blast_record_list)
#
#===============================================================================
#
#   The following code fragment would read blast output from STDIN, one
#   HSP at a time, process that HSP and move on.  It is the extreme form
#   of "memory-light".
#
#       my $hsp;
#       while ( defined( $hsp = next_blast_hsp() )
#       {
#          # Process the HSP
#       }
#
#-------------------------------------------------------------------------------
#
#   The following code fragment would launch blastall in a forked process,
#   read blast output one subject at a time, process those HSPs and move on.
#
#       my( $prog, $query, $db ) = @_;
#
#       #  This tedious approach allows file names with blanks and tabs, not to
#       #  mention newlines (sorry, but it was too much to resist):
#
#       my @command = ('blastall', '-p', $prog, '-d', $db, '-i', $query, '-e', '1e-5');
#
#       #  Of course we could (ab)use perl to make it more (or less) opaque:
#       #
#       #    my @command = qw( blastall -p prog -d db -i query -e 1e-5 );
#       #    @command[2,6,4] = @_;
#
#       my $bfh;
#       my $pid = open( $bfh, '-|' );
#       if ( $pid == 0 )
#       {
#           exec( @command );
#           die "'" . join(" ", @command) . "' failed: $!\n";
#       }
#
#       my $subj_matches;
#       while ( defined( $subj_matches = next_blast_subject( $bfh ) )
#       {
#           my ( $qid, $qdef, $qlen, $sid, $sdef, $slen, $hsps ) = @$subj_matches;
#           foreach ( sort { $b->[5]/$b->[4] <=> $a->[5]/$a->[4] } @$hsps )
#           {
#               # Process the HSPs, sorted by percent identity
#           }
#       }
#
#       close $bfh;
#
#===============================================================================

use strict;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
        structured_blast_output
        blast_hsp_list
        blast_record_list

        next_blast_query
        next_blast_subject
        next_blast_hsp
        next_blast_record
        );


#===============================================================================
#  Collect BLAST program output into parsed records.  This version returns
#  the entire output in one list, hence care should be taken with multiple
#  query searches.  The record types correspond to those returned by the
#  ratonalize_blast script.
#
#      @records = blast_record_list( $input, $self )
#
#  or
#
#     \@records = blast_record_list( $input, $self )
#
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  There are 3 output record types:  'Query=', '>' and 'HSP'.  Their fields are:
#
#     [ 'Query='  query_id  query_def  query_len ]
#          0         1          2          3
#
#     [   '>'     sbjct_id  sbjct_def  sbjct_len ] 
#          0         1          2          3
#
#     [ 'HSP' scr exp p_n p_val n_mat n_id n_sim n_gap dir q1 q2 qseq s1 s2 sseq ]
#         0    1   2   3    4     5    6     7     8    9  10 11  12  13 14  15
#
#===============================================================================

sub blast_record_list
{
    my @out = ();

    local $_;
    while ( $_ = next_blast_record( @_ ) ) { push @out, $_; }

    wantarray ? @out : \@out;
}


#===============================================================================
#  Collect BLAST program output into parsed records.  This version returns
#  the entire output in one list, hence care should be taken with multiple
#  query searches:
#
#      @hsps = blast_hsp_list( $input, $self )
#
#  or
#
#     \@hsps = blast_hsp_list( $input, $self )
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  There is one record per HSP, and all output records are stand alone, having
#  the query and subject sequence data:
#
# qid qdef qlen sid sdef slen scr e_val p_n p_val n_mat n_id n_pos n_gap dir q1 q2 qseq s1 s2 sseq
#  0   1    2    3   4    5    6    7    8    9    10    11   12    13   14  15 16  17  18 19  20
#
#===============================================================================

sub blast_hsp_list
{
    my @out = ();

    local $_;
    while ( $_ = next_blast_hsp( @_ ) ) { push @out, $_; }

    wantarray ? @out : \@out;
}


#===============================================================================
#  Collect BLAST program output into perl structures.  This returns
#  the entire output in one list, hence care should be taken with multiple
#  query searches:
#
#      @output = structured_blast_output( $input, $self )
#
#  or
#
#     \@output = structured_blast_output( $input, $self )
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  Output is clustered heirarchically:
#
#    ( [ qid, qdef, qlen, [ [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                           [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                           ...
#                         ]
#      ],
#      [ qid, qdef, qlen, [ [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                           [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                           ...
#                         ]
#      ],
#      ...
#    )
#
#  hsp_data = [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#                0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
#
#  Each query will be reported even if it does not have hits.
#
#===============================================================================

sub structured_blast_output
{
    my ( $subj_list, $hsp_list );
    my @out = ();

    local $_;
    while ( $_ = next_blast_record( @_ ) )
    {
        my $type = shift @$_;

        if ( $type eq 'Query=' )
        {
            $subj_list = [];
            $hsp_list = undef;
            push @out, [ @$_, $subj_list ];
        }

        elsif ( $subj_list and ( $type eq '>' ) )
        {
            $hsp_list = [];
            push @$subj_list, [ @$_, $hsp_list ];
        }

        elsif ( $hsp_list && ( $type eq 'HSP' ) )
        {
            push @$hsp_list, $_;
        }
    }

    wantarray ? @out : \@out;
}


#===============================================================================
#  Collect BLAST program output into perl structures.  This returns
#  the output for one query sequence:
#
#     $query_results = next_blast_query( $input, $self )
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  Output structure:
#
#    [ qid, qdef, qlen, [ [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                         [ sid, sdef, slen, [ hsp_data, hsp_data, ... ] ],
#                         ...
#                       ]
#    ]
#
#  hsp_data = [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#                0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
#
#  Each query will be reported even if it does not have hits.
#
#===============================================================================

{
my %query_info = ();

sub next_blast_query
{   my ( $input, $self ) = @_;
    $input ||= \*STDIN;

    my ( $query_info, $subj_list, $hsp_list );

    if ( $query_info = $query_info{ $input } )
    {
        $subj_list = [];
        $query_info{ $input } = undef;
    }

    local $_;
    while ( $_ = next_blast_record( @_ ) )
    {
        my $type = shift @$_;

        if ( $type eq 'Query=' )
        {
            if ( $subj_list )
            {
                $query_info{ $input } = [ @$_ ];
                return [ @$query_info, $subj_list ];
            }

            $query_info = [ @$_ ];
            $subj_list  = [];
            $hsp_list   = undef;
        }

        elsif ( $subj_list and ( $type eq '>' ) )
        {
            $hsp_list = [];
            push @$subj_list, [ @$_, $hsp_list ];
        }

        elsif ( $hsp_list && ( $type eq 'HSP' ) )
        {
            push @$hsp_list, $_;
        }
    }

    $query_info{ $input } = undef;
    $subj_list ? [ @$query_info, $subj_list ] : undef;
}
}


#===============================================================================
#  Collect BLAST program output into perl structures.  This returns
#  the output for one subject sequence:
#
#     $subject_results = next_blast_subject( $input, $self )
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  Output structure:
#
#    [ qid, qdef, qlen, sid, sdef, slen, [ hsp_data, hsp_data, ... ] ]
#
#  hsp_data = [ scr, exp, p_n, pval, nmat, nid, nsim, ngap, dir, q1, q2, qseq, s1, s2, sseq ]
#                0    1    2    3     4     5    6     7     8   9   10   11   12  13   14
#
#===============================================================================

{
my %q_and_s_info = ();

sub next_blast_subject
{   my ( $input, $self ) = @_;
    $input ||= \*STDIN;

    my $q_and_s_info = $q_and_s_info{ $input } || [ (undef) x 6 ];
    my $hsp_list = defined( $q_and_s_info->[3] ) ? [] : undef;

    local $_;
    while ( $_ = next_blast_record( @_ ) )
    {
        my $type = shift @$_;

        if ( $type eq 'Query=' )
        {
            if ( $hsp_list && @$hsp_list )
            {
                $q_and_s_info{ $input } = [ @$_, undef, undef, undef ];
                return [ @$q_and_s_info, $hsp_list ];
            }

            @$q_and_s_info = ( @$_, undef, undef, undef );
            $hsp_list = undef;
        }

        elsif ( $type eq '>' )
        {
            if ( $hsp_list && @$hsp_list )
            {
                $q_and_s_info{ $input } = [ @$q_and_s_info[0..2], @$_ ];
                return [ @$q_and_s_info, $hsp_list ];
            }

            if ( defined( $q_and_s_info->[0] ) )
            {
                @$q_and_s_info[ 3 .. 5 ] = @$_;
                $hsp_list = [];
            }
        }

        elsif ( ( $type eq 'HSP' ) && $hsp_list )
        {
            push @$hsp_list, $_;
        }
    }

    $q_and_s_info{ $input } = undef;
    $hsp_list ? [ @$q_and_s_info, $hsp_list ] : undef;
}
}


#===============================================================================
#  Collect BLAST program output into parsed records.  This version returns
#  the output one HSP at a time, hence is the memory light version:
#
#     $hsp = next_blast_hsp( $input, $self )
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  Output record fields are:
#
# qid qdef qlen sid sdef slen scr e_val p_n p_val n_mat n_id n_pos n_gap dir q1 q2 qseq s1 s2 sseq
#  0   1    2    3   4    5    6    7    8    9    10    11   12    13   14  15 16  17  18 19  20
#
#===============================================================================

{
my %q_and_s_info = ();  #  Saving query and subject info between calls

sub next_blast_hsp
{   my ( $input, $self ) = @_;
    $input ||= \*STDIN;

    my $q_and_s_info = $q_and_s_info{ $input } || [ (undef) x 6 ];

    local $_;
    while ( $_ = next_blast_record( @_ ) )
    {
        my $type = shift @$_;
        if    ( $type eq 'Query=' )
        {
            @$q_and_s_info = ( @$_, undef, undef, undef );
        }

        elsif ( $type eq '>' )
        {
            @$q_and_s_info[ 3 .. 5 ] = @$_ if  defined( $q_and_s_info->[0] );
        }

        elsif ( $type eq 'HSP' && defined( $q_and_s_info->[3] ) )
        {
            $q_and_s_info{ $input } = $q_and_s_info;
            return [ @$q_and_s_info, @$_ ];
        }
    }

    $q_and_s_info{ $input } = undef;
    return undef;
}
}


#===============================================================================
#  Collect BLAST program output into parsed records.  Each call returns one
#  record.  Record types correspond to those of the rationalize_blast script.
#  This can be used to progressively read blast output from a file or pipe,
#  without putting it all in memory.
#
#     $record = next_blast_record( $input, $self )
#
#     $input An input file or pipe handle, or array ref.  If it is undef,
#            \*STDIN will be used.
#
#     $self  Normally matches of a query to itself are discarded.  This can be
#            overriden by setting $self to true.
#
#  There are 3 output record types:  'Query=', '>' and 'HSP'.  Their fields are:
#
#     [ 'Query='  query_id  query_def  query_len ]
#          0         1          2          3
#
#     [ '>'       sbjct_id  sbjct_def  sbjct_len ]
#         0        1          2          3
#
#     [ 'HSP' scr exp p_n p_val n_mat n_id n_sim n_gap dir q1 q2 qseq s1 s2 sseq ]
#         0    1   2   3    4     5    6     7     8    9  10 11  12  13 14  15
#
#===============================================================================

{
my %blast_state = ();

sub next_blast_record
{   my ( $input, $self ) = @_;
    $input ||= \*STDIN;

    my ( $qid, $qdef, $qlen, $q1, $q2, @qseq );
    my ( $sid, $sdef, $slen, $s1, $s2, @sseq );
    my ( $s, $e, $n, $p, $ident, $outof, $posit, $ngap, $frame );
    my $q_ok   = 0;
    my $s_ok   = 0;
    my $hsp_ok = 0;

    my $saved_line;
    my $state = $blast_state{ $input };
    ( $saved_line, $q_ok, $qid, $s_ok, $sid ) = @$state if $state;

    while ( 1 )
    {
        local $_ = defined( $saved_line ) ? $saved_line : nextline( $input );
        $saved_line = undef;

        if (defined($_)) { s/\s+$//; }    #  trim trailing spaces (including the newline)

        # These all signify the end of an HSP.  Report it. ---------------------

        if ( $hsp_ok && ( /^Query=/
                       || /^>/
                       || /^Parameters:/
                       || /^ +Score = /
                       || /^ +Plus Strand HSPs:/
                       || /^ +Minus Strand HSPs:/
                       || /^ +Database:/
                       || ! defined( $_ )
                        )
           )
        {
            if ( $s_ok && $q1 && @qseq && $s1 && @sseq )
            {
                $e =~ s/^e-/1.0e-/i;  # Fix missing digits in exponential
                $p =~ s/^e-/1.0e-/i;

                $frame ||= (seqdir($q1,$q2) * seqdir($s1,$s2) > 0) ? "+" : "-";

                $blast_state{ $input } = [ $_, $q_ok, $qid, $s_ok, $sid ];
                return [ 'HSP', $s, $e, $n, $p,
                                $outof, $ident, $posit, $ngap, $frame,
                                $q1, $q2, join( '', @qseq ),
                                $s1, $s2, join( '', @sseq )
                       ];
            }

            $hsp_ok = 0;
        }

        #  This is the end condition -------------------------------------------

        last if ! defined( $_ );

        #  Now that reporting is up-to-date, process the line  -----------------

        #  Query sequence description  -----------------------------------------

        if ( s/^Query=\s+// )
        {
            $q_ok   = 0;
            $s_ok   = 0;
            $hsp_ok = 0;

            ( $qid, $qdef ) = split_id( $_ );   # query description

            #  Continue reading to query length

            while ( defined( $_ = nextline( $input ) ) )
            {
                s/\s+$//;                       # trailing space

                 #  Query length marks end of description

                if ( /^  +\(([1-9][\d,]*) letters.*\)/ )
                {
                    $qlen = $1;                 # grab query length
                    $qlen =~ s/,//g;            # get rid of commas
                    $q_ok = 1;
                    $blast_state{ $input } = [ undef, $q_ok, $qid, $s_ok, $sid ];
                    return [ 'Query=', $qid, $qdef, $qlen ];   # return query description
                }

                #  Database before length is an error

                elsif ( /^Database:/ ) { last; }

                #  Otherwise this is a continuation of the query description.
                #  Remove leading white space.

                s/^\s+//;
                $qdef .= ( $qdef =~ /-$/ ) ? $_ : " $_";
            }

            #  Failed to get query length?

            if ( ! $qlen )
            {
                $_ || ( $_ = defined($_) ? "" : "[EOF]" );
                print STDERR "Error parsing query definition for sequence length:\n";
                print STDERR "$qid $qdef\n<<<here>>>\n$_\n\n";
                print STDERR "Flushing this query sequence\n\n";
                next;
            }
        }

        # Subject sequence description -----------------------------------------

        elsif ( $q_ok && s/^>\s*// )
        {
            $s_ok   = 0;
            $hsp_ok = 0;

            ( $sid, $sdef ) = split_id( $_ );   # subject description

            while ( defined( $_ = nextline( $input ) ) )
            {
                chomp;

                #  Length marks end of subject sequence description

                if ( /^ +Length = ([1-9][\d,]*)/ )
                {  
                    $slen = $1;
                    $slen =~ s/,//g;
                    if ( $self || ( $sid ne $qid ) )
                    {
                        $s_ok = 1;
                        $blast_state{ $input } = [ undef, $q_ok, $qid, $s_ok, $sid ];
                        return [ '>', $sid, $sdef, $slen ];   # return subject description
                    }
                    last;
                }

                #  Multiple spaces marks a continuation

                elsif ( s/^  +// )
                {
                    $sdef .= ( $sdef =~ /-$/ ) ? $_ : " $_";
                }

                #  Merged nr entries start with one space

                elsif ( s/^ /\001/ ) {
                    $sdef .= $_;
                }

                #  Anything else is an error

                else { last; }
            }

            if ( ! $slen )
            {
                $_ ||= defined($_) ? "" : "[EOF]";
                print STDERR "Error parsing subject definition for sequence length:\n";
                print STDERR "$sid $sdef\n<<<here>>>\n$_\n\n";
                print STDERR "Flushing this subject sequence\n\n";
            }
        }

        # Score marks the start of an HSP description --------------------------

        elsif ( $s_ok && /^ Score = +([\d.e+-]+) / )
        {
            $hsp_ok = 0;

            $s = $1;
            if ( ! /Expect = +([^ ,]+)/ && ! /Expect[(]\d+[)] = +([^ ,]+)/ )
            {
                print STDERR "Error parsing Score line for Expect:\n";
                print STDERR "Query = $qid; Subject = $sid\n<<<here>>>\n$_\n";
                print STDERR "Flushing this HSP\n\n";
                next;
            }

            $e = $1;
            $n = /Expect\((\d+)\)/ ? $1
               : /P\((\d+)\)/      ? $1
               :                      1;
            $p = / = +(\S+)$/ ? $1 : $e;

            if ( ! defined( $_ = nextline( $input ) ) )
            {
                print STDERR "End-of-file while looking for Identities line:\n";
                print STDERR "Query = $qid; Subject = $sid\n<<<here>>>\n";
                print STDERR "Flushing this HSP\n\n";
                next;
            }
            chomp;

            if ( ! /^ Identities = +(\d+)\/(\d+)/ )
            {
                print STDERR "Error parsing Identities line:\n";
                print STDERR "Query = $qid; Subject = $sid\n<<<here>>>\n$_\n";
                print STDERR "Flushing this HSP\n\n";
                next;
            }
            $ident = $1;
            $outof = $2;

            $posit = /Positives = +(\d+)/ ? $1 : $ident;
            $ngap  = /Gaps = +(\d+)/      ? $1 : 0;

            $q1 = $s1 = undef;
            @qseq = @sseq = ();
            $hsp_ok = 1;
        }

        #  Frame of a translated blast -----------------------------------------

        elsif ( $hsp_ok && /^ Frame = +(\S+)/ )
        {
            $frame = $1;
        }

        #  Query sequence data -------------------------------------------------

        elsif ( $hsp_ok && s/^Query: +// )
        {
            my ($t1, $t2, $t3) = /(\d+)\s*([^\d\s]*)\s*(\d+)/;

            #  First fragment of alignment?

            if ( ! $q1 )
            {
                $q1 = $t1;
            }

            #  Additional fragment of alignment:
            #  Changed to handle entire row of gaps -- GJO 

            elsif ( abs( $t1 - $q2 ) > 1 )
            {
                print STDERR "Warning: Query position $t1 follows $q2\n";
                print STDERR "Query = $qid; Subject = $sid\n";
                print STDERR "$_\nFlushing this HSP\n\n";
                $hsp_ok = 0;
                next;
            }

            push @qseq, $t2;  #  Append sequence
            $q2       = $t3;  #  New last residue number

            #  Flush the alignment match symbol line

            if ( ! defined( $_ = nextline( $input ) ) )
            {
                print STDERR "End-of-file while reading alignment:\n";
                print STDERR "Query = $qid; Subject = $sid\n";
                print STDERR "Flushing this HSP\n\n";
                $hsp_ok = 0;
            }
        }

        #  Subject sequence data -----------------------------------------------

        elsif ( $hsp_ok && s/^Sbjct: +// )
        {
            my ( $t1,  $t2, $t3 ) = /(\d+)\s*([^\d\s]*)\s*(\d+)/;

            #  First fragment of alignment?

            if ( ! $s1 )
            {
                $s1 = $t1;
            }

            #  Additional fragment of alignment:
            #  Changed to handle entire row of gaps -- GJO 

            elsif ( abs( $t1 - $s2 ) > 1 )
            {
                print STDERR "Warning: Subject position $t1 follows $s2\n";
                print STDERR "Query = $qid; Subject = $sid\n";
                print STDERR "$_\nFlushing this HSP\n\n";
                $hsp_ok = 0;
                next;
            }

            push @sseq, $t2;  #  Append sequence
            $s2       = $t3;  #  New last residue number

            #  Flush the blank line

            nextline( $input );
        }

        #  Back up to the top to read another line -----------------------------
    }

    #  Breaking of the loop when an undefined input line is encountered,
    #  we are done.

    $blast_state{ $input } = undef;
    return undef;
}
}  #  End of bare block with state information


#===============================================================================
#  Useful functions:
#===============================================================================

#  This now keeps an index on each array reference.  It is critical that the
#  same array not be used twice, as it does not know to reset the counter.

{
my %index;
sub nextline
{
    my $input = shift;
    ref( $input ) eq "GLOB"  ? <$input>                          :
    ref( $input ) eq "ARRAY" ? $input->[ $index{$input}++ || 0 ] :
                               undef
}
}


sub split_id
{
    ( $_[0] =~ m/(\S+)(\s+(\S.*))?$/ ) ? ( $1, defined($3) ? $3 : "" ) : ();
}


sub seqdir { ( $_[0] <= $_[1] ) ? 1 : -1 }


sub dna_identity
{
    my ( $q_seq, $s_seq, $gap_weight ) = uc @_;
    $gap_weight = 1 if ! defined $gap_weight;  # Full mismatch
    $q_seq =~ tr/U/T/;
    $s_seq =~ tr/U/T/;
    #  Remove columns with ambiguity
    my $n_mask = $q_seq;
    $n_mask =~ tr/ACGT-/\377\377\377\377\377/;
    $n_mask =~ tr/\377/\000/c;
    $n_mask &= $s_seq;
    $n_mask =~ tr/ACGT-/\377\377\377\377\377/;
    $n_mask =~ tr/\377/\000/c;
    $q_seq &= $n_mask;
    $q_seq =~ tr/\000//d;
    $s_seq &= $n_mask;
    $s_seq =~ tr/\000//d;
    #  Okay.  Now gaps.
    my $q_gap = $q_seq;
    $q_gap =~ tr/-/\000/;
    $q_gap =~ tr/\000/\377/c;
    my $s_gap = $s_seq;
    $s_gap =~ tr/-/\000/;
    $s_gap =~ tr/\000/\377/c;
    my $shared_gap = ( $q_gap | $s_gap ) =~ tr/\000//;
    my $unique_gap = ( $q_gap ^ $s_gap ) =~ tr/\000//;
    my $n_identity = ( ( $q_seq ^ $s_seq ) =~ tr/\000// ) - $shared_gap;
    my $n_position = length $q_seq - $shared_gap - ( 1 - $gap_weight ) * $unique_gap;

    $n_position ? $n_identity / $n_position : undef
}


1;
