#!/usr/bin/perl -w
use strict;

#!/usr/bin/perl -w
#
#	This is a SAS Component.
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

package ScriptThing;

=head1 Script Utilities Package

This is a simple package containing utility methods of use to the server scripts.

=head2 Public Methods

=head3 GetBatch

    my @lines = ScriptThing::GetBatch($ih, $size);

Get a batch of work to do. The specified input stream will be read, and a
list of IDs pulled out, along with the contents of the input lines on
which the IDs were found. The input stream can be an open file handle or a
list of singleton values to return.

=over 4

=item ih

Open input file handle, or alternatively a reference to a list of values to return.
If a list is specified, the items will be removed from the list as they are returned.

=item size (optional)

Maximum permissible batch size. If omitted, the default is C<1000>.

=item column (optional)

Index (1-based) of the column containing the IDs. The default is the last
column.

=item RETURN

Returns a list of 2-tuples; each 2-tuple consists of an ID followed by the text
of the input line containing the ID (with the trailing new-line removed).

=back

=cut

sub GetBatch {
    # Get the parameters.
    my ($ih, $size, $column) = @_;
    # Declare the return variable.
    my @retVal;
    # Compute the batch size.
    my $linesLeft = $size || 1000;
    # Determine the mode in which we're operating.
    if (ref $ih eq 'ARRAY') {
        # Here we have a list reference. Loop through it until we run out or fill
        # the batch.
        while ($linesLeft-- > 0 && @$ih > 0) {
            # Get the next list entry.
            my $id = shift @$ih;
            # Put it in the return list as the desired ID and the line it appeared on.
            push @retVal, [$id, $id];
        }
    } else {
        # Loop through the input until we run out or fill the batch.
        while ($linesLeft-- > 0 && ! eof $ih) {
            # Get the next input line.
            my $line = <$ih>;
            chomp $line;
            # Only proceed if it's nonblank.
            if ($line =~ /\S/) {
                # We'll put our desired column in here.
                my $id = GetColumn($line, $column);
                # Put it in the return list.
                push @retVal, [$id, $line];
            }
        }
    }
    # Return the result.
    return @retVal;
}

=head3 GetList

    my @list = ScriptThing::GetList($ih, $column);

Extract a list of data items from a tab-delimited file. Unlike L</GetBatch>,
this method reads the entire file, and it only returns the column of interest
instead of tuples containing the original data lines.

=over 4

=item ih

Open file handle for the input.

=item column (optional)

Index (1-based) of the column containing the IDs. The default is the last
column.

=item RETURN

Returns a list containing the contents of the desired column for every record
in the input stream.

=back

=cut

sub GetList {
    # Get the parameters.
    my ($ih, $column) = @_;
    # Declare the return variable.
    my @retVal;
    # Loop through the input.
    while (! eof $ih) {
        # Get the next input line.
        my $line = <$ih>;
        chomp $line;
        # We'll put our desired column in here.
        my $id = GetColumn($line, $column);
        # Put it in the return list.
        push @retVal, $id;
    }
    # Return the list.
    return @retVal;
}

=head3 GetColumn

    my $id = ScriptThing::GetColumn($line, $column);

Get the specified column from a tab-delimited input line.

=over 4

=item line

A tab-delimited line of text.

=item column

The index (1-based) of the column whose value is desired. If undefined or 0,
then the last column will be extracted.

=item RETURN

Returns the value of the desired column. Note that if it is the last column, no
trimming of new-line characters will take place.

=back

=cut

sub GetColumn {
    # Get the parameters.
    my ($line, $column) = @_;
    # Declare the return variable.
    my $retVal;
    # Are we looking for a specific column or the last one?
    if ($column) {
        # We want a specific column.
        my @cols = split /\t/, $line;
        $retVal = $cols[$column - 1];
    } else {
        # We want the last column.
        if ($line =~ /.*\t(.+)$/) {
            $retVal = $1;
        } else {
            $retVal = $line;
        }
    }
    # Return the result.
    return $retVal;
}

=head3 CommentHash

    my %hash = ScriptThing::CommentHash(\@tuples, $column);

Convert the 2-tuples returned by L</GetBatch> to a comment hash for
FASTA-based methods. The return hash will map each incoming ID to a
string containing the fields from the corresponding line.

=over 4

=item tuples

Reference to a list of 2-tuples. Each 2-tuple contains an ID followed by a
tab-delimited input line (without the new-line character).

=item column

Index (1-based) of the column containing the ID value. The default is the last
column.

=item RETURN

Returns a hash mapping each incoming ID to the text from its input line.

=back

=cut

sub CommentHash {
    # Get the parameters.
    my ($tuples, $column) = @_;
    # Declare the return variable.
    my %retVal;
    # Loop through the tuples.
    for my $tuple (@$tuples) {
        # Get the ID and line.
        my ($id, $line) = @$tuple;
        # Split the line and pop off the ID.
        my @fields = split /\t/, $line;
        if (! $column) {
            pop @fields;
        } else {
            splice @fields, $column - 1, 1;
        }
        # Rejoin the fields with spaces in between to form the result.
        $retVal{$id} = join(" ", @fields);
    }
    # Return the result.
    return %retVal;
}


=head3 AdjustStdin

    AdjustStdin();

Check the environment for a STDIN variable, and if present, open the
named file as STDIN. This is a debugging hack that allows the scripts to
be run easily inside a symbolic debugger.

=cut

sub AdjustStdin {
    # Check for the environment variable.
    my $file = $ENV{STDIN};
    if ($file) {
        # We found it, so open STDIN using the specified file name.
        open STDIN, "<$file" || die $!;
    }
}







1;

