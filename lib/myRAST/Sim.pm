
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

=head1 Similarity Object

=head2 Introduction

The similarity object provides access by name to the fields of a similarity
list. Unlike a standard object, the similarity object is stored as a list
reference, not a hash reference. The similarity fields are pulled from the
appropriate places in the list.

A blast takes a sequence called the I<query> and matches it against a
I<database>. When describing the data in a similarity, we will
refer repeatedly to the query sequence and the database sequence. Often,
the query and database sequences will be given by peg IDs. In some cases,
however, they will be contig IDs. In both cases, the match is represented
by an alignment between portions of the sequences. Gap characters may
be required to get the alignments to match, and the number of gaps is
part of the data in the similarity.

=cut

package Sim;

=head3 as_string

    my $simString = "$sim";

or

    my $simString = $sim->as_string;

Return the similarity as a descriptive string, consisting of the query peg,
the similar peg, and the match score.

=cut

use overload '""' => \&as_string;

sub as_string {
    my ($obj) = @_;
    return sprintf("sim:%s->%s:%s:%s", $obj->id1, $obj->id2, $obj->psc, $obj->iden);
}

=head3 new_from_line

    my $sim = Sim->new_from_line($line);

Create a similarity object from a blast output line. The line is presumed to have
the complete list of similarity values in it, tab-separated.

=over 4

=item line

Input line, containing the similarity values in it delimited by tabs. A line terminator
may be present at the end.

=item RETURN

Returns a similarity object that allows the values to be accessed by name.

=back

=cut

sub new_from_line {
    my ($class, $line) = @_;
    chomp $line;
    my $self = [split(/\t/, $line)];
    return bless $self, $class;
}

=head3 validate

    my $okFlag = $sim->validate();

Return TRUE if the similarity values are valid, else FALSE.

=cut

sub validate {
    my ($self) = @_;
    return ($self->id1 ne "" and
            $self->id2 ne "" and
            $self->iden =~ /^[.\d]+$/ and
            $self->ali_ln =~ /^\d+$/ and
            $self->mismatches =~ /^\d+$/ and
            $self->gaps =~ /^\d+$/ and
            $self->b1 =~ /^\d+$/ and
            $self->e1 =~ /^\d+$/ and
            $self->b2 =~ /^\d+$/ and
            $self->e2 =~ /^\d+$/ and
            $self->psc =~ /^[-.e\d]+$/ and
            $self->bsc =~ /^[-.\d]+$/ and
            $self->ln1 =~ /^\d+$/ and
            $self->ln2 =~ /^\d+$/);
}

=head3 as_line

    my $line = $sim->as_line;

Return the similarity as an output line. This is exactly the reverse of
L</new_from_line>.

=cut

sub as_line {
    my ($self) = @_;
    return join("\t", @$self) . "\n";
}

=head3 id1

    my $id = $sim->id1;

Return the ID of the query sequence that was blasted against the database.

=cut

sub id1 {
    my ($sim) = @_;
    return $sim->[0];
}

=head3 id2

    my $id = $sim->id2;

Return the ID of the sequence in the database that matched the query sequence.

=cut

sub id2 {
    my ($sim) = @_;
    return $sim->[1];
}

sub feature2 {
    require FIGO;
    my($sim) = @_;
    my $id = $sim->[1];
    if ($id !~ /^fig\|/) { return undef }
    my $figO = new FIGO;
    return FeatureO->new($figO, $id);
}

=head3 iden

    my $percent = $sim->iden;

Return the percentage identity between the query and database sequences.

=cut

sub iden {
    my ($sim) = @_;
    return $sim->[2];
}

=head3 ali_ln

    my $chars = $sim->ali_ln;

Return the length (in characters) of the alignment between the two similar sequences.

=cut

sub ali_ln {
    my ($sim) = @_;
    return $sim->[3];
}

=head3 mismatches

    my $count = $sim->mismatches;

Return the number of alignment positions that do not match.

=cut

sub mismatches {
    my ($sim) = @_;
    return $sim->[4];
}

=head3 gaps

    my $count = $sim->gaps;

Return the number of gaps required to align the sequences.

=cut

sub gaps {
    my ($sim) = @_;
    return $sim->[5];
}

=head3 b1

    my $beginOffset = $sim->b1;

Return the position in the query sequence at which the alignment begins.

=cut

sub b1 {
    my ($sim) = @_;
    return $sim->[6];
}

=head3 e1

    my $endOffset = $sim->e1;

Return the position in the query sequence at which the alignment ends.

=cut

sub e1 {
    my ($sim) = @_;
    return $sim->[7];
}

=head3 b2

    my $beginOffset = $sim->b2;

Position in the database sequence at which the alignment begins.

=cut

sub b2 {
    my ($sim) = @_;
    return $sim->[8];
}

=head3 e2

    my $endOffset = $sim->e2;

Return the position in the database sequence at which the alignment ends.

=cut

sub e2 {
    my ($sim) = @_;
    return $sim->[9];
}

=head3 psc

    my $score = $sim->psc;

Return the similarity score as a floating-point number. The score is the computed
probability that the similarity is a result of random chance. A score of 0 indicates a
perfect match. A higher score indicates a less-perfect match. Values of C<1e-10> or
less are considered good matches.

=cut

sub psc {
    my ($sim) = @_;
    return ($sim->[10] =~ /^e-/) ? "1.0" . $sim->[10] : $sim->[10];
}

=head3 bsc

    my $score = $sim->bsc;

Return the bit score for this similarity. The bit score is an estimate of the
search space required to find the similarity by chance. A higher bit score
indicates a better match.

=cut

sub bsc {
    my ($sim) = @_;
    return $sim->[11];
}

=head3 bsc

    my $score = $sim->bit_score;

Return the bit score for this similarity. The bit score is an estimate of the
search space required to find the similarity by chance. A higher bit score
indicates a better match.

=cut

sub bit_score {
    my ($sim) = @_;
    return $sim->bsc;
}

sub nbsc {
    my($sim) = @_;

    my $min_ln = &min($sim->ln1,$sim->ln2);
    
    return $min_ln ? sprintf("%4.2f",$sim->bit_score / $min_ln) : undef;
}

sub min {
    my($x,$y) = @_;
    return ($x < $y) ? $x : $y;
}

=head3 ln1

    my $length = $sim->ln1;

Return the number of characters in the query sequence.

=cut

sub ln1 {
    my ($sim) = @_;
    return $sim->[12];
}

=head3 ln2

    my $length = $sim->ln2;

Return the length of the database sequence.

=cut

sub ln2 {
    my ($sim) = @_;
    return $sim->[13];
}

=head3 tool

    my $name = $sim->tool;

Return the name of the tool used to find this similarity.

=cut

sub tool {
    my ($sim) = @_;
    return $sim->[14];
}

sub def2 {
    my ($sim) = @_;
    return $sim->[15];
}

sub ali {
    my ($sim) = @_;
    return $sim->[16];
}

1;
