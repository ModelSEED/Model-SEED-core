# -*- perl -*-
# This is a SAS component.

package WriteGenbank;

#########################################################################
# Copyright (c) 2003-2008 University of Chicago and Fellowship
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
#########################################################################

use strict;
use warnings;


sub form_header {
    my ($contig, $contig_len, $date, $defline, $genome, $strain, $taxonomy, $taxon_ID) = @_;

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#...Build up header in the Format Accumulator...
#-------------------------------------------------------------------------------

    formline <<END, $contig, $contig_len, $date;
LOCUS       @<<<<<<<<<<<<<<<<<<<@####### bp    DNA     circular BCT @<<<<<<<<<<<
END

    formline <<END, $defline;
DEFINITION  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END

    formline <<END, $defline;
~~          ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END

    formline <<END, $genome;
ACCESSION   Unknown Unknown
VERSION     Unknown
KEYWORDS    WGS.
SOURCE      @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END

    formline <<END, $genome, $taxonomy;
  ORGANISM  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END
    formline <<END, $taxonomy;
~~          ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END

    formline <<END, $contig_len, $contig_len;
REFERENCE   1  (bases 1 to @#######)
  AUTHORS   [Insert Names here]
  TITLE     Direct Submission
  JOURNAL   [Insert paper submission information here]
COMMENT     [Insert project information here]
FEATURES             Location/Qualifiers
     source          1..@<<<<<<<
END

    &form_multiline('organism', $genome);
    &form_multiline('mol_type', 'genomic DNA');
    &form_multiline('strain', $strain) if $strain;
    &form_multiline('db_xref', "taxon:$taxon_ID");

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#...Print header and clear Format-Accumulator...
#===============================================================================
    print $^A;  $^A = ""; 
#-------------------------------------------------------------------------------
    
    return;
}



sub form_feature {
    my ($type, $locus, $ltag) = @_;
    
    $ltag = qq(\"$ltag\");
    formline <<END, $type, $locus, $ltag;
     @<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                     /locus_tag=^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END

   return;
}



sub form_multiline {
    my ($field, $text) = @_;
    
    my $tmp = "/$field=\"$text\"";
    
    formline <<END, $tmp;
                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END
	
    formline <<END, $tmp;
~~                   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END
    
    return;
}



sub write_contig {
    my ($contig_sequence_reference) = @_;
    
    my $tmp = $$contig_sequence_reference;
    
    formline <<END;
ORIGIN
END

    my $charcount = 1;
    while ($tmp)
    {
	formline <<END, $charcount, $tmp, $tmp, $tmp, $tmp, $tmp, $tmp;
@######## ^<<<<<<<<< ^<<<<<<<<< ^<<<<<<<<< ^<<<<<<<<< ^<<<<<<<<< ^<<<<<<<<<
END
        $charcount += 60;
    }
    
    print $^A;   $^A = "";
    
    return;
}

1;
