
# This is a SAS component.

########################################################################
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
########################################################################

package SeedUtils;
use BerkTable;
use DB_File;
use Carp;

#
# In case we are running in a SEED, pull in the FIG_Config
#
BEGIN
{
    eval {
	require FIG_Config;
    };
}

    use strict;
    no warnings qw(once);
    use base qw(Exporter);
    our @EXPORT = qw(hypo boundaries_of parse_fasta_record create_fasta_record
                     rev_comp genome_of min max sims verify_dir between translate
                     standard_genetic_code parse_location roles_of_function
                     strip_ec location_string location_cmp strand_of by_fig_id
		     verify_db bbh_data id_url validate_fasta_file);

=head1 SEED Utility Methods

=head2 Introduction

This is a simple utility package that performs functions useful for
bioinformatics, but that do not require access to the databases.

=head2 Public Methods

=head3 abbrev

    my $abbrev = SeedUtils::abbrev($genome_name);

Return an abbreviation of the specified genome name. This method is used to create
a reasonably indicative genome name that fits in 10 characters.

=over 4

=item genome_name

Genome name to abbreviate.

=item RETURN

Returns a shortened version of the genome name that is 10 characters or less in
length.

=back

=cut

sub abbrev {
    my($genome_name) = @_;
    my %exclude = map { $_ => 1 } 
                  qw( candidatus subspecies subsp strain str bv pv sp );
    my ($p1,$p2,@rest) = grep { ! $exclude{lc $_} } 
                         map { $_ =~ s/\W//g; $_ }
                         split(/\s/,$genome_name);
    my $p3 = join("",@rest);

    my $lbl_ln = 10;

    if (! $p2)
    {
	if (length($p1) > $lbl_ln) { $p1 = substr($p1,0,$lbl_ln) }
	return $p1;
    }
    elsif (! $p3)
    {
	my $l1 = length($p1);
	my $l2 = length($p2);
	my $ln1 = $l1;
	my $ln2 = $l2;

	if (($l1 + $l2 + 1) > $lbl_ln)
	{
	    $ln1 = $lbl_ln - ($l2+1);
	    $ln1 = &min($l1,&max($ln1,3));
	    $ln2 = $lbl_ln - ($ln1+1);
	    $p1 = substr($p1,0,$ln1);
	    $p2 = substr($p2,0,$ln2);
	}
	my $sep = ($l1 == $ln1) ? '_' : '.';
	return $p1 . $sep . $p2;
    }
    else
    {
	my $l1  = length($p1);
	my $l2  = length($p2);
	my $l3  = length($p3);
	my $l23 = $l2+$l3+1;
	my $ln1 = $l1;
	my $ln2 = $l2;
	my $ln3 = $l3;
	
	if (($l1 + $l2 + $l3 + 2) > $lbl_ln)
	{
	    $ln1 = $lbl_ln - ($l23 + 1);
	    $ln1 = &min($l1,&max($ln1,3));
	    my $rest = $lbl_ln - ($ln1+1);
	    $ln2 = $rest - ($ln3+1);
	    $ln2 = &min($l2,&max($ln2,3));
	    $ln3 = $lbl_ln - ($ln1+$ln2+2);

	    $p1 = substr($p1,0,$ln1);
	    $p2 = substr($p2,0,$ln2);
	    $p3 = substr($p3,0,$ln3);
	}
	my $sep1 = ($l1 == $ln1) ? '_' : '.';
	my $sep2 = ($l2 == $ln2) ? '_' : '.';
	return $p1 . $sep1 . $p2 . $sep2 . $p3;
    }
}

=head3 abbrev_set

    my $abbrevH = SeedUtils::abbrev_set($genome_names);

Takes a pointer to a list of genome names and returns a hash mapping names to unique
abbreviations.  The names will be less than or equal to 10 characters in length.

=over 4

=item genome_names

Pointer to a list of genome names

=item RETURN

Returns a hash mapping full names to unique abbreviations.

=back

=cut

sub abbrev_set {
    my($genome_names) = @_;

    my %seen;
    my $hash = {};
    foreach my $name (@$genome_names)
    {
	next if ($hash->{$name});
	my $abbrev = &abbrev($name);
	while ($seen{$abbrev})
	{
	    $abbrev = &next_try($abbrev);
	}
	$hash->{$name} = $abbrev;
	$seen{$abbrev} = 1;
    }
    return $hash;
}

sub next_try {
    my($abbrev) = @_;

    my($ext) = ($abbrev =~ s/\.(\d+)$//);
    $ext ||= 0;
    $ext++;
    my $ln = length($abbrev) + length($ext) + 1;
    if ($ln > 10)
    {
	$abbrev = substr($abbrev,0,(10 - (length($ext)+1)));
    }
    return "$abbrev.$ext";
}

=head3 bbh_data

    my $bbhList = FIGRules::bbh_data($peg, $cutoff);

Return a list of the bi-directional best hits relevant to the specified PEG.

=over 4

=item peg

ID of the feature whose bidirectional best hits are desired.

=item cutoff

Similarity cutoff. If omitted, 1e-10 is used.

=item RETURN

Returns a reference to a list of 3-tuples. The first element of the list is the best-hit
PEG; the second element is the score. A lower score indicates a better match. The third
element is the normalized bit score for the pair; it is normalized to the length
of the protein.

=back

=cut

#: Return Type @@;
sub bbh_data {
    my ($peg, $cutoff) = @_;
    my @retVal = ();
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new();
    my $url = "http://bioseed.mcs.anl.gov/simserver/perl/bbhs.pl";
    my $retries = 5;
    my $done = 0;
    my $resp;
    while ($retries > 0 && ! $done) {
        $resp = $ua->post($url, { id => $peg, cutoff => $cutoff });
        if ($resp->is_success) {
            my $dat = $resp->content;
            while ($dat =~ /([^\n]+)\n/g) {
                my @l = split(/\t/, $1);
                push @retVal, \@l;
            }
            $done = 1;
        } else {
            $retries--;
        }
    }
    if (! $done) {
        die("Failure retrieving bbh data for $peg: " . $resp->status_line);
    }
    return \@retVal;
}


=head3 between

    my $flag = between($x, $y, $z);

Determine whether or not $y is between $x and $z.

=over 4

=item x

First edge number.

=item y

Number to examine.

=item z

Second edge number.

=item RETURN

Return TRUE if the number I<$y> is between the numbers I<$x> and I<$z>. The check
is inclusive (that is, if I<$y> is equal to I<$x> or I<$z> the function returns
TRUE), and the order of I<$x> and I<$z> does not matter. If I<$x> is lower than
I<$z>, then the return is TRUE if I<$x> <= I<$y> <= I<$z>. If I<$z> is lower,
then the return is TRUE if I<$x> >= I$<$y> >= I<$z>.

=back

=cut

#: Return Type $;
sub between {
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my($x,$y,$z) = @_;

    if ($x < $z) {
        return (($x <= $y) && ($y <= $z));
    } else {
        return (($x >= $y) && ($y >= $z));
    }
}


=head3 boundaries_of

    my ($contig, $min, $max, $dir) = boundaries_of($locs);

Return the boundaries of a set of locations. The contig, the leftmost
location, and the rightmost location will be returned to the caller. If
more than one contig is represented, the method will return an undefined
value for the contig (indicating failure).

=over 4

=item locs

Reference to a list of location strings. A location string contains a contig ID,
and underscore (C<_>), a starting offset, a strand identifier (C<+> or C<->), and
a length (e.g. C<360108.3:NC_10023P_1000+2000> begins at offset 1000 of contig
B<360108.3:NC_10023P> and covers 2000 base pairs on the C<+> strand).

=item RETURN

Returns a 4-element list. The first element is the contig ID from all the locations,
the second is the offset of leftmost base pair represented in the locations, the
third is the offset of the rightmost base pair represented in the locations, and
the fourth is the dominant strand.

=back

=cut

sub boundaries_of {
    # Get the parameters.
    my ($locs) = @_;
    # Declare the return variables.
    my ($contig, $min, $max);
    # We'll put all the starting and ending offsets found in here.
    my @offsets;
    # This will be used to count the orientations.
    my %dirs = ('+' => 0, '-' => 0);
    # This will count the number of errors found.
    my $error = 0;
    # Insure the location is an array. If it's not, we assume it's a string of
    # comma-separated values.
    if (! ref $locs) {
        $locs = [ split /\s*,\s*/, $locs ];
    }
    # Loop through the locations.
    for my $loc (@$locs) {
        # Parse this location.
        if ($loc =~ /^(.+)_(\d+)(\+|\-)(\d+)$/) {
            # This is a valid location string.
            my ($newContig, $begin, $dir, $len) = ($1, $2, $3, $4);
            # Is this contig valid?
            if ($contig && $newContig ne $contig) {
                # No, skip this location.
                $error++;
            } else {
                # Save the contig.
                $contig = $newContig;
                # Count the orientation.
                $dirs{$dir}++;
                # Compute the ending offset.
                my $end = ($dir eq '+' ? $begin + $len - 1 : $begin - $len + 1);
                # Save both offsets.
                push @offsets, $begin, $end;
            }
        } elsif ($loc =~ /^(.+)_(\d+)_(\d+)/) {
            # Here we have an old-style location string.
            my($newContig, $start, $stop) = ($1, $2, $3);
            # Is this contig valid?
            if ($contig && $newContig ne $contig) {
                # No, skip this location.
                $error++;
            } else {
                # Save the contig.
                $contig = $newContig;
                # Compute the orientation.
                my $dir;
                if ($start > $stop) {
                    $dir = '-';
                } else {
                    $dir = '+';
                }
                # Count it.
                $dirs{$dir}++;
                # Save both offsets.
                push @offsets, $start, $stop;
            }
        } else {
            # The location is invalid, so it's an error,
            $error++;
        }
    }
    # If there's an error, clear the contig ID.
    if ($error) {
        $contig = undef;
    }
    # Compute the min and max from the offsets collected.
    $min = min(@offsets);
    $max = max(@offsets);
    # Save the dominant orientation.
    my $dir = ($dirs{'-'} > $dirs{'+'} ? '-' : '+');
    # Return the results.
    return ($contig, $min, $max, $dir);
}

=head3 boundary_loc

    my $singleLoc = SeedUtils::boundary_loc($locations);

Return a single location string (see L<SAP/Location Strings>) that covers
the incoming list of locations. NOTE that if the locations listed span
more than one contig, this method may return an unexpected result.

This method is useful for converting the output of L<SAP/fid_locations> to
location strings.

=over 4

=item locations

A set of location strings formatted as a comma-separated list or as a reference
to a list of location strings.

=item RETURN

Returns a single location string that covers as best as possible the list of
incoming locations.

=back

=cut

sub boundary_loc {
    # Get the parameters.
    my ($locations) = @_;
    # Convert the incoming locations to a list.
    my @locs;
    if (ref $locations eq 'ARRAY') {
        @locs = @$locations;
    } else {
        @locs = split /\s*,\s*/, $locations;
    }
    # Get the boundary information for the listed locations.
    my ($contig, $min, $max, $dir) = boundaries_of(\@locs);
    # Compute the indicated location string.
    my $retVal = $contig . "_" . ($dir eq '+' ? $min : $max) . $dir .
                ($max + 1 - $min);
    # Return the result.
    return $retVal;
}

=head3 by_fig_id

    my @sorted_by_fig_id = sort { by_fig_id($a,$b) } @fig_ids;

Compare two feature IDs.

This function is designed to assist in sorting features by ID. The sort is by
genome ID followed by feature type and then feature number.

=over 4

=item a

First feature ID.

=item b

Second feature ID.

=item RETURN

Returns a negative number if the first parameter is smaller, zero if both parameters
are equal, and a positive number if the first parameter is greater.

=back

=cut

sub by_fig_id {
    my($a,$b) = @_;
    my($g1,$g2,$t1,$t2,$n1,$n2);
    if (($a =~ /^fig\|(\d+\.\d+).([^\.]+)\.(\d+)$/) && (($g1,$t1,$n1) = ($1,$2,$3)) &&
         ($b =~ /^fig\|(\d+\.\d+).([^\.]+)\.(\d+)$/) && (($g2,$t2,$n2) = ($1,$2,$3))) {
        ($g1 <=> $g2) or ($t1 cmp $t2) or ($n1 <=> $n2);
    } else {
        $a cmp $b;
    }
}

=head3 create_fasta_record

    my $fastaString = create_fasta_record($id, $comment, $sequence, $stripped);

Create a FASTA record from the specified DNA or protein sequence. The
sequence will be split into 60-character lines, and the record will
include an identifier line.

=over 4

=item id

ID for the sequence, to be placed at the beginning of the identifier
line.

=item comment (optional)

Comment text to place after the ID on the identifier line. If this parameter
is empty, undefined, or 0, no comment will be placed.

=item sequence

Sequence of letters to form into FASTA. For purposes of convenience, whitespace
characters in the sequence will be removed automatically.

=item stripped (optional)

If TRUE, then the sequence will be returned unmodified instead of converted
to FASTA format. The default is FALSE.

=item RETURN

Returns the desired sequence in FASTA format.

=back

=cut

sub create_fasta_record {
    # Get the parameters.
    my ($id, $comment, $sequence, $stripped) = @_;
    # Declare the return variable.
    my $retVal;
    # If we're in stripped mode, we just return the sequence.
    if ($stripped) {
        $retVal = $sequence;
    } else {
        # Here we have to do the FASTA conversion. Start with the ID.
        my $header = ">$id";
        # Add a comment, if any.
        if ($comment) {
            $header .= " $comment";
        }
        # Clean up the sequence.
        $sequence =~ s/\s+//g;
        # We need to format the sequence into 60-byte chunks. We use the infamous
        # grep-split trick. The split, because of the presence of the parentheses,
        # includes the matched delimiters in the output list. The grep strips out
        # the empty list items that appear between the so-called delimiters, since
        # the delimiters are what we want.
        my @chunks = grep { $_ } split /(.{1,60})/, $sequence;
        # Add the chunks and the trailer.
        $retVal = join("\n", $header, @chunks) . "\n";
    }
    # Return the result.
    return $retVal;
}

=head3 display_id_and_seq

    SeedUtils::display_id_and_seq($id_and_comment, $seqP, $fh);

Display a fasta ID and sequence to the specified open file. This method is designed
to work well with L</read_fasta_sequence> and L</rev_comp>, because it takes as
input a string pointer rather than a string. If the file handle is omitted it
defaults to STDOUT.

The output is formatted into a FASTA record. The first line of the output is
preceded by a C<< > >> symbol, and the sequence is split into 60-character
chunks displayed one per line. Thus, this method can be used to produce
FASTA files from data gathered by the rest of the system.

=over 4

=item id_and_comment

The sequence ID and (optionally) the comment from the sequence's FASTA record.
The ID

=item seqP

Reference to a string containing the sequence. The sequence is automatically
formatted into 60-character chunks displayed one per line.

=item fh

Open file handle to which the ID and sequence should be output. If omitted,
C<\*STDOUT> is assumed.

=back

=cut

sub display_id_and_seq {
    
    my( $id, $seqP, $fh ) = @_;

    if (! defined($fh) )  { $fh = \*STDOUT; }

    print $fh ">$id\n";
    &display_seq($seqP, $fh);
}

=head3 display_seq

    SeedUtils::display_seq(\$seqP, $fh);

Display a fasta sequence to the specified open file. If the file handle is
omitted it defaults to STDOUT.

The sequence is split into 60-character chunks displayed one per line for
readability.

=over 4

=item seqP

Reference to a string containing the sequence.

=item fh

Open file handle to which the sequence should be output. If omitted,
C<STDOUT> is assumed.

=back

=cut

sub display_seq {

    my ( $seqP, $fh ) = @_;
    my ( $i, $n, $ln );

    if (! defined($fh) )  { $fh = \*STDOUT; }

    $n = length($$seqP);
#   confess "zero-length sequence ???" if ( (! defined($n)) || ($n == 0) );
    for ($i=0; ($i < $n); $i += 60) {
        if (($i + 60) <= $n) {
            $ln = substr($$seqP,$i,60);
        } else {
            $ln = substr($$seqP,$i,($n-$i));
        }
        print $fh "$ln\n";
    }
}

=head3 extract_seq
    
 $seq = &SeedUtils::extract_seq($contigs,$loc)

This is just a little utility routine that I have found convenient.  It assumes that
$contigs is a hash that contains IDs as keys and sequences as values.  $loc must be of the
form

       Contig_Beg_End

where Contig is the ID of one of the sequences; Beg and End give the coordinates of the sought
subsequence.  If Beg > End, it is assumed that you want the reverse complement of the subsequence.
This routine plucks out the subsequence for you.

=cut

sub extract_seq {
    my($contigs,$loc) = @_;
    my($contig,$beg,$end,$contig_seq);
    my($plus,$minus);

    $plus = $minus = 0;
    my $strand = "";
    my @loc = split(/,/,$loc);
    my @seq = ();
    foreach $loc (@loc)
    {
        if ($loc =~ /^\S+_(\d+)_(\d+)$/)
        {
            if ($1 < $2)
            {
                $plus++;
            }
            elsif ($2 < $1)
            {
                $minus++;
            }
        }
    }
    if ($plus > $minus)
    {
        $strand = "+";
    }
    elsif ($plus < $minus)
    {
        $strand = "-";
    }

    foreach $loc (@loc)
    {
        if ($loc =~ /^(\S+)_(\d+)_(\d+)$/)
        {
            ($contig,$beg,$end) = ($1,$2,$3);

            my $len = length($contigs->{$contig});
            if (!$len)
            {
                carp "Undefined or zero-length contig $contig";
                return "";
            }

            if (($beg > $len) || ($end > $len))
            {
                carp "Region $loc out of bounds (contig len=$len)";
            }
            else
            {
                if (($beg < $end) || (($beg == $end) && ($strand eq "+")))
                {
                    push(@seq,substr($contigs->{$contig},$beg-1,($end+1-$beg)));
                }
                else
                {
                    $strand = "-";
                    push(@seq,&reverse_comp(substr($contigs->{$contig},$end-1,($beg+1-$end))));
                }
            }
        }
    }
    return join("",@seq);
}



=head3 file_read

    my $text = $fig->file_read($fileName);

or

    my @lines = $fig->file_read($fileName);

or

    my $text = FIG::file_read($fileName);

or

    my @lines = FIG::file_read($fileName);

Read an entire file into memory. In a scalar context, the file is returned
as a single text string with line delimiters included. In a list context, the
file is returned as a list of lines, each line terminated by a line
delimiter. (For a method that automatically strips the line delimiters,
use C<Tracer::GetFile>.)

=over 4

=item fileName

Fully-qualified name of the file to read.

=item RETURN

In a list context, returns a list of the file lines. In a scalar context, returns
a string containing all the lines of the file with delimiters included.

=back

=cut

#: Return Type $;
#: Return Type @;
sub file_read {

    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my($fileName) = @_;
    return file_head($fileName, '*');

}


=head3 file_head

    my $text = $fig->file_head($fileName, $count);

or

    my @lines = $fig->file_head($fileName, $count);

or

    my $text = FIG::file_head($fileName, $count);

or

    my @lines = FIG::file_head($fileName, $count);

Read a portion of a file into memory. In a scalar context, the file portion is
returned as a single text string with line delimiters included. In a list
context, the file portion is returned as a list of lines, each line terminated
by a line delimiter.

=over 4

=item fileName

Fully-qualified name of the file to read.

=item count (optional)

Number of lines to read from the file. If omitted, C<1> is assumed. If the
non-numeric string C<*> is specified, the entire file will be read.

=item RETURN

In a list context, returns a list of the desired file lines. In a scalar context, returns
a string containing the desired lines of the file with delimiters included.

=back

=cut

#: Return Type $;
#: Return Type @;
sub file_head {

    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my($file, $count) = @_;

    my ($n, $allFlag);
    if ($count eq '*') {
        $allFlag = 1;
        $n = 0;
    } else {
        $allFlag = 0;
        $n = (!$count ? 1 : $count);
    }

    if (open(my $fh, "<$file")) {
        my(@ret, $i);
        $i = 0;
        while (<$fh>) {
            push(@ret, $_);
            $i++;
            last if !$allFlag && $i >= $n;
        }
        close($fh);
        if (wantarray) {
            return @ret;
        } else {
            return join("", @ret);
        }
    }
}



=head3 genome_of

    my $genomeID = genome_of($fid);

Return the Genome ID embedded in the specified FIG feature ID.

=over 4

=item fid

Feature ID of interest.

=item RETURN

Returns the genome ID in the middle portion of the FIG feature ID. If the
feature ID is invalid, this method returns an undefined value.

=back

=cut

sub genome_of {
    # Get the parameters.
    my ($fid) = @_;
    # Declare the return variable.
    my $retVal;
    # Parse the feature ID.
    if ($fid =~ /^fig\|(\d+\.\d+)\./) {
        $retVal = $1;
    }
    # Return the result.
    return $retVal;
}

=head3 hypo

    my $flag = hypo($func);

Return TRUE if the specified functional role is hypothetical, else FALSE.
Hypothetical functional roles are identified by key words in the text,
such as I<hypothesis>, I<predicted>, or I<glimmer> (among others).

=over 4

=item func

Text of the functional role whose nature is to be determined.

=item RETURN

Returns TRUE if the role is hypothetical, else FALSE.

=back

=cut

sub hypo {
    my ($func) = @_;
    if (! $func)                             { return 1 }
    $func =~ s/\s*\#.*$//;
    if ($func =~ /lmo\d+ protein/i)          { return 1 }
    if ($func =~ /hypoth/i)                  { return 1 }
    if ($func =~ /conserved protein/i)       { return 1 }
    if ($func =~ /gene product/i)            { return 1 }
    if ($func =~ /interpro/i)                { return 1 }
    if ($func =~ /B[sl][lr]\d/i)             { return 1 }
    if ($func =~ /^U\d/)                     { return 1 }
    if ($func =~ /^orf[^_]/i)                { return 1 }
    if ($func =~ /uncharacterized/i)         { return 1 }
    if ($func =~ /pseudogene/i)              { return 1 }
    if ($func =~ /^predicted/i)              { return 1 }
    if ($func =~ /AGR_/)                     { return 1 }
    if ($func =~ /similar to/i)              { return 1 }
    if ($func =~ /similarity/i)              { return 1 }
    if ($func =~ /glimmer/i)                 { return 1 }
    if ($func =~ /unknown/i)                 { return 1 }
    if (($func =~ /domain/i) ||
        ($func =~ /^y[a-z]{2,4}\b/i) ||
        ($func =~ /complete/i) ||
        ($func =~ /ensang/i) ||
        ($func =~ /unnamed/i) ||
        ($func =~ /EG:/) ||
        ($func =~ /orf\d+/i) ||
        ($func =~ /RIKEN/) ||
        ($func =~ /Expressed/i) ||
        ($func =~ /[a-zA-Z]{2,3}\|/) ||
        ($func =~ /predicted by Psort/) ||
        ($func =~ /^bh\d+/i) ||
        ($func =~ /cds_/i) ||
        ($func =~ /^[a-z]{2,3}\d+[^:\+\-0-9]/i) ||
        ($func =~ /similar to/i) ||
        ($func =~ / identi/i) ||
        ($func =~ /ortholog of/i) ||
        ($func =~ /structural feature/i))    { return 1 }
    return 0;

}

=head3 id_url

    my $url = id_url($id);

Return the URL for a specified external gene ID.

=over 4

=item id

ID of the gene whose URL is desired.

=item RETURN

Returns a URL for displaying information about the specified gene. The structure
of the ID is used to determine the web site to which the gene belongs.

=back

=cut

sub id_url {
    # Get the parameters.
    my ($id) = @_;
    # Declare the return variable.
    my $retVal;
    # Parse the ID to determine the URL.
    if ($id =~ /^(?:ref\|)?([NXYZA]P_[0-9\.]+)$/) {
        $retVal = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=protein;cmd=search;term=$1";
    } elsif ($id =~ /^gi\|(\d+)$/) {
        $retVal = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve;db=Protein&list_uids=$1;dopt=GenPept";
    } elsif ($id =~ /^cmr\|(.+)$/) {
        $retVal = "http://cmr.jcvi.org/tigr-scripts/CMR/shared/GenePage.cgi?locus=$1";
    } elsif ($id =~ /^sp\|([A-Z0-9]{6})$/) {
        $retVal = "http://us.expasy.org/cgi-bin/get-sprot-entry?$1";
    } elsif ($id =~ /^uni\|([A-Z0-9_]+?)$/) {
        $retVal = "http://www.ebi.uniprot.org/uniprot-srv/uniProtView.do?proteinAc=$1";
    } elsif ($id =~ /^kegg\|(([a-z]{2,4}):([a-zA-Z_0-9]+))$/) {
        $retVal = "http://www.genome.ad.jp/dbget-bin/www_bget?$2+$3";
    } elsif ($id =~ /^tr\|([a-zA-Z0-9]+)$/) {
        $retVal = "http://ca.expasy.org/uniprot/$1";
    } elsif ($id =~ /^(fig\|\d+\.\d+\.\w+\.\d+)$/) {
        $retVal = "http://seed-viewer.theseed.org/?pattern=$1&page=SearchResult&action=check_search";
    }
    # Return the result.
    return $retVal;
}


=head3 location_cmp

    my $cmp = location_cmp($loc1, $loc2);

Compare two location strings (see L<SAP/Location Strings>).

The ordering principle for locations is that they are sorted first by contig ID, then by
leftmost position, in reverse order by length, and then by direction. The effect is that
within a contig, the locations are ordered first and foremost in the way they would
appear when displayed in a picture of the contig and second in such a way that embedded
locations come after the locations in which they are embedded. In the case of two
locations that represent the exact same base pairs, the forward (C<+>) location is
arbitrarily placed first.

=over 4

=item loc1

First location string to compare.

=item loc2

Second location string to compare.

=item RETURN

Returns a negative number if the B<loc1> location sorts first, a positive number if the
B<loc2> location sorts first, and zero if the two locations are the same.


=back

=cut

sub location_cmp {
    # Get the parameters.
    my ($loc1, $loc2) = @_;
    # Parse the locations.
    my ($contig1, $beg1, $strand1, $len1) = $loc1 =~ /^(.+)_(\d+)([+-])(\d+)$/;
    my $left1 = ($strand1 eq '+' ? $beg1 : $beg1 - $len1 + 1);
    my ($contig2, $beg2, $strand2, $len2) = $loc2 =~ /^(.+)_(\d+)([+-])(\d+)$/;
    my $left2 = ($strand2 eq '+' ? $beg2 : $beg2 - $len2 + 1);
    # Declare the return variable. We compare the indicative parts of the location
    # in order. Note that we sort in reverse order by length, so the last comparison
    # puts 2 before 1.
    my $retVal = ($contig1 cmp $contig2) || ($left1 <=> $left2) ||
                 ($len2 <=> $len1);
    # If everything matches to this point, check the strands.
    if (! $retVal) {
        if ($strand1 eq '+') {
            # First location is positive, so if the locations are unequal, it
            # sorts first.
            $retVal = ($strand2 eq '+' ? 0 : -1);
        } else {
            # First location is negative, so if the locations are unequal, it
            # sorts second.
            $retVal = ($strand1 eq '-' ? 0 : 1);
        }
    }
    # Return the result.
    return $retVal;
}

=head3 location_string

    my $locString = location_string($contig, $beg, $end);

Form a location string for the specified contig that starts at the
indicated begin location and stops at the indicated end location. A
single-base location will automatically be put on the forward strand.

=over 4

=item contig

ID of the contig to contain this location.

=item beg

Beginning offset of the location.

=item end

Ending offset of the location.

=item RETURN

Returns a location string (see L<SAP/Location String>) for the specified
location.

=back

=cut

sub location_string {
    # Get the parameters.
    my ($contig, $beg, $end) = @_;
    # Compute the strand and length.
    my ($strand, $len);
    if ($beg <= $end) {
        $strand = '+';
        $len = $end + 1 - $beg;
    } else {
        $strand = '-';
        $len = $beg + 1 - $end;
    }
    # Return the result.
    return $contig . "_$beg$strand$len";
}

=head3 max

    my $max = max(@nums);

Return the maximum number from all the values in the specified list.

=over 4

=item nums

List of numbers to examine.

=item RETURN

Returns the maximum numeric value from the specified parameters, or
an undefined value if an empty list is passed in.

=back

=cut

sub max {
    my ($retVal, @nums) = @_;
    for my $num (@nums) {
        if ($num > $retVal) {
            $retVal = $num;
        }
    }
    return $retVal;
}

=head3 min

    my $min = min(@nums);

Return the minimum number from all the values in the specified list.

=over 4

=item nums

List of numbers to examine.

=item RETURN

Returns the minimum numeric value from the specified parameters, or
an undefined value if an empty list is passed in.

=back

=cut

sub min {
    my ($retVal, @nums) = @_;
    for my $num (@nums) {
        if ($num < $retVal) {
            $retVal = $num;
        }
    }
    return $retVal;
}

=head3 parse_fasta_record

    my ($id, $comment, $seq) = parse_fasta_record($string);

Extract the ID, comment, and sequence from a single FASTA record. For
backward compatability, instead of a FASTA record the ID and sequence can
be specified separated by a comma. In this case, the returned comment
will be empty.

=over 4

=item string

A single FASTA record, or an ID and sequence separated by a single comma,
an unadorned sequence, a 2-element list consisting of an ID and a sequence,
or a 3-element list consisting of an ID, a comment, and a sequence.

=item RETURN

Returns a three-element list consisting of the incoming ID, the associated
comment, and the specified DNA or protein sequence. If the incoming string is
invalid, all three list elements will come back undefined. If no ID is
specified, an MD5 will be provided.

=back

=cut

sub parse_fasta_record {
    # Get the parameters.
    my ($string) = @_;
    # Declare the return variables.
    my ($id, $comment, $seq);
    # Check the type of input string.
    if (! defined $string) {
        # Do nothing if no string was passed in. This extra check prevents a
        # warning at runtime.
    } elsif ($string =~ /^>(\S+)([\t ]+[^\r\n]*)?[\r\n]+(.+)/s) {
        # Here we have a standard FASTA string.
        ($id, $comment, $seq) = ($1, $2, $3);
        # Remove white space from the sequence string.
        $seq =~ s/\s+//sg;
        # Trim front of comment.
        $comment =~ s/^s+//;
    } elsif ($string =~ /(.+?)\s*,\s*(.+)/) {
        ($id, $comment, $seq) = ($1, '', $2);
    } elsif (ref $string eq 'ARRAY') {
        # Here the data came in pre-formatted as a list reference.
        ($id, $comment, $seq) = @$string;
        # If there's no comment, we need to adjust.
        if (! defined $seq) {
            $seq = $comment;
            $comment = '';
        }
    } else {
        # Here we have only a sequence. We need to construct the ID.
        $seq = $string;
        require Digest::MD5;
        $id = "md5|" . Digest::MD5::md5_base64($seq);
        $comment = "";
    }
    # Return the results.
    return ($id, $comment, $seq);
}

=head3 parse_location

    my ($contig, $begin, $end, $strand) = parse_location($locString);

Return the contigID, start offset, and end offset for a specified
location string (see L<SAP/Location Strings>).

=over 4

=item locString

Location string to parse.

=item RETURN

Returns a four-element list containing the contig ID from the location
string, the starting offset of the location, the ending offset, and the
strand. If the location string is not valid, the values returned will be
C<undef>.

=back

=cut

sub parse_location {
    # Get the parameters.
    my ($locString) = @_;
    # Declare the return variables.
    my ($contig, $begin, $end, $strand);
    # Parse the location string.
    if ($locString =~ /^(.+)_(\d+)([+-])(\d+)$/) {
        # Pull out the contig ID, strand, and begin location.
        $contig = $1;
        $begin = $2;
        $strand = $3;
        # Compute the ending location from the direction and length.
        if ($3 eq '+') {
            $end = $begin + $4 - 1;
        } else {
            $end = $begin - $4 + 1;
        }
    }
    elsif ($locString =~ /^(.*)_(\d+)_(\d+)$/)
    {
	$contig = $1;
	$begin = $2;
	$end = $3;
	$strand = $begin < $end ? "+" : "-";
    }

    # Return the results.
    return ($contig, $begin, $end, $strand);
}

=head3 rev_comp

    my $revcmp = rev_comp($dna);

or

    rev_comp(\$dna);

Return the reverse complement of a DNA string.

=over 4

=item dna

Either a DNA string, or a reference to a DNA string.

=item RETURN

If the input is a DNA string, returns the reverse complement. If the
input is a reference to a DNA string, the string itself is reverse
complemented.

=back

=cut

sub rev_comp {
    # Get the parameters.
    my ($dna) = @_;
    # Determine how we were called.
    my ($retVal, $refMode);
    if (! ref $dna) {
        $retVal = reverse $dna;
        $refMode = 0;
    } else {
        $retVal = reverse $$dna;
        $refMode = 1;
    }
    # Now $retVal contains the reversed DNA string, and $refMode is TRUE iff the
    # user passed in a reference. The following translation step complements the
    # string.
    $retVal =~ tr/acgtumrwsykbdhvACGTUMRWSYKBDHV/tgcaakywsrmvhdbTGCAAKYWSRMVHDB/;
    # Return the result in the method corresponding to the way it came in.
    if ($refMode) {
        $$dna = $retVal;
        return;
    } else {
        return $retVal;
    }
}

# Synonym of rev_comp, for backward compatibility.
sub reverse_comp {
    return rev_comp($_[0]);
}

=head3 roles_for_loading

    my ($roles, $errors) = SeedUtils::roles_for_loading($function);

Split a functional assignment into roles. If the functional assignment
seems suspicious, it will be flagged as invalid. A count will be returned
of the number of roles that are rejected because they are too long.

=over 4

=item function

Functional assignment to parse.

=item RETURN

Returns a two-element list. The first is either a reference to a list of
roles, or an undefined value (indicating a suspicious functional assignment).
The second is the number of roles that are rejected for being too long.

=back

=cut

sub roles_for_loading {
    # Get the parameters.
    my ($function) = @_;
    # Declare the return variables.
    my ($roles, $errors) = (undef, 0);
    # Only proceed if there are no suspicious elements in the functional assignment.
    if (! ($function =~ /\b(?:similarit|blast\b|fasta|identity)|%|E=/i)) {
        # Initialize the return list.
        $roles = [];
        # Split the function into roles.
        my @roles = roles_of_function($function);
        # Keep only the good roles.
        for my $role (@roles) {
            if (length($role) > 250) {
                $errors++;
            } else {
                push @$roles, $role;
            }
        }
    }
    # Return the results.
    return ($roles, $errors);
}


=head3 roles_of_function

    my @roles = roles_of_function($assignment);

Return a list of the functional roles in the specified assignment string.
A single assignment may contain multiple roles as well as comments; this
method separates them out.

=over 4

=item assignment

Functional assignment to parse for roles.

=item RETURN

Returns a list of the individual roles in the assignment.

=back

=cut

sub roles_of_function {
    # Get the parameters.
    my ($assignment) = @_;
    # Remove any comment.
    my $commentFree = ($assignment =~ /(.+?)\s*[#!]/ ? $1 : $assignment);
    # Split out the roles.
    my @retVal = split /\s+[\/@]\s+|\s*;\s+/, $commentFree;
    # Return the result.
    return @retVal;
}

=head3 sims

    my @sims = sims($id, $maxN, $maxP, 'fig');
    
or

    my @sims = sims($id, $maxN, $maxP, 'all);


Retrieve similarities from the network similarity server. The similarity retrieval
is performed using an HTTP user agent that returns similarity data in multiple
chunks. An anonymous subroutine is passed to the user agent that parses and
reformats the chunks as they come in. The similarites themselves are returned
as B<Sim> objects. Sim objects are actually list references with 15 elements.
The Sim object methods allow access to the elements by name.

Similarities can be either raw or expanded. The raw similarities are basic
hits between features with similar DNA. Expanding a raw similarity drags in any
features considered substantially identical. So, for example, if features B<A1>,
B<A2>, and B<A3> are all substatially identical to B<A>, then a raw similarity
B<[C,A]> would be expanded to B<[C,A] [C,A1] [C,A2] [C,A3]>.

=over 4

=item id

ID of the feature whose similarities are desired, or reference to a list
of the IDs of the features whose similarities are desired.

=item maxN (optional)

Maximum number of similarities to return for each incoming feature.

=item maxP (optional)

The maximum allowable similarity score.

=item select (optional)

Selection criterion: C<raw> means only raw similarities are returned; C<fig>
means only similarities to FIG features are returned; C<all> means all expanded
similarities are returned; and C<figx> means similarities are expanded until the
number of FIG features equals the maximum.

=item max_expand (optional)

The maximum number of features to expand.

=item filters (optional)

Reference to a hash containing filter information, or a subroutine that can be
used to filter the sims.

=item RETURN

Returns a list of L<Sim> objects.

=back

=cut

sub sims {
    # Get the parameters.
    my($id, $maxN, $maxP, $select, $max_expand, $filters) = @_;
    # Get the URL for submitting to the sims server.
    my $url = $FIG_Config::sim_server_url || "http://bioseed.mcs.anl.gov/simserver/perl/sims.pl";
    # Get a list of the IDs to process.
    my @ids;
    if (ref($id) eq "ARRAY") {
        @ids = @$id;
    } else {
        @ids = ($id);
    }
    # Form a list of the parameters to pass to the server.
    my %args = ();
    $args{id} = \@ids;
    $args{maxN} = $maxN if defined($maxN);
    $args{maxP} = $maxP if defined($maxP);
    $args{select} = $select if defined($select);
    $args{max_expand} = $max_expand if defined($max_expand);
    # If the filter is a hash, put the filters in the argument list.
    if (ref($filters) eq 'HASH') {
        for my $k (keys(%$filters))
        {
            $args{"filter_$k"}= $filters->{$k};
        }
    }
    # Get the user agent.
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new();
    # Insure we have the Sim module.
    require Sim;
    #
    # Our next task is to create the anonymous subroutine that will process the
    # chunks that come back from the server. We require three global variables:
    # @sims to hold the similarities found, $tail to remember the unprocessed
    # data from the previous chunk, and $chunks to count the chunks.
    #
    my @retVal;
    my $tail;
    my $chunks = 0;
    #
    # ANONYMOUS SUBROUTINE
    #
    my $cb = sub {
        eval {
            # Get the parameters.
            my ($data, $command) = @_;
            # Check for a reset command. If we get one, we discard any data
            # in progress.
            if ($command && $command eq 'reset') {
                $tail = '';
            } else {
                $chunks++;
                # Get the data to process. Note we concatenate it to the incoming
                # tail from last time.
                my $c = $tail . $data;
                # Make sure the caller hasn't messed up the new-line character.
                # FASTA readers in particular are notorious for doing things
                # like that.
                local $/ = "\n";
                # Split the input into lines.
                my @lines = split(/\n/, $c);
                # If the input does not end with a new-line, we have a partial
                # chunk and need to put it in the tail for next time. If not,
                # there is no tail for next time.
                if (substr($c, -1, 1) ne "\n") {
                    $tail = pop @lines;
                } else {
                    $tail = '';
                }
                # Loop through the lines. Note there's no need to chomp because
                # the SPLIT took out the new-line characters.
                for my $l (@lines) {
                    # Split the line into fields.
                    my @s = split(/\t/, $l);
                    # Insure we have all the fields we need.
                    if (@s >= 9) {
                        # Check to see if we've seen this SIM before.
                        my $id1 = $s[0];
                        my $id2 = $s[1];
                        # Add it to the result list.
                        push(@retVal, bless \@s, 'Sim');
                    }
                }
            }
        };
    };
    #
    #   END OF ANONYMOUS SUBROUTINE
    #
    # Now we're ready to start. Because networking is an iffy thing, we set up
    # to try our request multiple times.
    my $n_retries = 10;
    my $attempts = 0;
    # Set the timeout value, in seconds.
    $ua->timeout(180);
    # Loop until we succeed or run out of retries.
    my $done = 0;
    while (! $done && $attempts++ < $n_retries) {
        # Reset the content processor. This clears the tail.
        &$cb(undef, 'reset');
        my $resp = $ua->post($url, \%args, ':content_cb' => $cb);
        if ($resp->is_success) {
            # If the response was successful, get the content. This triggers
            # the anonymous subroutine.
            my $x = $resp->content;
            # Denote we've been successful.
            $done = 1;
        }
    }
    return @retVal;
}


=head3 genetic_code

    my $code = genetic_code();

Return a hash containing the translation of nucleotide triples to proteins.
Methods such as L</translate> can take a translation scheme as a parameter.
This method returns the translation scheme for genetic code 11 or 4,
and an error for all other cocdes. The scheme is implemented as a reference to a
hash that contains nucleotide triplets as keys and has protein letters as values.

=cut

sub genetic_code {
    my ($ncbi_genetic_code_num) = @_;
    my $code = &standard_genetic_code();

    if    (($ncbi_genetic_code_num ==  1) ||
	   ($ncbi_genetic_code_num == 11)
	   ) {
	#...Do nothing
    }
    elsif ($ncbi_genetic_code_num ==  4) {
	$code->{TGA} = 'W';
    }
    else {
	die "Sorry, only genetic codes 1, 4, and 11 are currently supported";
    }

    return $code;
}


=head3 standard_genetic_code

    my $code = standard_genetic_code();

Return a hash containing the standard translation of nucleotide triples to proteins.
Methods such as L</translate> can take a translation scheme as a parameter. This method
returns the default translation scheme. The scheme is implemented as a reference to a
hash that contains nucleotide triplets as keys and has protein letters as values.

=cut

sub standard_genetic_code {

    my $code = {};

    $code->{"AAA"} = "K";
    $code->{"AAC"} = "N";
    $code->{"AAG"} = "K";
    $code->{"AAT"} = "N";
    $code->{"ACA"} = "T";
    $code->{"ACC"} = "T";
    $code->{"ACG"} = "T";
    $code->{"ACT"} = "T";
    $code->{"AGA"} = "R";
    $code->{"AGC"} = "S";
    $code->{"AGG"} = "R";
    $code->{"AGT"} = "S";
    $code->{"ATA"} = "I";
    $code->{"ATC"} = "I";
    $code->{"ATG"} = "M";
    $code->{"ATT"} = "I";
    $code->{"CAA"} = "Q";
    $code->{"CAC"} = "H";
    $code->{"CAG"} = "Q";
    $code->{"CAT"} = "H";
    $code->{"CCA"} = "P";
    $code->{"CCC"} = "P";
    $code->{"CCG"} = "P";
    $code->{"CCT"} = "P";
    $code->{"CGA"} = "R";
    $code->{"CGC"} = "R";
    $code->{"CGG"} = "R";
    $code->{"CGT"} = "R";
    $code->{"CTA"} = "L";
    $code->{"CTC"} = "L";
    $code->{"CTG"} = "L";
    $code->{"CTT"} = "L";
    $code->{"GAA"} = "E";
    $code->{"GAC"} = "D";
    $code->{"GAG"} = "E";
    $code->{"GAT"} = "D";
    $code->{"GCA"} = "A";
    $code->{"GCC"} = "A";
    $code->{"GCG"} = "A";
    $code->{"GCT"} = "A";
    $code->{"GGA"} = "G";
    $code->{"GGC"} = "G";
    $code->{"GGG"} = "G";
    $code->{"GGT"} = "G";
    $code->{"GTA"} = "V";
    $code->{"GTC"} = "V";
    $code->{"GTG"} = "V";
    $code->{"GTT"} = "V";
    $code->{"TAA"} = "*";
    $code->{"TAC"} = "Y";
    $code->{"TAG"} = "*";
    $code->{"TAT"} = "Y";
    $code->{"TCA"} = "S";
    $code->{"TCC"} = "S";
    $code->{"TCG"} = "S";
    $code->{"TCT"} = "S";
    $code->{"TGA"} = "*";
    $code->{"TGC"} = "C";
    $code->{"TGG"} = "W";
    $code->{"TGT"} = "C";
    $code->{"TTA"} = "L";
    $code->{"TTC"} = "F";
    $code->{"TTG"} = "L";
    $code->{"TTT"} = "F";

    return $code;
}

=head3 strand_of

    my $plusOrMinus = strand_of($loc);

Return the strand (C<+> or C<->) from the specified location string.

=over 4

=item loc

Location string to parse (see L<SAP/Location Strings>).

=item RETURN

Returns C<+> if the location is on the forward strand, else C<->.

=back

=cut

sub strand_of {
    # Get the parameters.
    my ($loc) = @_;
    # Declare the return variable.
    my $retVal;
    # Parse the strand indicator from the location.
    if ($loc =~ /\d+([+-])\d+/) {
        $retVal = $1;
    }
    # Return the result.
    return $retVal;
}

=head3 strip_ec

    my $role = strip_ec($rawRole);

Strip the EC number (if any) from the specified role or functional
assignment.

=over 4

=item rawRole

Role or functional assignment from which the EC numbers are to be stripped.

=item RETURN

Returns the incoming string with any EC numbers removed. The EC numbers must
be formatted in the standard format used by the SEED (with the C<EC> prefix
and surrounding parentheses).

=back

=cut

sub strip_ec {
    # Get the parameters.
    my ($rawRole) = @_;
    # Declare the return variable.
    my $retVal = $rawRole;
    # Remove the EC numbers.
    $retVal =~ s/\s*\(EC\s+[0-9.\-]+\)//g;
    # Return the result.
    return $retVal;
}

=head3 translate

    my $aa_seq = translate($dna_seq, $code, $fix_start);

Translate a DNA sequence to a protein sequence using the specified genetic code.
If I<$fix_start> is TRUE, will translate an initial C<TTG> or C<GTG> code to
C<M>. (In the standard genetic code, these two combinations normally translate
to C<V> and C<L>, respectively.)

=over 4

=item dna_seq

DNA sequence to translate. Note that the DNA sequence can only contain
known nucleotides.

=item code

Reference to a hash specifying the translation code. The hash is keyed by
nucleotide triples, and the value for each key is the corresponding protein
letter. If this parameter is omitted, the L</standard_genetic_code> will be
used.

=item fix_start

TRUE if the first triple is to get special treatment, else FALSE. If TRUE,
then a value of C<TTG> or C<GTG> in the first position will be translated to
C<M> instead of the value specified in the translation code.

=item RETURN

Returns a string resulting from translating each nucleotide triple into a
protein letter.

=back

=cut

#: Return Type $;
sub translate {

    my( $dna,$code,$start ) = @_;
    my( $i,$j,$ln );
    my( $x,$y );
    my( $prot );
    
    if (! defined($code)) {
        $code = &standard_genetic_code;
    }
    $ln = length($dna);
    $prot = "X" x ($ln/3);
    $dna =~ tr/a-z/A-Z/;

    for ($i=0,$j=0; ($i < ($ln-2)); $i += 3,$j++) {
        $x = substr($dna,$i,3);
        if ($y = $code->{$x}) {
            substr($prot,$j,1) = $y;
        }
    }

    if (($start) && ($ln >= 3) && (substr($dna,0,3) =~ /^[GT]TG$/)) {
        substr($prot,0,1) = 'M';
    }
    return $prot;
}

=head3 type_of

    my $type = SeedUtils::type_of($fid);

Return the type of a feature, given a FIG feature ID (e.g. C<fig|100226.1.peg.3361>).

=over 4

=item fid

ID of a feature whose type is desired.

=item RETURN

Returns the type of the feature (e.g. C<peg>, C<rna>, ...).

=back

=cut

sub type_of {
    # Get the parameter.
    my ($fid) = @_;
    # Declare the return variable. We return undefined if the ID is unparseable.
    my $retVal;
    # Parse the FIG ID.
    if ($fid =~ /fig\|\d+\.\d+\.(\w+)\./) {
        # Save the type segment.
        $retVal = $1;
    }
    # Return the result.
    return $retVal;
}


=head3 verify_dir

    verify_dir($dirName);

Insure that the specified directory exists. If the directory does not
exist, it will be created.

=over 4

=item dirName

Name of the relevant directory.

=back

=cut

sub verify_dir {
    # Get the parameters.
    my ($dirName) = @_;
    # Strip off the final slash, if any.
    $dirName =~ s#/$##;
    # Only proceed if the directory does NOT already exist.
    if (! -d $dirName) {
        # If there is a parent directory, recursively insure it is there.
        if ($dirName =~ m#(.+)/[^/]+$#) {
            verify_dir($1);
        }
        # Create this particular directory with full permissions.
        mkdir $dirName, 0777;
    }
}

=head3 validate_fasta_file

    $sequence_type = validate_fasta_file($in_file, $out_file)
    
Ensure the given file is in valid fasta format. If $out_file
is given, write the data to $out_file as a normalized fasta file
(with cleaned up line endings, upper case data).

If successful, returns the string "dna" or "protein".

Will invoke die() on failure; call inside eval{} to ensure full error catching.

=cut

sub validate_fasta_file
{
    my($file, $norm) = @_;

    my($input_fh, $clean_fh);
    
    if ($file =~ /\.gz$/)
    {
	open($input_fh, "-|", "gunzip", "-c", $file) or die "cannot unzip $file: $!";
    }
    else
    {
	open($input_fh, "<", $file) or die "cannot open $file: $!";
    }

    if ($norm)
    {
	open($clean_fh, ">", $norm) or die "cannot write normalized file $norm: $!";
    }

    my $state = 'expect_header';
    my $cur_id;
    my $dna_chars;
    my $prot_chars;
    
    while (<$input_fh>)
    {
	chomp;
	
	if ($state eq 'expect_header')
	{
	    if (/^>(\S+)/)
	    {
		$cur_id = $1;
		$state = 'expect_data';
		print $clean_fh ">$cur_id\n" if $clean_fh;
		next;
	    }
	    else
	    {
		die "Invalid fasta: Expected header at line $.\n";
	    }
	}
	elsif ($state eq 'expect_data')
	{
	    if (/^>(\S+)/)
	    {
		$cur_id = $1;
		$state = 'expect_data';
		print $clean_fh ">$cur_id\n" if $clean_fh;
		next;
	    }
	    elsif (/^([acgtumrwsykbdhvn]*)\s*$/i)
	    {
		print $clean_fh uc($1) . "\n" if $clean_fh;
		$dna_chars += length($1);
		next;
	    }
	    elsif (/^([*abcdefghijklmnopqrstuvwxyz]*)\s*$/i)
	    {
		print $clean_fh uc($1) . "\n" if $clean_fh;
		$prot_chars += length($1);
		next;
	    }
	    else
	    {
		my $str = $_;
		if (length($_) > 100)
		{
		    $str = substr($_, 0, 50) . " [...] " . substr($_, -50);
		}
		die "Invalid fasta: Bad data at line $.\n$str\n";
	    }
	}
	else
	{
	    die "Internal error: invalid state $state\n";
	}
    }
    close($input_fh);
    close($clean_fh) if $clean_fh;

    my $what = ($prot_chars > 0) ? "protein" : "dna";

    return $what;
}

sub strip_func {
        my($func) = @_;

        $func =~ s/^FIG\d{6}[^:]*:\s*//;
        $func =~ s/\s*\#.*$//;
        return($func);
}

sub strip_func_comment {
        my($func) = @_;

        $func =~ s/\s*\#.*$//;
        return($func);
}

sub verify_db {
    my($db,$type) = @_;

    #
    # Find formatdb; if we're operating in a SEED environment
    # use it from there.
    #

    my $path = '';
    if ($FIG_Config::blastbin ne '' && -d $FIG_Config::blastbin)
    {
	$path = "$FIG_Config::blastbin/";
    }
    elsif ($FIG_Config::ext_bin ne '' && -d $FIG_Config::ext_bin)
    {
	$path = "$FIG_Config::ext_bin/";
    }
    

    my @cmd;
    if ($type =~ /^p/i)
    {
	if ((! -s "$db.psq") || (-M "$db.psq" > -M $db))
	{
	    @cmd = ("${path}formatdb", "-p", "T", "-i", $db);
	}
    }
    else
    {
	if ((! -s "$db.nsq") || (-M "$db.nsq" > -M $db))
	{
	    @cmd = ("${path}formatdb", "-p", "F", "-i", $db);
	}
    }
    if (@cmd)
    {
	my $rc = system(@cmd);
	if ($rc != 0)
	{
	    warn "SeedUtils::verify_db: formatdb failed with rc=$rc: @cmd\n";
	}
    }
}

#
# Some berkeley-db building utilities.
#

sub create_berk_table
{
    my($input_file, $key_columns, $value_columns, $db_file, %opts) = @_;

    local $DB_BTREE->{flags};
    if ($opts{-multiple_values})
    {
	$DB_BTREE->{flags} = R_DUP;
    }
    
    my $ifh;

    if ($opts{-sort})
    {
	my $sk = join(" ", map { "-k " . ($_ + 1) } @$key_columns);
	my $cmd = "sort $sk $input_file";
	print "Run $cmd\n";
	
	open($ifh, "$cmd |") or die "Cannot open sort $sk $input_file for reading: $!";
    }
    else
    {
	open($ifh, "<", $input_file) or die "Cannot open $input_file for reading: $!";
    }

    my $hash = {};
    my $tie = tie %$hash, "DB_File", $db_file, O_RDWR | O_CREAT, 0666, $DB_BTREE;
    $tie or die "Cannot create $db_file: $!";

    while (<$ifh>)
    {
	chomp;
	my @a = split(/\t/);
	my $k = join($;, @a[@$key_columns]);
	my $v = join($;, @a[@$value_columns]);

	$hash->{$k} = $v;
    }
    close($ifh);
    undef $hash;
    untie $tie;
}

sub open_berk_table
{
    my($table, %opts) = @_;

    if (! -f $table)
    {
	warn "Cannot read table file $table\n";
	return undef;
    }
    my $h = {};
    tie %$h, 'BerkTable', $table, %opts;
    return $h;
}

our $AllColors;

sub compare_region_color
{
    my($n) = @_;
    my $nc = @$AllColors;
    my $c = $AllColors->[$n % $nc];
    return split(/-/, $c);
}

$AllColors =
        [
          '255-0-0',      # red
          '0-255-0',      # green
          '0-0-255',      # blue
          '255-64-192',
          '255-128-64',
          '255-0-128',
          '255-192-64',
          '64-192-255',
          '64-255-192',
          '192-128-128',
          '192-255-0',
          '0-255-128',
          '0-192-64',
          '128-0-0',
          '255-0-192',
          '64-0-128',
          '128-64-64',
          '64-255-0',
          '128-0-64',
          '128-192-255',
          '128-192-0',
          '64-0-0',
          '128-128-0',
          '255-192-255',
          '128-64-255',
          '64-0-192',
          '0-64-64',
          '64-0-255',
          '192-64-255',
          '128-0-128',
          '192-255-64',
          '64-128-255',
          '255-128-192',
          '64-192-64',
          '0-128-128',
          '255-0-64',
          '128-64-0',
          '128-255-128',
          '255-64-128',
          '128-192-64',
          '128-128-64',
          '255-255-192',
          '192-192-128',
          '192-64-128',
          '64-128-192',
          '192-192-64',
          '192-0-128',
          '64-64-192',
          '0-128-192',
          '0-128-64',
          '255-192-128',
          '192-128-0',
          '64-255-255',
          '255-0-255',
          '128-255-255',
          '255-255-64',
          '0-128-0',
          '192-255-192',
          '0-192-0',
          '0-64-192',
          '0-64-128',
          '192-0-255',
          '192-192-255',
          '64-255-128',
          '0-0-128',
          '255-64-64',
          '192-192-0',
          '192-128-192',
          '128-64-192',
          '0-192-255',
          '128-192-192',
          '192-0-64',
          '192-255-255',
          '255-192-0',
          '255-255-128',
          '192-0-0',
          '64-64-0',
          '192-64-192',
          '192-128-255',
          '128-255-192',
          '64-64-255',
          '0-64-255',
          '128-64-128',
          '255-64-255',
          '192-128-64',
          '64-64-128',
          '0-128-255',
          '64-0-64',
          '128-0-192',
          '255-128-255',
          '64-128-0',
          '255-64-0',
          '64-192-192',
          '255-128-0',
          '0-0-64',
          '128-128-192',
          '128-128-255',
          '0-192-192',
          '0-255-192',
          '128-192-128',
          '192-0-192',
          '0-255-64',
          '64-192-0',
          '0-192-128',
          '128-255-64',
          '255-255-0',
          '64-255-64',
          '192-64-64',
          '192-64-0',
          '255-192-192',
          '192-255-128',
          '0-64-0',
          '0-0-192',
          '128-0-255',
          '64-128-64',
          '64-192-128',
          '0-255-255',
          '255-128-128',
          '64-128-128',
          '128-255-0'
        ];

sub run {
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
    my($cmd) = @_;

    if ($ENV{FIG_VERBOSE}) {
        my @tmp = `date`;
        chomp @tmp;
        print STDERR "$tmp[0]: running $cmd\n";
    }
    (system($cmd) == 0) || die("FAILED: $cmd");
}

sub map_to_families
{
    my($fam2c, $func) = @_;

    my $fh;

    if (ref($fam2c))
    {
	$fh = $fam2c;
    }
    else
    {
	if (!open($fh, "<", $fam2c))
	{
	    die "Cannot open $fam2c: $!";
	}
    }
    $_ = <$fh>;
    chomp;
    my($fam, $peg) = split(/\t/);
    while (defined($fam))
    {
	my $cur = $fam;
	my @set;
	while (defined($fam) && $fam eq $cur)
	{
	    push(@set, $peg);
	    $_ = <$fh>;
	    chomp;
	    ($fam, $peg) = split(/\t/);
	}
	$func->($cur, \@set);
    }
	 
}


1;
