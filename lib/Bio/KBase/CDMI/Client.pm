package Bio::KBase::CDMI::Client;

use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;

=head1 NAME

Bio::KBase::CDMI::Client

=head1 DESCRIPTION



=cut

sub new
{
    my($class, $url) = @_;

    my $self = {
	client => JSON::RPC::Client->new,
	url => $url,
    };
    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);

    return bless $self, $class;
}




=head2 $result = fids_to_annotations(fids)

This routine takes as input a list of fids.  It retrieves the existing
annotations for each fid, including the text of the annotation, who
made the annotation and when (as seconds from the epoch).

=cut

sub fids_to_annotations
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_annotations",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_annotations: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_annotations: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_functions(fids)

This routine takes as input a list of fids and returns a mapping
from the fids to their assigned functions.

=cut

sub fids_to_functions
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_functions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_functions: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_functions: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_literature(fids)

We try to associate features and publications, when the publications constitute
supporting evidence of the function.  We connect a paper to a feature when
we believe that an "expert" has asserted that the function of the feature
is basically what we have associated with the feature.  Thus, we might
attach a paper reporting the crystal structure of a protein, even though
the paper is clearly not the paper responsible for the original characterization.
Our position in this matter is somewhat controversial, but we are seeking to
characterize some assertions as relatively solid, and this strategy seems to
support that goal.  Please note that we certainly wish we could also
capture original publications, and when experts can provide those
connections, we hope that they will help record the associations.

=cut

sub fids_to_literature
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_literature",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_literature: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_literature: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_protein_families(fids)

Kbase supports the creation and maintence of protein families.  Each family is intended to contain a set
of isofunctional homologs.  Currently, the families are collections of translations
of features, rather than of just protein sequences (represented by md5s, for example).
fids_to_protein_families supports access to the features that have been grouped into a family.
Ideally, each feature in a family would have the same assigned function.  This is not
always true, but probably should be.

=cut

sub fids_to_protein_families
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_protein_families",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_protein_families: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_protein_families: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_roles(fids)

Given a feature, one can get the set of roles it implements using fid_to_roles.
Remember, a protein can be multifunctional -- implementing several roles.
This can occur due to fusions or to broad specificity of substrate.

=cut

sub fids_to_roles
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_roles",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_roles: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_roles: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_subsystems(fids)

fids in subsystems normally have somewhat more reliable assigned functions than
those not in subsystems.  Hence, it is common to ask "Is this protein-encoding gene
included in any subsystems?"   fids_to_subsystems can be used to see which subsystems
contain a fid (or, you can submit as input a set of fids and get the subsystems for each).

=cut

sub fids_to_subsystems
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_subsystems",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_subsystems: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_subsystems: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_co_occurring_fids(fids)

One of the most powerful clues to function relates to conserved clusters of genes on
the chromosome (in prokaryotic genomes).  We have attempted to record pairs of genes
that tend to occur close to one another on the chromosome.  To meaningfully do this,
we need to construct similarity-based mappings between genes in distinct genomes.
We have constructed such mappings for many (but not all) genomes maintained in the
Kbase CS.  The prokaryotic geneomes in the CS are grouped into OTUs by ribosomal
RNA (genomes within a single OTU have SSU rRNA that is greater than 97% identical).
If two genes occur close to one another (i.e., corresponding genes occur close
to one another), then we assign a score, which is the number of distinct OTUs
in which such clustering is detected.  This allows one to normalize for situations
in which hundreds of corresponding genes are detected, but they all come from
very closely related genomes.

The significance of the score relates to the number of genomes in the database.
We recommend that you take the time to look at a set of scored pairs and determine
approximately what percentage appear to be actually related for a few cutoff values.

=cut

sub fids_to_co_occurring_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_co_occurring_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_co_occurring_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_co_occurring_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_locations(fids)

A "location" is a sequence of "regions".  A region is a contiguous set of bases
in a contig.  We work with locations in both the string form and as structures.
fids_to_locations takes as input a list of fids.  For each fid, a structured location
is returned.  The location is a list of regions; a region is given as a pointer to
a list containing

             the contig,
             the beginning base in the contig (from 1).
             the strand (+ or -), and
             the length

Note that specifying a region using these 4 values allows you to represent a single
base-pair region on either strand unambiguously (which giving begin/end pairs does
not achieve).

=cut

sub fids_to_locations
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_locations",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_locations: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_locations: " . $self->{client}->status_line;
    }
}



=head2 $result = locations_to_fids(region_of_dna_strings)

It is frequently the case that one wishes to look up the genes that
occur in a given region of a contig.  Location_to_fids can be used to extract
such sets of genes for each region in the input set of regions.  We define a gene
as "occuring" in a region if the location of the gene overlaps the designated region.

=cut

sub locations_to_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.locations_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking locations_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking locations_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = locations_to_dna_sequences(locations)

locations_to_dna_sequences takes as input a list of locations (each in the form of
a list of regions).  The routine constructs 2-tuples composed of

     [the input location,the dna string]

The returned DNA string is formed by concatenating the DNA for each of the
regions that make up the location.

=cut

sub locations_to_dna_sequences
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.locations_to_dna_sequences",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking locations_to_dna_sequences: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking locations_to_dna_sequences: " . $self->{client}->status_line;
    }
}



=head2 $result = proteins_to_fids(proteins)

proteins_to_fids takes as input a list of proteins (i.e., a list of md5s) and
returns for each a set of protein-encoding fids that have the designated
sequence as their translation.  That is, for each sequence, the returned fids will
be the entire set (within Kbase) that have the sequence as a translation.

=cut

sub proteins_to_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.proteins_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking proteins_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking proteins_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = proteins_to_protein_families(proteins)

Protein families contain a set of isofunctional homologs.  proteins_to_protein_families
can be used to look up is used to get the set of protein_families containing a specified protein.
For performance reasons, you can submit a batch of proteins (i.e., a list of proteins),
and for each input protein, you get back a set (possibly empty) of protein_families.
Specific collections of families (e.g., FIGfams) usually require that a protein be in
at most one family.  However, we will be integrating protein families from a number of
sources, and so a protein can be in multiple families.

=cut

sub proteins_to_protein_families
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.proteins_to_protein_families",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking proteins_to_protein_families: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking proteins_to_protein_families: " . $self->{client}->status_line;
    }
}



=head2 $result = proteins_to_literature(proteins)

The routine proteins_to_literature can be used to extract the list of papers
we have associated with specific protein sequences.  The user should note that
in many cases the association of a paper with a protein sequence is not precise.
That is, the paper may actually describe a closely-related protein (that may
not yet even be in a sequenced genome).  Annotators attempt to use best
judgement when associating literature and proteins.  Publication references
include [pubmed ID,URL for the paper, title of the paper].  In some cases,
the URL and title are omitted.  In theory, we can extract them from PubMed
and we will attempt to do so.

=cut

sub proteins_to_literature
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.proteins_to_literature",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking proteins_to_literature: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking proteins_to_literature: " . $self->{client}->status_line;
    }
}



=head2 $result = proteins_to_functions(proteins)

The routine proteins_to_functions allows users to access functions associated with
specific protein sequences.  The input proteins are given as a list of MD5 values
(these MD5 values each correspond to a specific protein sequence).  For each input
MD5 value, a list of [feature-id,function] pairs is constructed and returned.
Note that there are many cases in which a single protein sequence corresponds
to the translation associated with multiple protein-encoding genes, and each may
have distinct functions (an undesirable situation, we grant).

This function allows you to access all of the functions assigned (by all annotation
groups represented in Kbase) to each of a set of sequences.

=cut

sub proteins_to_functions
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.proteins_to_functions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking proteins_to_functions: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking proteins_to_functions: " . $self->{client}->status_line;
    }
}



=head2 $result = proteins_to_roles(proteins)

The routine proteins_to_roles allows a user to gather the set of functional
roles that are associated with specifc protein sequences.  A single protein
sequence (designated by an MD5 value) may have numerous associated functions,
since functions are treated as an attribute of the feature, and multiple
features may have precisely the same translation.  In our experience,
it is not uncommon, even for the best annotation teams, to assign
distinct functions (and, hence, functional roles) to identical
protein sequences.

For each input MD5 value, this routine gathers the set of features (fids)
that share the same sequence, collects the associated functions, expands
these into functional roles (for multi-functional proteins), and returns
the set of roles that results.

Note that, if the user wishes to see the specific features that have the
assigned fiunctional roles, they should use proteins_to_functions instead (it
returns the fids associated with each assigned function).

=cut

sub proteins_to_roles
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.proteins_to_roles",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking proteins_to_roles: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking proteins_to_roles: " . $self->{client}->status_line;
    }
}



=head2 $result = roles_to_proteins(roles)

roles_to_proteins can be used to extract the set of proteins (designated by MD5 values)
that currently are believed to implement a given role.  Note that the proteins
may be multifunctional, meaning that they may be implementing other roles, as well.

=cut

sub roles_to_proteins
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.roles_to_proteins",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking roles_to_proteins: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking roles_to_proteins: " . $self->{client}->status_line;
    }
}



=head2 $result = roles_to_subsystems(roles)

roles_to_subsystems can be used to access the set of subsystems that include
specific roles. The input is a list of roles (i.e., role descriptions), and a mapping
is returned as a hash with key role description and values composed of sets of susbsystem names.

=cut

sub roles_to_subsystems
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.roles_to_subsystems",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking roles_to_subsystems: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking roles_to_subsystems: " . $self->{client}->status_line;
    }
}



=head2 $result = roles_to_protein_families(roles)

roles_to_protein_families can be used to locate the protein families containing
features that have assigned functions implying that they implement designated roles.
Note that for any input role (given as a role description), you may have a set
of distinct protein_families returned.

=cut

sub roles_to_protein_families
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.roles_to_protein_families",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking roles_to_protein_families: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking roles_to_protein_families: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_coexpressed_fids(fids)

The routine fids_to_coexpressed_fids returns (for each input fid) a
list of features that appear to be coexpressed.  That is,
for an input fid, we determine the set of fids from the same genome that
have Pearson Correlation Coefficients (based on normalized expression data)
greater than 0.5 or less than -0.5.

=cut

sub fids_to_coexpressed_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_coexpressed_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_coexpressed_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_coexpressed_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = protein_families_to_fids(protein_families)

protein_families_to_fids can be used to access the set of fids represented by each of
a set of protein_families.  We define protein_families as sets of fids (rather than sets
of MD5s.  This may, or may not, be a mistake.

=cut

sub protein_families_to_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.protein_families_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking protein_families_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking protein_families_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = protein_families_to_proteins(protein_families)

protein_families_to_proteins can be used to access the set of proteins (i.e., the set of MD5 values)
represented by each of a set of protein_families.  We define protein_families as sets of fids (rather than sets
           of MD5s.  This may, or may not, be a mistake.

=cut

sub protein_families_to_proteins
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.protein_families_to_proteins",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking protein_families_to_proteins: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking protein_families_to_proteins: " . $self->{client}->status_line;
    }
}



=head2 $result = protein_families_to_functions(protein_families)

protein_families_to_functions can be used to extract the set of functions assigned to the fids
that make up the family.  Each input protein_family is mapped to a family function.

=cut

sub protein_families_to_functions
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.protein_families_to_functions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking protein_families_to_functions: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking protein_families_to_functions: " . $self->{client}->status_line;
    }
}



=head2 $result = protein_families_to_co_occurring_families(protein_families)

Since we accumulate data relating to the co-occurrence (i.e., chromosomal
clustering) of genes in prokaryotic genomes,  we can note which pairs of genes tend to co-occur.
From this data, one can compute the protein families that tend to co-occur (i.e., tend to
cluster on the chromosome).  This allows one to formulate conjectures for unclustered pairs, based
on clustered pairs from the same protein_families.

=cut

sub protein_families_to_co_occurring_families
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.protein_families_to_co_occurring_families",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking protein_families_to_co_occurring_families: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking protein_families_to_co_occurring_families: " . $self->{client}->status_line;
    }
}



=head2 $result = co_occurrence_evidence(pairs_of_fids)

co-occurence_evidence is used to retrieve the detailed pairs of genes that go into the
computation of co-occurence scores.  The scores reflect an estimate of the number of distinct OTUs that
contain an instance of a co-occuring pair.  This routine returns as evidence a list of all the pairs that
went into the computation.

The input to the computation is a list of pairs for which evidence is desired.

The returned output is a list of elements. one for each input pair.  Each output element
is a 2-tuple: the input pair and the evidence for the pair.  The evidence is a list of pairs of
fids that are believed to correspond to the input pair.

=cut

sub co_occurrence_evidence
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.co_occurrence_evidence",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking co_occurrence_evidence: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking co_occurrence_evidence: " . $self->{client}->status_line;
    }
}



=head2 $result = contigs_to_sequences(contigs)

contigs_to_sequences is used to access the DNA sequence associated with each of a set
of input contigs.  It takes as input a set of contig IDs (from which the genome can be determined) and
produces a mapping from the input IDs to the returned DNA sequence in each case.

=cut

sub contigs_to_sequences
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.contigs_to_sequences",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking contigs_to_sequences: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking contigs_to_sequences: " . $self->{client}->status_line;
    }
}



=head2 $result = contigs_to_lengths(contigs)

In some cases, one wishes to know just the lengths of the contigs, rather than their
actual DNA sequence (e.g., suppose that you wished to know if a gene boundary occured within
100 bp of the end of the contig).  To avoid requiring a user to access the entire DNA sequence,
we offer the ability to retrieve just the contig lengths.  Input to the routine is a list of contig IDs.
The routine returns a mapping from contig IDs to lengths

=cut

sub contigs_to_lengths
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.contigs_to_lengths",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking contigs_to_lengths: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking contigs_to_lengths: " . $self->{client}->status_line;
    }
}



=head2 $result = contigs_to_md5s(contigs)

contigs_to_md5s can be used to acquire MD5 values for each of a list of contigs.
The quickest way to determine whether two contigs are identical is to compare their
associated MD5 values, eliminating the need to retrieve the sequence of each and compare them.

The routine takes as input a list of contig IDs.  The output is a mapping
from contig ID to MD5 value.

=cut

sub contigs_to_md5s
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.contigs_to_md5s",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking contigs_to_md5s: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking contigs_to_md5s: " . $self->{client}->status_line;
    }
}



=head2 $result = md5s_to_genomes(md5s)

md5s to genomes is used to get the genomes associated with each of a list of input md5 values.

           The routine takes as input a list of MD5 values.  It constructs a mapping from each input
           MD5 value to a list of genomes that share the same MD5 value.

           The MD5 value for a genome is independent of the names of contigs and the case of the DNA sequence
           data.

=cut

sub md5s_to_genomes
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.md5s_to_genomes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking md5s_to_genomes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking md5s_to_genomes: " . $self->{client}->status_line;
    }
}



=head2 $result = genomes_to_md5s(genomes)

The routine genomes_to_md5s can be used to look up the MD5 value associated with each of
a set of genomes.  The MD5 values are computed when the genome is loaded, so this routine
just retrieves the precomputed values.

Note that the MD5 value of a genome is independent of the contig names and case of the
DNA sequences that make up the genome.

=cut

sub genomes_to_md5s
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.genomes_to_md5s",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking genomes_to_md5s: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking genomes_to_md5s: " . $self->{client}->status_line;
    }
}



=head2 $result = genomes_to_contigs(genomes)

The routine genomes_to_contigs can be used to retrieve the IDs of the contigs
associated with each of a list of input genomes.  The routine constructs a mapping
from genome ID to the list of contigs included in the genome.

=cut

sub genomes_to_contigs
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.genomes_to_contigs",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking genomes_to_contigs: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking genomes_to_contigs: " . $self->{client}->status_line;
    }
}



=head2 $result = genomes_to_fids(genomes, types_of_fids)

genomes_to_fids is used to get the fids included in specific genomes.  It
is often the case that you want just one or two types of fids -- hence, the
types_of_fids argument.

=cut

sub genomes_to_fids
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.genomes_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking genomes_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking genomes_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = genomes_to_taxonomies(genomes)

The routine genomes_to_taxonomies can be used to retrieve taxonomic information for
each of a list of input genomes.  For each genome in the input list of genomes, a list of
taxonomic groups is returned.  Kbase will use the groups maintained by NCBI.  For an NCBI
taxonomic string like

     cellular organisms;
     Bacteria;
     Proteobacteria;
     Gammaproteobacteria;
     Enterobacteriales;
     Enterobacteriaceae;
     Escherichia;
     Escherichia coli

associated with the strain 'Escherichia coli 1412', this routine would return a list of these
taxonomic groups:


     ['Bacteria',
      'Proteobacteria',
      'Gammaproteobacteria',
      'Enterobacteriales',
      'Enterobacteriaceae',
      'Escherichia',
      'Escherichia coli',
      'Escherichia coli 1412'
     ]

That is, the initial "cellular organisms" has been deleted, and the strain ID has
been added as the last "grouping".

The output is a mapping from genome IDs to lists of the form shown above.

=cut

sub genomes_to_taxonomies
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.genomes_to_taxonomies",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking genomes_to_taxonomies: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking genomes_to_taxonomies: " . $self->{client}->status_line;
    }
}



=head2 $result = genomes_to_subsystems(genomes)

A user can invoke genomes_to_subsystems to rerieve the names of the subsystems
relevant to each genome.  The input is a list of genomes.  The output is a mapping
from genome to a list of 2-tuples, where each 2-tuple give a variant code and a
subsystem name.  Variant codes of -1 (or *-1) amount to assertions that the
genome contains no active variant.  A variant code of 0 means "work in progress",
and presence or absence of the subsystem in the genome should be undetermined.

=cut

sub genomes_to_subsystems
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.genomes_to_subsystems",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking genomes_to_subsystems: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking genomes_to_subsystems: " . $self->{client}->status_line;
    }
}



=head2 $result = subsystems_to_genomes(subsystems)

The routine subsystems_to_genomes is used to determine which genomes are in
specified subsystems.  The input is the list of subsystem names of interest.
The output is a map from the subsystem names to lists of 2-tuples, where each 2-tuple is
a [variant-code,genome ID] pair.

=cut

sub subsystems_to_genomes
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.subsystems_to_genomes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking subsystems_to_genomes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking subsystems_to_genomes: " . $self->{client}->status_line;
    }
}



=head2 $result = subsystems_to_fids(subsystems, genomes)

The routine subsystems_to_fids allows the user to map subsystem names into the fids that
occur in genomes in the subsystems.  Specifically, the input is a list of subsystem names.
What is returned is a mapping from subsystem names to a "genome-mapping".  The genome-mapping
takes genome IDs to 2-tuples that capture the variant code of the genome and the fids from
the genome that are included in the subsystem.

=cut

sub subsystems_to_fids
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.subsystems_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking subsystems_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking subsystems_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = subsystems_to_roles(subsystems, aux)

The routine subsystem_to_roles is used to determine the role descriptions that
occur in a subsystem.  The input is a list of subsystem names.  A map is returned connecting
subsystem names to lists of roles.  'aux' is a boolean variable.  If it is 0, auxiliary roles
are not returned.  If it is 1, they are returned.

=cut

sub subsystems_to_roles
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.subsystems_to_roles",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking subsystems_to_roles: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking subsystems_to_roles: " . $self->{client}->status_line;
    }
}



=head2 $result = subsystems_to_spreadsheets(subsystems, genomes)

The subsystem_to_spreadsheet routine allows a user to extract the subsystem spreadsheets for
a specified set of subsystem names.  In the returned output, each subsystem is mapped
to a hash that takes as input a genome ID and maps it to the "row" for the genome in the subsystem.
The "row" is itself a 2-tuple composed of the variant code, and a mapping from role descriptions to
lists of fids.  We suggest writing a simple test script to get, say, the subsystem named
'Histidine Degradation', extracting the spreadsheet, and then using something like Dumper to make
sure that it all makes sense.

=cut

sub subsystems_to_spreadsheets
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.subsystems_to_spreadsheets",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking subsystems_to_spreadsheets: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking subsystems_to_spreadsheets: " . $self->{client}->status_line;
    }
}



=head2 $result = all_roles_used_in_models()

The all_roles_used_in_models allows a user to access the set of roles that are included in current models.  This is
important.  There are far fewer roles used in models than overall.  Hence, the returned set represents
the minimal set we need to clean up in order to properly support modeling.

=cut

sub all_roles_used_in_models
{
    my($self, @args) = @_;

    @args == 0 or die "Invalid argument count (expecting 0)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.all_roles_used_in_models",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_roles_used_in_models: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_roles_used_in_models: " . $self->{client}->status_line;
    }
}



=head2 $result = complexes_to_complex_data(complexes)



=cut

sub complexes_to_complex_data
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.complexes_to_complex_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking complexes_to_complex_data: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking complexes_to_complex_data: " . $self->{client}->status_line;
    }
}



=head2 $result = genomes_to_genome_data(genomes)



=cut

sub genomes_to_genome_data
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.genomes_to_genome_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking genomes_to_genome_data: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking genomes_to_genome_data: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_regulon_data(fids)



=cut

sub fids_to_regulon_data
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_regulon_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_regulon_data: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_regulon_data: " . $self->{client}->status_line;
    }
}



=head2 $result = regulons_to_fids(regulons)



=cut

sub regulons_to_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.regulons_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking regulons_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking regulons_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_feature_data(fids)



=cut

sub fids_to_feature_data
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_feature_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_feature_data: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_feature_data: " . $self->{client}->status_line;
    }
}



=head2 $result = equiv_sequence_assertions(proteins)

Different groups have made assertions of function for numerous protein sequences.
The equiv_sequence_assertions allows the user to gather function assertions from
all of the sources.  Each assertion includes a field indicating whether the person making
the assertion viewed themself as an "expert".  The routine gathers assertions for all
proteins having identical protein sequence.

=cut

sub equiv_sequence_assertions
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.equiv_sequence_assertions",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking equiv_sequence_assertions: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking equiv_sequence_assertions: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_atomic_regulons(fids)

The fids_to_atomic_regulons allows one to map fids into regulons that contain the fids.
Normally a fid will be in at most one regulon, but we support multiple regulons.

=cut

sub fids_to_atomic_regulons
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_atomic_regulons",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_atomic_regulons: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_atomic_regulons: " . $self->{client}->status_line;
    }
}



=head2 $result = atomic_regulons_to_fids(atomic_regulons)

The atomic_regulons_to_fids routine allows the user to access the set of fids that make up a regulon.
Regulons may arise from several sources; hence, fids can be in multiple regulons.

=cut

sub atomic_regulons_to_fids
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.atomic_regulons_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking atomic_regulons_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking atomic_regulons_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_protein_sequences(fids)

fids_to_protein_sequences allows the user to look up the amino acid sequences
corresponding to each of a set of fids.  You can also get the sequence from proteins (i.e., md5 values).
This routine saves you having to look up the md5 sequence and then accessing
the protein string in a separate call.

=cut

sub fids_to_protein_sequences
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_protein_sequences",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_protein_sequences: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_protein_sequences: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_proteins(fids)



=cut

sub fids_to_proteins
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_proteins",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_proteins: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_proteins: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_dna_sequences(fids)

fids_to_dna_sequences allows the user to look up the DNA sequences
corresponding to each of a set of fids.

=cut

sub fids_to_dna_sequences
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_dna_sequences",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_dna_sequences: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_dna_sequences: " . $self->{client}->status_line;
    }
}



=head2 $result = roles_to_fids(roles, genomes)

A "function" is a set of "roles" (often called "functional roles");

                F1 / F2  (where F1 and F2 are roles)  is a function that implements
                          two functional roles in different domains of the protein.
                F1 @ F2 implements multiple roles through broad specificity
                F1; F2  is thought to implement F1 or f2 (uncertainty)

            You often wish to find the fids in one or more genomes that
            implement specific functional roles.  To do this, you can use
            roles_to_fids.

=cut

sub roles_to_fids
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.roles_to_fids",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking roles_to_fids: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking roles_to_fids: " . $self->{client}->status_line;
    }
}



=head2 $result = reactions_to_complexes(reactions)

Reactions are thought of as being either spontaneous or implemented by
one or more Complexes.  Complexes connect to Roles.  Hence, the connection of fids
or roles to reactions goes through Complexes.

=cut

sub reactions_to_complexes
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.reactions_to_complexes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking reactions_to_complexes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking reactions_to_complexes: " . $self->{client}->status_line;
    }
}



=head2 $result = reaction_strings(reactions, name_parameter)

Reaction_strings are text strings that represent (albeit crudely)
the details of Reactions.

=cut

sub reaction_strings
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.reaction_strings",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking reaction_strings: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking reaction_strings: " . $self->{client}->status_line;
    }
}



=head2 $result = roles_to_complexes(roles)

roles_to_complexes allows a user to connect Roles to Complexes,
from there, the connection exists to Reactions (although in the
actual ER-model model, the connection from Complex to Reaction goes through
ReactionComplex).  Since Roles also connect to fids, the connection between
fids and Reactions is induced.

The "name_parameter" can be 0, 1 or 'only'. If 1, then the compound name will 
be included with the ID in the output. If only, the compound name will be included 
instead of the ID. If 0, only the ID will be included. The default is 0.

=cut

sub roles_to_complexes
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.roles_to_complexes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking roles_to_complexes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking roles_to_complexes: " . $self->{client}->status_line;
    }
}



=head2 $result = complexes_to_roles(complexes)



=cut

sub complexes_to_roles
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.complexes_to_roles",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking complexes_to_roles: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking complexes_to_roles: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_subsystem_data(fids)



=cut

sub fids_to_subsystem_data
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_subsystem_data",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_subsystem_data: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_subsystem_data: " . $self->{client}->status_line;
    }
}



=head2 $result = representative(genomes)



=cut

sub representative
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.representative",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking representative: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking representative: " . $self->{client}->status_line;
    }
}



=head2 $result = otu_members(genomes)



=cut

sub otu_members
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.otu_members",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking otu_members: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking otu_members: " . $self->{client}->status_line;
    }
}



=head2 $result = fids_to_genomes(fids)



=cut

sub fids_to_genomes
{
    my($self, @args) = @_;

    @args == 1 or die "Invalid argument count (expecting 1)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.fids_to_genomes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking fids_to_genomes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking fids_to_genomes: " . $self->{client}->status_line;
    }
}



=head2 $result = text_search(input, start, count, entities)

text_search performs a search against a full-text index maintained 
for the CDMI. The parameter "input" is the text string to be searched for.
The parameter "entities" defines the entities to be searched. If the list
is empty, all indexed entities will be searched. The "start" and "count"
parameters limit the results to "count" hits starting at "start".

=cut

sub text_search
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_API.text_search",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking text_search: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking text_search: " . $self->{client}->status_line;
    }
}





=head2 $result = get_entity_AlignmentTree(ids, fields)

An alignment arranges a group of protein sequences so that they
match. Each alignment is associated with a phylogenetic tree that
describes how the sequences developed and their evolutionary distance.
The actual tree and alignment FASTA are stored in separate flat files.
The Kbase will maintain a set of alignments and associated
trees.  The majority
of these will be based on protein sequences.  We will not have a comprehensive set
but we will have tens of thousands of such alignments, and we view them as an
imporant resource to support annotation.
The alignments/trees will include the tools and parameters used to construct
them.
Access to the underlying sequences and trees in a form convenient to existing
tools will be supported.

It has the following fields:

=over 4


=item alignment_method

The name of the program used to produce the alignment.


=item alignment_parameters

The parameters given to the program when producing the alignment.


=item alignment_properties

A colon-delimited string of key-value pairs containing additional
properties of the alignment.


=item tree_method

The name of the program used to produce the tree.


=item tree_parameters

The parameters given to the program when producing the tree.


=item tree_properties

A colon-delimited string of key-value pairs containing additional
properties of the tree.



=back

=cut

sub get_entity_AlignmentTree
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_AlignmentTree",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_AlignmentTree: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_AlignmentTree: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_AlignmentTree(start, count, fields)



=cut

sub all_entities_AlignmentTree
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_AlignmentTree",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_AlignmentTree: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_AlignmentTree: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Annotation(ids, fields)

An annotation is a comment attached to a feature. Annotations
are used to track the history of a feature's functional assignments
and any related issues. The key is the feature ID followed by a
colon and a complemented ten-digit sequence number.

It has the following fields:

=over 4


=item annotator

name of the annotator who made the comment


=item comment

text of the annotation


=item annotation_time

date and time at which the annotation was made



=back

=cut

sub get_entity_Annotation
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Annotation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Annotation: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Annotation: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Annotation(start, count, fields)



=cut

sub all_entities_Annotation
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Annotation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Annotation: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Annotation: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_AtomicRegulon(ids, fields)

An atomic regulon is an indivisible group of coregulated features
on a single genome. Atomic regulons are constructed so that a given feature
can only belong to one. Because of this, the expression levels for
atomic regulons represent in some sense the state of a cell.
An atomicRegulon is a set of protein-encoding genes that
are believed to have identical expression profiles (i.e.,
they will all be expressed or none will be expressed in the
vast majority of conditions).  These are sometimes referred
to as "atomic regulons".  Note that there are more common
notions of "coregulated set of genes" based on the notion
that a single regulatory mechanism impacts an entire set of
genes. Since multiple other mechanisms may impact
overlapping sets, the genes impacted by a regulatory
mechanism need not all share the same expression profile.
We use a distinct notion (CoregulatedSet) to reference sets
of genes impacted by a single regulatory mechanism (i.e.,
by a single transcription regulator).

It has the following fields:

=over 4



=back

=cut

sub get_entity_AtomicRegulon
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_AtomicRegulon",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_AtomicRegulon: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_AtomicRegulon: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_AtomicRegulon(start, count, fields)



=cut

sub all_entities_AtomicRegulon
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_AtomicRegulon",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_AtomicRegulon: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_AtomicRegulon: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Attribute(ids, fields)

An attribute describes a category of condition or characteristic for
an experiment. The goals of the experiment can be inferred from its values
for all the attributes of interest.
It has the following fields:

=over 4


=item description

Descriptive text indicating the nature and use of this attribute.



=back

=cut

sub get_entity_Attribute
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Attribute",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Attribute: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Attribute: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Attribute(start, count, fields)



=cut

sub all_entities_Attribute
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Attribute",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Attribute: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Attribute: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Biomass(ids, fields)

A biomass is a collection of compounds in a specific
ratio and in specific compartments that are necessary for a
cell to function properly. The prediction of biomasses is key
to the functioning of the model.
It has the following fields:

=over 4


=item mod_date

last modification date of the biomass data


=item name

descriptive name for this biomass



=back

=cut

sub get_entity_Biomass
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Biomass",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Biomass: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Biomass: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Biomass(start, count, fields)



=cut

sub all_entities_Biomass
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Biomass",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Biomass: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Biomass: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_BiomassCompound(ids, fields)

A Biomass Compound represents the occurrence of a particular
compound in a biomass.
It has the following fields:

=over 4


=item coefficient

proportion of the biomass in grams per mole that
contains this compound



=back

=cut

sub get_entity_BiomassCompound
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_BiomassCompound",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_BiomassCompound: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_BiomassCompound: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_BiomassCompound(start, count, fields)



=cut

sub all_entities_BiomassCompound
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_BiomassCompound",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_BiomassCompound: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_BiomassCompound: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Compartment(ids, fields)

A compartment is a section of a single model that represents
the environment in which a reaction takes place (e.g. cell
wall).
It has the following fields:

=over 4


=item abbr

short abbreviated name for this compartment (usually
a single character)


=item mod_date

date and time of the last modification to the
compartment's definition


=item name

common name for the compartment


=item msid

common modeling ID of this compartment



=back

=cut

sub get_entity_Compartment
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Compartment",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Compartment: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Compartment: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Compartment(start, count, fields)



=cut

sub all_entities_Compartment
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Compartment",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Compartment: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Compartment: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Complex(ids, fields)

A complex is a set of chemical reactions that act in concert to
effect a role.
It has the following fields:

=over 4


=item name

name of this complex. Not all complexes have names.


=item msid

common modeling ID of this complex.


=item mod_date

date and time of the last change to this complex's definition



=back

=cut

sub get_entity_Complex
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Complex",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Complex: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Complex: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Complex(start, count, fields)



=cut

sub all_entities_Complex
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Complex",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Complex: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Complex: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Compound(ids, fields)

A compound is a chemical that participates in a reaction. Both
ligands and reaction components are treated as compounds.
It has the following fields:

=over 4


=item label

primary name of the compound, for use in displaying
reactions


=item abbr

shortened abbreviation for the compound name


=item msid

common modeling ID of this compound


=item ubiquitous

TRUE if this compound is found in most reactions, else FALSE


=item mod_date

date and time of the last modification to the
compound definition


=item uncharged_formula

a electrically neutral formula for the compound


=item formula

a pH-neutral formula for the compound


=item mass

atomic mass of the compound



=back

=cut

sub get_entity_Compound
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Compound",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Compound: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Compound: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Compound(start, count, fields)



=cut

sub all_entities_Compound
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Compound",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Compound: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Compound: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Contig(ids, fields)

A contig is thought of as composing a part of the DNA associated with a specific
genome.  It is represented as an ID (including the genome ID) and a ContigSequence.
We do not think of strings of DNA from, say, a metgenomic sample as "contigs",
since there is no associated genome (these would be considered ContigSequences).
This use of the term "ContigSequence", rather than just "DNA sequence", may turn out
to be a bad idea.  For now, you should just realize that a Contig has an associated
genome, but a ContigSequence does not.

It has the following fields:

=over 4


=item source_id

ID of this contig from the core (source) database



=back

=cut

sub get_entity_Contig
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Contig",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Contig: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Contig: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Contig(start, count, fields)



=cut

sub all_entities_Contig
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Contig",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Contig: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Contig: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_ContigChunk(ids, fields)

ContigChunks are strings of DNA thought of as being a string in a 4-character alphabet
with an associated ID.  We allow a broader alphabet that includes U (for RNA) and
the standard ambiguity characters.
The notion of ContigChunk was introduced to avoid transferring/manipulating
huge contigs to access small substrings.  A ContigSequence is formed by
concatenating a set of one or more ContigChunks.  Thus, ContigChunks are the
basic units moved from the database to memory.  Their existence should be
hidden from users in most circumstances (users are expected to request
substrings of ContigSequences, and the Kbase software locates the appropriate
ContigChunks).

It has the following fields:

=over 4


=item sequence

base pairs that make up this sequence



=back

=cut

sub get_entity_ContigChunk
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_ContigChunk",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_ContigChunk: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_ContigChunk: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_ContigChunk(start, count, fields)



=cut

sub all_entities_ContigChunk
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_ContigChunk",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_ContigChunk: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_ContigChunk: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_ContigSequence(ids, fields)

ContigSequences are strings of DNA.  Contigs have an associated
genome, but ContigSequences do not..   We can think of random samples of DNA as a set of ContigSequences.
There are no length constraints imposed on ContigSequences -- they can be either
very short or very long.  The basic unit of data that is moved to/from the database
is the ContigChunk, from which ContigSequences are formed. The key
of a ContigSequence is the sequence's MD5 identifier.

It has the following fields:

=over 4


=item length

number of base pairs in the contig



=back

=cut

sub get_entity_ContigSequence
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_ContigSequence",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_ContigSequence: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_ContigSequence: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_ContigSequence(start, count, fields)



=cut

sub all_entities_ContigSequence
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_ContigSequence",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_ContigSequence: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_ContigSequence: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_CoregulatedSet(ids, fields)

We need to represent sets of genes that are coregulated via some
regulatory mechanism.  In particular, we wish to represent genes
that are coregulated using transcription binding sites and
corresponding transcription regulatory proteins.
We represent a coregulated set (which may, or may not, be considered
an atomic regulon) using CoregulatedSet.

It has the following fields:

=over 4


=item source_id

original ID of this coregulated set in the source (core)
database



=back

=cut

sub get_entity_CoregulatedSet
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_CoregulatedSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_CoregulatedSet: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_CoregulatedSet: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_CoregulatedSet(start, count, fields)



=cut

sub all_entities_CoregulatedSet
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_CoregulatedSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_CoregulatedSet: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_CoregulatedSet: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Diagram(ids, fields)

A functional diagram describes a network of chemical
reactions, often comprising a single subsystem.
It has the following fields:

=over 4


=item name

descriptive name of this diagram


=item content

content of the diagram, in PNG format



=back

=cut

sub get_entity_Diagram
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Diagram",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Diagram: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Diagram: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Diagram(start, count, fields)



=cut

sub all_entities_Diagram
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Diagram",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Diagram: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Diagram: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_EcNumber(ids, fields)

EC numbers are assigned by the Enzyme Commission, and consist
of four numbers separated by periods, each indicating a successively
smaller cateogry of enzymes.
It has the following fields:

=over 4


=item obsolete

This boolean indicates when an EC number is obsolete.


=item replacedby

When an obsolete EC number is replaced with another EC number, this string will
hold the name of the replacement EC number.



=back

=cut

sub get_entity_EcNumber
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_EcNumber",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_EcNumber: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_EcNumber: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_EcNumber(start, count, fields)



=cut

sub all_entities_EcNumber
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_EcNumber",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_EcNumber: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_EcNumber: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Experiment(ids, fields)

An experiment is a combination of conditions for which gene expression
information is desired. The result of the experiment is a set of expression
levels for features under the given conditions.
It has the following fields:

=over 4


=item source

Publication or lab relevant to this experiment.



=back

=cut

sub get_entity_Experiment
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Experiment",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Experiment: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Experiment: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Experiment(start, count, fields)



=cut

sub all_entities_Experiment
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Experiment",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Experiment: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Experiment: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Family(ids, fields)

The Kbase will support the maintenance of protein families (as sets of Features
with associated translations).  We are initially only supporting the notion of a family
as composed of a set of isofunctional homologs.  That is, the families we
initially support should be thought of as containing protein-encoding genes whose
associated sequences all implement the same function
(we do understand that the notion of "function" is somewhat ambiguous, so let
us sweep this under the rug by calling a functional role a "primitive concept").
We currently support families in which the members are
translations of features, and we think of Features as
having an associated function. Identical protein sequences
as products of translating distinct genes may or may not
have identical functions, and we allow multiple members of
the same Family to share identical protein sequences.  This
may be justified, since in a very, very, very few cases
identical proteins do, in fact, have distinct functions.
We would prefer to reach the point where our Families are
sets of protein sequence, rather than sets of
protein-encoding Features.

It has the following fields:

=over 4


=item type

type of protein family (e.g. FIGfam, equivalog)


=item family_function

optional free-form description of the family. For function-based
families, this would be the functional role for the family
members.



=back

=cut

sub get_entity_Family
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Family",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Family: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Family: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Family(start, count, fields)



=cut

sub all_entities_Family
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Family",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Family: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Family: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Feature(ids, fields)

A feature (sometimes also called a gene) is a part of a
genome that is of special interest. Features may be spread across
multiple DNA sequences (contigs) of a genome, but never across more
than one genome. Each feature in the database has a unique
ID that functions as its ID in this table.
Normally a Feature is just a single contigous region on a contig.
Features have types, and an appropriate choice of available types
allows the support of protein-encoding genes, exons, RNA genes,
binding sites, pathogenicity islands, or whatever.

It has the following fields:

=over 4


=item feature_type

Code indicating the type of this feature. Among the
codes currently supported are "peg" for a protein encoding
gene, "bs" for a binding site, "opr" for an operon, and so
forth.


=item source_id

ID for this feature in its original source (core)
database


=item sequence_length

Number of base pairs in this feature.


=item function

Functional assignment for this feature. This will
often indicate the feature's functional role or roles, and
may also have comments.



=back

=cut

sub get_entity_Feature
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Feature",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Feature: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Feature: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Feature(start, count, fields)



=cut

sub all_entities_Feature
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Feature",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Feature: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Feature: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Genome(ids, fields)

The Kbase houses a large and growing set of genomes.  We often have multiple
genomes that have identical DNA.  These usually have distinct gene calls and
annotations, but not always.  We consider the Kbase to be a framework for
managing hundreds of thousands of genomes and offering the tools needed to
support compartive analysis on large sets of genomes, some of which are
virtually identical.
Each genome has an MD5 value computed from the DNA that is associated with the genome.
Hence, it is easy to recognize when you have identical genomes, perhaps annotated
by distinct groups.

It has the following fields:

=over 4


=item pegs

Number of protein encoding genes for this genome.


=item rnas

Number of RNA features found for this organism.


=item scientific_name

Full genus/species/strain name of the genome sequence.


=item complete

TRUE if the genome sequence is complete, else FALSE


=item prokaryotic

TRUE if this is a prokaryotic genome sequence, else FALSE


=item dna_size

Number of base pairs in the genome sequence.


=item contigs

Number of contigs for this genome sequence.


=item domain

Domain for this organism (Archaea, Bacteria, Eukaryota,
Virus, Plasmid, or Environmental Sample).


=item genetic_code

Genetic code number used for protein translation on most
of this genome sequence's contigs.


=item gc_content

Percent GC content present in the genome sequence's
DNA.


=item phenotype

zero or more strings describing phenotypic information
about this genome sequence


=item md5

MD5 identifier describing the genome's DNA sequence


=item source_id

identifier assigned to this genome by the original
source



=back

=cut

sub get_entity_Genome
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Genome: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Genome: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Genome(start, count, fields)



=cut

sub all_entities_Genome
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Genome",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Genome: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Genome: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Identifier(ids, fields)

An identifier is an alternate name for a protein sequence.
The identifier is typically stored in a prefixed form that
indicates the database it came from.
It has the following fields:

=over 4


=item source

Specific type of the identifier, such as its source
database or category. The type can usually be decoded to
convert the identifier to a URL.


=item natural_form

Natural form of the identifier. This is how the identifier looks
without the identifying prefix (if one is present).



=back

=cut

sub get_entity_Identifier
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Identifier",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Identifier: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Identifier: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Identifier(start, count, fields)



=cut

sub all_entities_Identifier
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Identifier",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Identifier: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Identifier: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Media(ids, fields)

A media describes the chemical content of the solution in which cells
are grown in an experiment or for the purposes of a model. The key is the
common media name. The nature of the media is described by its relationship
to its constituent compounds.
It has the following fields:

=over 4


=item mod_date

date and time of the last modification to the media's
definition


=item name

descriptive name of the media


=item type

type of the medium (aerobic or anaerobic)



=back

=cut

sub get_entity_Media
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Media",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Media: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Media: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Media(start, count, fields)



=cut

sub all_entities_Media
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Media",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Media: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Media: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Model(ids, fields)

A model specifies a relationship between sets of features and
reactions in a cell. It is used to simulate cell growth and gene
knockouts to validate annotations.
It has the following fields:

=over 4


=item mod_date

date and time of the last change to the model data


=item name

descriptive name of the model


=item version

revision number of the model


=item type

ask Chris


=item status

indicator of whether the model is stable, under
construction, or under reconstruction


=item reaction_count

number of reactions in the model


=item compound_count

number of compounds in the model


=item annotation_count

number of annotations used to build the model



=back

=cut

sub get_entity_Model
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Model: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Model: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Model(start, count, fields)



=cut

sub all_entities_Model
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Model: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Model: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_ModelCompartment(ids, fields)

The Model Compartment represents a section of a cell
(e.g. cell wall, cytoplasm) as it appears in a specific
model.
It has the following fields:

=over 4


=item compartment_index

number used to distinguish between different
instances of the same type of compartment in a single
model. Within a model, any two instances of the same
compartment must have difference compartment index
values.


=item label

description used to differentiate between instances
of the same compartment in a single model


=item pH

pH used to determine proton balance in this
compartment


=item potential

ask Chris



=back

=cut

sub get_entity_ModelCompartment
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_ModelCompartment",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_ModelCompartment: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_ModelCompartment: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_ModelCompartment(start, count, fields)



=cut

sub all_entities_ModelCompartment
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_ModelCompartment",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_ModelCompartment: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_ModelCompartment: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_OTU(ids, fields)

An OTU (Organism Taxonomic Unit) is a named group of related
genomes.
It has the following fields:

=over 4



=back

=cut

sub get_entity_OTU
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_OTU",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_OTU: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_OTU: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_OTU(start, count, fields)



=cut

sub all_entities_OTU
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_OTU",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_OTU: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_OTU: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_PairSet(ids, fields)

A PairSet is a precompute set of pairs or genes.  Each pair occurs close to
one another of the chromosome.  We believe that all of the first members
of the pairs correspond to one another (are quite similar), as do all of
the second members of the pairs.  These pairs (from prokaryotic genomes)
offer on of the most powerful clues relating to uncharacterized genes/peroteins.

It has the following fields:

=over 4


=item score

Score for this evidence set. The score indicates the
number of significantly different genomes represented by the
pairings.



=back

=cut

sub get_entity_PairSet
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_PairSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_PairSet: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_PairSet: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_PairSet(start, count, fields)



=cut

sub all_entities_PairSet
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_PairSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_PairSet: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_PairSet: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Pairing(ids, fields)

A pairing indicates that two features are found
close together in a genome. Not all possible pairings are stored in
the database; only those that are considered for some reason to be
significant for annotation purposes.The key of the pairing is the
concatenation of the feature IDs in alphabetical order with an
intervening colon.
It has the following fields:

=over 4



=back

=cut

sub get_entity_Pairing
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Pairing",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Pairing: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Pairing: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Pairing(start, count, fields)



=cut

sub all_entities_Pairing
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Pairing",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Pairing: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Pairing: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_ProbeSet(ids, fields)

A probe set is a device containing multiple probe sequences for use
in gene expression experiments.
It has the following fields:

=over 4



=back

=cut

sub get_entity_ProbeSet
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_ProbeSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_ProbeSet: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_ProbeSet: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_ProbeSet(start, count, fields)



=cut

sub all_entities_ProbeSet
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_ProbeSet",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_ProbeSet: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_ProbeSet: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_ProteinSequence(ids, fields)

We use the concept of ProteinSequence as an amino acid string with an associated
MD5 value.  It is easy to access the set of Features that relate to a ProteinSequence.
While function is still associated with Features (and may be for some time), publications
are associated with ProteinSequences (and the inferred impact on Features is through
the relationship connecting ProteinSequences to Features).

It has the following fields:

=over 4


=item sequence

The sequence contains the letters corresponding to
the protein's amino acids.



=back

=cut

sub get_entity_ProteinSequence
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_ProteinSequence",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_ProteinSequence: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_ProteinSequence: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_ProteinSequence(start, count, fields)



=cut

sub all_entities_ProteinSequence
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_ProteinSequence",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_ProteinSequence: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_ProteinSequence: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Publication(ids, fields)

Annotators attach publications to ProteinSequences.  The criteria we have used
to gather such connections is a bit nonstandard.  We have sought to attach publications
to ProteinSequences when the publication includes an expert asserting a belief or estimate
of function.  The paper may not be the original characterization.  Further, it may not
even discuss a sequence protein (much of the literature is very valuable, but reports
work on proteins in strains that have not yet been sequenced).  On the other hand,
reports of sequencing regions of a chromosome (with no specific assertion of a
clear function) should not be attached.  The attached publications give an ID (usually a
Pubmed ID),  a URL to the paper (when we have it), and a title (when we have it).

It has the following fields:

=over 4


=item title

title of the article, or (unknown) if the title is not known


=item link

URL of the article


=item pubdate

publication date of the article



=back

=cut

sub get_entity_Publication
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Publication",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Publication: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Publication: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Publication(start, count, fields)



=cut

sub all_entities_Publication
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Publication",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Publication: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Publication: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Reaction(ids, fields)

A reaction is a chemical process that converts one set of
compounds (substrate) to another set (products).
It has the following fields:

=over 4


=item mod_date

date and time of the last modification to this reaction's
definition


=item name

descriptive name of this reaction


=item msid

common modeling ID of this reaction


=item abbr

abbreviated name of this reaction


=item equation

displayable formula for the reaction


=item reversibility

direction of this reaction (> for forward-only,
< for backward-only, = for bidirectional)



=back

=cut

sub get_entity_Reaction
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Reaction",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Reaction: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Reaction: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Reaction(start, count, fields)



=cut

sub all_entities_Reaction
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Reaction",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Reaction: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Reaction: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_ReactionRule(ids, fields)

A reaction rule represents the way a reaction takes place
within the context of a model.
It has the following fields:

=over 4


=item direction

reaction directionality (> for forward, < for
backward, = for bidirectional) with respect to this complex


=item transproton

ask Chris



=back

=cut

sub get_entity_ReactionRule
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_ReactionRule",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_ReactionRule: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_ReactionRule: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_ReactionRule(start, count, fields)



=cut

sub all_entities_ReactionRule
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_ReactionRule",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_ReactionRule: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_ReactionRule: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Reagent(ids, fields)

This entity represents a compound as it is used by
a specific reaction. A reaction involves many compounds, and a
compound can be involved in many reactions. The reagent
describes the use of the compound by a specific reaction.
It has the following fields:

=over 4


=item stoichiometry

Number of molecules of the compound that participate
in a single instance of the reaction. For example, if a
reaction produces two water molecules, the stoichiometry of
water for the reaction would be two. When a reaction is
written on paper in chemical notation, the stoichiometry is
the number next to the chemical formula of the
compound. The value is negative for substrates and positive
for products.


=item cofactor

TRUE if the compound is a cofactor; FALSE if it is a major
component of the reaction.


=item compartment_index

Abstract number that groups this reagent into a
compartment. Each group can then be assigned to real
compartments when doing comparative analysis.


=item transport_coefficient

Number of reagents of this type transported.
A positive value implies transport into the reactions
default compartment; a negative value implies export
to the reagent's specified compartment.



=back

=cut

sub get_entity_Reagent
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Reagent",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Reagent: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Reagent: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Reagent(start, count, fields)



=cut

sub all_entities_Reagent
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Reagent",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Reagent: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Reagent: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Requirement(ids, fields)

A requirement describes the way a reaction fits
into a model.
It has the following fields:

=over 4


=item direction

reaction directionality (> for forward, < for
backward, = for bidirectional) with respect to this model


=item transproton

ask Chris


=item proton

ask Chris



=back

=cut

sub get_entity_Requirement
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Requirement",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Requirement: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Requirement: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Requirement(start, count, fields)



=cut

sub all_entities_Requirement
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Requirement",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Requirement: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Requirement: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Role(ids, fields)

A role describes a biological function that may be fulfilled
by a feature. One of the main goals of the database is to assign
features to roles. Most roles are effected by the construction of
proteins. Some, however, deal with functional regulation and message
transmission.
It has the following fields:

=over 4


=item hypothetical

TRUE if a role is hypothetical, else FALSE



=back

=cut

sub get_entity_Role
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Role",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Role: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Role: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Role(start, count, fields)



=cut

sub all_entities_Role
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Role",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Role: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Role: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_SSCell(ids, fields)

An SSCell (SpreadSheet Cell) represents a role as it occurs
in a subsystem spreadsheet row. The key is a colon-delimited triple
containing an MD5 hash of the subsystem ID followed by a genome ID
(with optional region string) and a role abbreviation.
It has the following fields:

=over 4



=back

=cut

sub get_entity_SSCell
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_SSCell",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_SSCell: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_SSCell: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_SSCell(start, count, fields)



=cut

sub all_entities_SSCell
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_SSCell",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_SSCell: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_SSCell: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_SSRow(ids, fields)

An SSRow (that is, a row in a subsystem spreadsheet) represents a collection of
functional roles present in the Features of a single Genome.  The roles are part
of a designated subsystem, and the fids associated with each role are included in the row,
That is, a row amounts to an instance of a subsystem as it exists in a specific, designated
genome.

It has the following fields:

=over 4


=item curated

This flag is TRUE if the assignment of the molecular
machine has been curated, and FALSE if it was made by an
automated program.


=item region

Region in the genome for which the machine is relevant.
Normally, this is an empty string, indicating that the machine
covers the whole genome. If a subsystem has multiple machines
for a genome, this contains a location string describing the
region occupied by this particular machine.



=back

=cut

sub get_entity_SSRow
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_SSRow",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_SSRow: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_SSRow: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_SSRow(start, count, fields)



=cut

sub all_entities_SSRow
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_SSRow",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_SSRow: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_SSRow: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Scenario(ids, fields)

A scenario is a partial instance of a subsystem with a
defined set of reactions. Each scenario converts input compounds to
output compounds using reactions. The scenario may use all of the
reactions controlled by a subsystem or only some, and may also
incorporate additional reactions. Because scenario names are not
unique, the actual scenario ID is a number.
It has the following fields:

=over 4


=item common_name

Common name of the scenario. The name, rather than the ID
number, is usually displayed everywhere.



=back

=cut

sub get_entity_Scenario
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Scenario",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Scenario: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Scenario: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Scenario(start, count, fields)



=cut

sub all_entities_Scenario
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Scenario",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Scenario: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Scenario: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Source(ids, fields)

A source is a user or organization that is permitted to
assign its own identifiers or to submit bioinformatic objects
to the database.
It has the following fields:

=over 4



=back

=cut

sub get_entity_Source
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Source",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Source: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Source: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Source(start, count, fields)



=cut

sub all_entities_Source
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Source",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Source: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Source: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Subsystem(ids, fields)

A subsystem is a set of functional roles that have been annotated simultaneously (e.g.,
the roles present in a specific pathway), with an associated subsystem spreadsheet
which encodes the fids in each genome that implement the functional roles in the
subsystem.

It has the following fields:

=over 4


=item version

version number for the subsystem. This value is
incremented each time the subsystem is backed up.


=item curator

name of the person currently in charge of the
subsystem


=item notes

descriptive notes about the subsystem


=item description

description of the subsystem's function in the
cell


=item usable

TRUE if this is a usable subsystem, else FALSE. An
unusable subsystem is one that is experimental or is of
such low quality that it can negatively affect analysis.


=item private

TRUE if this is a private subsystem, else FALSE. A
private subsystem has valid data, but is not considered ready
for general distribution.


=item cluster_based

TRUE if this is a clustering-based subsystem, else
FALSE. A clustering-based subsystem is one in which there is
functional-coupling evidence that genes belong together, but
we do not yet know what they do.


=item experimental

TRUE if this is an experimental subsystem, else FALSE.
An experimental subsystem is designed for investigation and
is not yet ready to be used in comparative analysis and
annotation.



=back

=cut

sub get_entity_Subsystem
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Subsystem",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Subsystem: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Subsystem: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Subsystem(start, count, fields)



=cut

sub all_entities_Subsystem
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Subsystem",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Subsystem: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Subsystem: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_SubsystemClass(ids, fields)

Subsystem classes impose a hierarchical organization on the
subsystems.
It has the following fields:

=over 4



=back

=cut

sub get_entity_SubsystemClass
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_SubsystemClass",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_SubsystemClass: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_SubsystemClass: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_SubsystemClass(start, count, fields)



=cut

sub all_entities_SubsystemClass
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_SubsystemClass",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_SubsystemClass: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_SubsystemClass: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_TaxonomicGrouping(ids, fields)

We associate with most genomes a "taxonomy" based on the NCBI taxonomy.
This includes, for each genome, a list of ever larger taxonomic groups.

It has the following fields:

=over 4


=item domain

TRUE if this is a domain grouping, else FALSE.


=item hidden

TRUE if this is a hidden grouping, else FALSE. Hidden groupings
are not typically shown in a lineage list.


=item scientific_name

Primary scientific name for this grouping. This is the name used
when displaying a taxonomy.


=item alias

Alternate name for this grouping. A grouping
may have many alternate names. The scientific name should also
be in this list.



=back

=cut

sub get_entity_TaxonomicGrouping
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_TaxonomicGrouping",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_TaxonomicGrouping: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_TaxonomicGrouping: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_TaxonomicGrouping(start, count, fields)



=cut

sub all_entities_TaxonomicGrouping
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_TaxonomicGrouping",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_TaxonomicGrouping: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_TaxonomicGrouping: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Variant(ids, fields)

Each subsystem may include the designation of distinct variants.  Thus,
there may be three closely-related, but distinguishable forms of histidine
degradation.  Each form would be called a "variant", with an associated code,
and all genomes implementing a specific variant can easily be accessed.

It has the following fields:

=over 4


=item role_rule

a space-delimited list of role IDs, in alphabetical order,
that represents a possible list of non-auxiliary roles applicable to
this variant. The roles are identified by their abbreviations. A
variant may have multiple role rules.


=item code

the variant code all by itself


=item type

variant type indicating the quality of the subsystem
support. A type of "vacant" means that the subsystem
does not appear to be implemented by the variant. A
type of "incomplete" means that the subsystem appears to be
missing many reactions. In all other cases, the type is
"normal".


=item comment

commentary text about the variant



=back

=cut

sub get_entity_Variant
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Variant",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Variant: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Variant: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Variant(start, count, fields)



=cut

sub all_entities_Variant
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Variant",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Variant: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Variant: " . $self->{client}->status_line;
    }
}



=head2 $result = get_entity_Variation(ids, fields)

A variation describes a set of aligned regions
in two or more contigs.
It has the following fields:

=over 4


=item notes

optional text description of what the variation
means



=back

=cut

sub get_entity_Variation
{
    my($self, @args) = @_;

    @args == 2 or die "Invalid argument count (expecting 2)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_entity_Variation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_entity_Variation: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_entity_Variation: " . $self->{client}->status_line;
    }
}



=head2 $result = all_entities_Variation(start, count, fields)



=cut

sub all_entities_Variation
{
    my($self, @args) = @_;

    @args == 3 or die "Invalid argument count (expecting 3)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.all_entities_Variation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking all_entities_Variation: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking all_entities_Variation: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_AffectsLevelOf(ids, from_fields, rel_fields, to_fields)

This relationship indicates the expression level of an atomic regulon
for a given experiment.
It has the following fields:

=over 4


=item level

Indication of whether the feature is expressed (1), not expressed (-1),
or unknown (0).



=back

=cut

sub get_relationship_AffectsLevelOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_AffectsLevelOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_AffectsLevelOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_AffectsLevelOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsAffectedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsAffectedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsAffectedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsAffectedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsAffectedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Aligns(ids, from_fields, rel_fields, to_fields)

This relationship connects each alignment to its constituent protein
sequences. Each alignment contains many protein sequences, and a single
sequence can be in many alignments. Parts of a single protein can occur
in multiple places in an alignment. The sequence-id field is used to
keep these unique, and is the string that represents the sequence in the
alignment and tree text.
It has the following fields:

=over 4


=item begin

location within the sequence at which the aligned portion begins


=item end

location within the sequence at which the aligned portion ends


=item len

length of the sequence within the alignment


=item sequence_id

identifier for this sequence in the alignment


=item properties

additional information about this sequence's participation in the
alignment



=back

=cut

sub get_relationship_Aligns
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Aligns",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Aligns: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Aligns: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsAlignedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsAlignedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsAlignedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsAlignedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsAlignedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Concerns(ids, from_fields, rel_fields, to_fields)

This relationship connects a publication to the protein
sequences it describes.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Concerns
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Concerns",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Concerns: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Concerns: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsATopicOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsATopicOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsATopicOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsATopicOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsATopicOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Contains(ids, from_fields, rel_fields, to_fields)

This relationship connects a subsystem spreadsheet cell to the features
that occur in it. A feature may occur in many machine roles and a
machine role may contain many features. The subsystem annotation
process is essentially the maintenance of this relationship.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Contains
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Contains",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Contains: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Contains: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsContainedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsContainedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsContainedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsContainedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsContainedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Controls(ids, from_fields, rel_fields, to_fields)

This relationship connects a coregulated set to the
features that are used as its transcription factors.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Controls
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Controls",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Controls: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Controls: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsControlledUsing(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsControlledUsing
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsControlledUsing",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsControlledUsing: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsControlledUsing: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Describes(ids, from_fields, rel_fields, to_fields)

This relationship connects a subsystem to the individual
variants used to implement it. Each variant contains a slightly
different subset of the roles in the parent subsystem.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Describes
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Describes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Describes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Describes: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDescribedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsDescribedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDescribedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDescribedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDescribedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Displays(ids, from_fields, rel_fields, to_fields)

This relationship connects a diagram to its reactions. A
diagram shows multiple reactions, and a reaction can be on many
diagrams.
It has the following fields:

=over 4


=item location

Location of the reaction's node on the diagram.



=back

=cut

sub get_relationship_Displays
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Displays",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Displays: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Displays: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDisplayedOn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsDisplayedOn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDisplayedOn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDisplayedOn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDisplayedOn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Encompasses(ids, from_fields, rel_fields, to_fields)

This relationship connects a feature to a related
feature; for example, it would connect a gene to its
constituent splice variants, and the splice variants to their
exons.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Encompasses
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Encompasses",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Encompasses: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Encompasses: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsEncompassedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsEncompassedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsEncompassedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsEncompassedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsEncompassedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Formulated(ids, from_fields, rel_fields, to_fields)

This relationship connects a coregulated set to the
source organization that originally computed it.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Formulated
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Formulated",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Formulated: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Formulated: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_WasFormulatedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_WasFormulatedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_WasFormulatedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_WasFormulatedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_WasFormulatedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_GeneratedLevelsFor(ids, from_fields, rel_fields, to_fields)

This relationship connects an atomic regulon to a probe set from which experimental
data was produced for its features. It contains a vector of the expression levels.
It has the following fields:

=over 4


=item level_vector

Vector of expression levels (-1, 0, 1) for the experiments, in
sequence order.



=back

=cut

sub get_relationship_GeneratedLevelsFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_GeneratedLevelsFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_GeneratedLevelsFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_GeneratedLevelsFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_WasGeneratedFrom(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_WasGeneratedFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_WasGeneratedFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_WasGeneratedFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_WasGeneratedFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasAssertionFrom(ids, from_fields, rel_fields, to_fields)

Sources (users) can make assertions about identifiers using the annotation clearinghouse.
When a user makes a new assertion about an identifier, it erases the old one.
It has the following fields:

=over 4


=item function

The function is the text of the assertion made about the identifier.


=item expert

TRUE if this is an expert assertion, else FALSE



=back

=cut

sub get_relationship_HasAssertionFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasAssertionFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasAssertionFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasAssertionFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Asserts(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Asserts
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Asserts",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Asserts: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Asserts: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasCompoundAliasFrom(ids, from_fields, rel_fields, to_fields)

This relationship connects a source (database or organization)
with the compounds for which it has assigned names (aliases).
The alias itself is stored as intersection data.
It has the following fields:

=over 4


=item alias

alias for the compound assigned by the source



=back

=cut

sub get_relationship_HasCompoundAliasFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasCompoundAliasFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasCompoundAliasFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasCompoundAliasFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_UsesAliasForCompound(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_UsesAliasForCompound
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_UsesAliasForCompound",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_UsesAliasForCompound: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_UsesAliasForCompound: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasIndicatedSignalFrom(ids, from_fields, rel_fields, to_fields)

This relationship connects an experiment to a feature. The feature
expression levels inferred from the experimental results are stored here.
It has the following fields:

=over 4


=item rma_value

Normalized expression value for this feature under the experiment's
conditions.


=item level

Indication of whether the feature is expressed (1), not expressed (-1),
or unknown (0).



=back

=cut

sub get_relationship_HasIndicatedSignalFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasIndicatedSignalFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasIndicatedSignalFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasIndicatedSignalFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IndicatesSignalFor(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IndicatesSignalFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IndicatesSignalFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IndicatesSignalFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IndicatesSignalFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasMember(ids, from_fields, rel_fields, to_fields)

This relationship connects each feature family to its
constituent features. A family always has many features, and a
single feature can be found in many families.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_HasMember
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasMember",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasMember: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasMember: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsMemberOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsMemberOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsMemberOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsMemberOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsMemberOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasParticipant(ids, from_fields, rel_fields, to_fields)

A scenario consists of many participant reactions that
convert the input compounds to output compounds. A single reaction
may participate in many scenarios.
It has the following fields:

=over 4


=item type

Indicates the type of participaton. If 0, the
reaction is in the main pathway of the scenario. If 1, the
reaction is necessary to make the model work but is not in
the subsystem. If 2, the reaction is part of the subsystem
but should not be included in the modelling process.



=back

=cut

sub get_relationship_HasParticipant
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasParticipant",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasParticipant: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasParticipant: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_ParticipatesIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_ParticipatesIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_ParticipatesIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_ParticipatesIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_ParticipatesIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasPresenceOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a media to the compounds that
occur in it. The intersection data describes how much of each
compound can be found.
It has the following fields:

=over 4


=item concentration

concentration of the compound in the media


=item minimum_flux

minimum flux of the compound for this media


=item maximum_flux

maximum flux of the compound for this media



=back

=cut

sub get_relationship_HasPresenceOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasPresenceOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasPresenceOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasPresenceOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsPresentIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsPresentIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsPresentIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsPresentIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsPresentIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasReactionAliasFrom(ids, from_fields, rel_fields, to_fields)

This relationship connects a source (database or organization)
with the reactions for which it has assigned names (aliases).
The alias itself is stored as intersection data.
It has the following fields:

=over 4


=item alias

alias for the reaction assigned by the source



=back

=cut

sub get_relationship_HasReactionAliasFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasReactionAliasFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasReactionAliasFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasReactionAliasFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_UsesAliasForReaction(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_UsesAliasForReaction
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_UsesAliasForReaction",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_UsesAliasForReaction: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_UsesAliasForReaction: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasRepresentativeOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a genome to the FIGfam protein families
for which it has representative proteins. This information can be computed
from other relationships, but it is provided explicitly to allow fast access
to a genome's FIGfam profile.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_HasRepresentativeOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasRepresentativeOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasRepresentativeOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasRepresentativeOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRepresentedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsRepresentedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRepresentedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRepresentedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRepresentedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasResultsIn(ids, from_fields, rel_fields, to_fields)

This relationship connects a probe set to the experiments that were
applied to it.
It has the following fields:

=over 4


=item sequence

Sequence number of this experiment in the various result vectors.



=back

=cut

sub get_relationship_HasResultsIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasResultsIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasResultsIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasResultsIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasResultsFor(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasResultsFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasResultsFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasResultsFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasResultsFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasSection(ids, from_fields, rel_fields, to_fields)

This relationship connects a contig's sequence to its DNA
sequences.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_HasSection
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasSection",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasSection: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasSection: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsSectionOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsSectionOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsSectionOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsSectionOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsSectionOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasStep(ids, from_fields, rel_fields, to_fields)

This relationship connects a complex to the reaction
rules for the reactions that work together to make the complex
happen.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_HasStep
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasStep",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasStep: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasStep: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsStepOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsStepOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsStepOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsStepOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsStepOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasUsage(ids, from_fields, rel_fields, to_fields)

This relationship connects a biomass compound specification
to the compounds for which it is relevant.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_HasUsage
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasUsage",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasUsage: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasUsage: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsUsageOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsUsageOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsUsageOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsUsageOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsUsageOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasValueFor(ids, from_fields, rel_fields, to_fields)

This relationship connects an experiment to its attributes. The attribute
values are stored here.
It has the following fields:

=over 4


=item value

Value of this attribute in the given experiment. This is always encoded
as a string, but may in fact be a number.



=back

=cut

sub get_relationship_HasValueFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasValueFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasValueFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasValueFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasValueIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasValueIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasValueIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasValueIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasValueIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Imported(ids, from_fields, rel_fields, to_fields)

This relationship specifies the import source for
identifiers. It is used when reloading identifiers to
provide for rapid deletion of the previous load's results.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Imported
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Imported",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Imported: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Imported: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_WasImportedFrom(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_WasImportedFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_WasImportedFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_WasImportedFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_WasImportedFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Includes(ids, from_fields, rel_fields, to_fields)

A subsystem is defined by its roles. The subsystem's variants
contain slightly different sets of roles, but all of the roles in a
variant must be connected to the parent subsystem by this
relationship. A subsystem always has at least one role, and a role
always belongs to at least one subsystem.
It has the following fields:

=over 4


=item sequence

Sequence number of the role within the subsystem.
When the roles are formed into a variant, they will
generally appear in sequence order.


=item abbreviation

Abbreviation for this role in this subsystem. The
abbreviations are used in columnar displays, and they also
appear on diagrams.


=item auxiliary

TRUE if this is an auxiliary role, or FALSE if this role
is a functioning part of the subsystem.



=back

=cut

sub get_relationship_Includes
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Includes",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Includes: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Includes: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsIncludedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsIncludedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsIncludedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsIncludedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsIncludedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IndicatedLevelsFor(ids, from_fields, rel_fields, to_fields)

This relationship connects a feature to a probe set from which experimental
data was produced for the feature. It contains a vector of the expression levels.
It has the following fields:

=over 4


=item level_vector

Vector of expression levels (-1, 0, 1) for the experiments, in
sequence order.



=back

=cut

sub get_relationship_IndicatedLevelsFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IndicatedLevelsFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IndicatedLevelsFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IndicatedLevelsFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasLevelsFrom(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasLevelsFrom
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasLevelsFrom",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasLevelsFrom: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasLevelsFrom: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Involves(ids, from_fields, rel_fields, to_fields)

This relationship connects a reaction to the
reagents representing the compounds that participate in it.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Involves
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Involves",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Involves: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Involves: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInvolvedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsInvolvedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInvolvedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInvolvedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInvolvedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsARequirementIn(ids, from_fields, rel_fields, to_fields)

This relationship connects a model to its requirements.
A requirement represents the use of a reaction in a single model.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsARequirementIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsARequirementIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsARequirementIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsARequirementIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsARequirementOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsARequirementOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsARequirementOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsARequirementOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsARequirementOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsAlignedIn(ids, from_fields, rel_fields, to_fields)

This relationship connects each variation to the
contig regions that it aligns.
It has the following fields:

=over 4


=item start

start location of region


=item len

length of region


=item dir

direction of region (+ or -)



=back

=cut

sub get_relationship_IsAlignedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsAlignedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsAlignedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsAlignedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsAlignmentFor(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsAlignmentFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsAlignmentFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsAlignmentFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsAlignmentFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsAnnotatedBy(ids, from_fields, rel_fields, to_fields)

This relationship connects a feature to its annotations. A
feature may have multiple annotations, but an annotation belongs to
only one feature.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsAnnotatedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsAnnotatedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsAnnotatedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsAnnotatedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Annotates(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Annotates
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Annotates",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Annotates: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Annotates: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsBindingSiteFor(ids, from_fields, rel_fields, to_fields)

This relationship connects a coregulated set to the
binding site to which its feature attaches.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsBindingSiteFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsBindingSiteFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsBindingSiteFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsBindingSiteFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsBoundBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsBoundBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsBoundBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsBoundBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsBoundBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsClassFor(ids, from_fields, rel_fields, to_fields)

This relationship connects each subsystem class with the
subsystems that belong to it. A class can contain many subsystems,
but a subsystem is only in one class. Some subsystems are not in any
class, but this is usually a temporary condition.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsClassFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsClassFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsClassFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsClassFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInClass(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsInClass
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInClass",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInClass: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInClass: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsCollectionOf(ids, from_fields, rel_fields, to_fields)

A genome belongs to only one genome set. For each set, this relationship marks the genome to be used as its representative.
It has the following fields:

=over 4


=item representative

TRUE for the representative genome of the set, else FALSE.



=back

=cut

sub get_relationship_IsCollectionOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsCollectionOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsCollectionOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsCollectionOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsCollectedInto(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsCollectedInto
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsCollectedInto",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsCollectedInto: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsCollectedInto: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsComposedOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a genome to its
constituent contigs. Unlike contig sequences, a
contig belongs to only one genome.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsComposedOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsComposedOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsComposedOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsComposedOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsComponentOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsComponentOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsComponentOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsComponentOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsComponentOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsComprisedOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a biomass to the compound
specifications that define it.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsComprisedOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsComprisedOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsComprisedOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsComprisedOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Comprises(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Comprises
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Comprises",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Comprises: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Comprises: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsConfiguredBy(ids, from_fields, rel_fields, to_fields)

This relationship connects a genome to the atomic regulons that
describe its state.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsConfiguredBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsConfiguredBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsConfiguredBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsConfiguredBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_ReflectsStateOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_ReflectsStateOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_ReflectsStateOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_ReflectsStateOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_ReflectsStateOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsConsistentWith(ids, from_fields, rel_fields, to_fields)

This relationship connects a functional role to the EC numbers consistent
with the chemistry described in the role.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsConsistentWith
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsConsistentWith",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsConsistentWith: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsConsistentWith: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsConsistentTo(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsConsistentTo
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsConsistentTo",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsConsistentTo: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsConsistentTo: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsCoregulatedWith(ids, from_fields, rel_fields, to_fields)

This relationship connects a feature with another feature in the
same genome with which it appears to be coregulated as a result of
expression data analysis.
It has the following fields:

=over 4


=item coefficient

Pearson correlation coefficient for this coregulation.



=back

=cut

sub get_relationship_IsCoregulatedWith
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsCoregulatedWith",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsCoregulatedWith: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsCoregulatedWith: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasCoregulationWith(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasCoregulationWith
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasCoregulationWith",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasCoregulationWith: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasCoregulationWith: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsCoupledTo(ids, from_fields, rel_fields, to_fields)

This relationship connects two FIGfams that we believe to be related
either because their members occur in proximity on chromosomes or because
the members are expressed together. Such a relationship is evidence the
functions of the FIGfams are themselves related. This relationship is
commutative; only the instance in which the first FIGfam has a lower ID
than the second is stored.
It has the following fields:

=over 4


=item co_occurrence_evidence

number of times members of the two FIGfams occur close to each
other on chromosomes


=item co_expression_evidence

number of times members of the two FIGfams are co-expressed in
expression data experiments



=back

=cut

sub get_relationship_IsCoupledTo
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsCoupledTo",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsCoupledTo: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsCoupledTo: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsCoupledWith(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsCoupledWith
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsCoupledWith",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsCoupledWith: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsCoupledWith: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDefaultFor(ids, from_fields, rel_fields, to_fields)

This relationship connects a reaction to the compartment
in which it runs by default.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsDefaultFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDefaultFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDefaultFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDefaultFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_RunsByDefaultIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_RunsByDefaultIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_RunsByDefaultIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_RunsByDefaultIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_RunsByDefaultIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDefaultLocationOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a reagent to the compartment
which is its default location during the reaction.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsDefaultLocationOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDefaultLocationOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDefaultLocationOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDefaultLocationOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasDefaultLocation(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasDefaultLocation
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasDefaultLocation",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasDefaultLocation: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasDefaultLocation: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDeterminedBy(ids, from_fields, rel_fields, to_fields)

A functional coupling evidence set exists because it has
pairings in it, and this relationship connects the evidence set to
its constituent pairings. A pairing cam belong to multiple evidence
sets.
It has the following fields:

=over 4


=item inverted

A pairing is an unordered pair of protein sequences,
but its similarity to other pairings in a pair set is
ordered. Let (A,B) be a pairing and (X,Y) be another pairing
in the same set. If this flag is FALSE, then (A =~ X) and (B
=~ Y). If this flag is TRUE, then (A =~ Y) and (B =~
X).



=back

=cut

sub get_relationship_IsDeterminedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDeterminedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDeterminedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDeterminedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Determines(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Determines
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Determines",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Determines: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Determines: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDividedInto(ids, from_fields, rel_fields, to_fields)

This relationship connects a model to the cell compartments
that participate in the model.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsDividedInto
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDividedInto",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDividedInto: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDividedInto: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsDivisionOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsDivisionOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsDivisionOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsDivisionOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsDivisionOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsExemplarOf(ids, from_fields, rel_fields, to_fields)

This relationship links a role to a feature that provides a typical
example of how the role is implemented.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsExemplarOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsExemplarOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsExemplarOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsExemplarOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasAsExemplar(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasAsExemplar
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasAsExemplar",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasAsExemplar: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasAsExemplar: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsFamilyFor(ids, from_fields, rel_fields, to_fields)

This relationship connects an isofunctional family to the roles that
make up its assigned function.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsFamilyFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsFamilyFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsFamilyFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsFamilyFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_DeterminesFunctionOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_DeterminesFunctionOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_DeterminesFunctionOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_DeterminesFunctionOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_DeterminesFunctionOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsFormedOf(ids, from_fields, rel_fields, to_fields)

This relationship connects each feature to the atomic regulon to
which it belongs.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsFormedOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsFormedOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsFormedOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsFormedOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsFormedInto(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsFormedInto
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsFormedInto",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsFormedInto: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsFormedInto: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsFunctionalIn(ids, from_fields, rel_fields, to_fields)

This relationship connects a role with the features in which
it plays a functional part.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsFunctionalIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsFunctionalIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsFunctionalIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsFunctionalIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasFunctional(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasFunctional
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasFunctional",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasFunctional: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasFunctional: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsGroupFor(ids, from_fields, rel_fields, to_fields)

The recursive IsGroupFor relationship organizes
taxonomic groupings into a hierarchy based on the standard organism
taxonomy.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsGroupFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsGroupFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsGroupFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsGroupFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInGroup(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsInGroup
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInGroup",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInGroup: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInGroup: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsImplementedBy(ids, from_fields, rel_fields, to_fields)

This relationship connects a variant to the physical machines
that implement it in the genomes. A variant is implemented by many
machines, but a machine belongs to only one variant.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsImplementedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsImplementedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsImplementedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsImplementedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Implements(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Implements
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Implements",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Implements: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Implements: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInPair(ids, from_fields, rel_fields, to_fields)

A pairing contains exactly two protein sequences. A protein
sequence can belong to multiple pairings. When going from a protein
sequence to its pairings, they are presented in alphabetical order
by sequence key.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsInPair
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInPair",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInPair: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInPair: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsPairOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsPairOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsPairOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsPairOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsPairOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInstantiatedBy(ids, from_fields, rel_fields, to_fields)

This relationship connects a compartment to the instances
of that compartment that occur in models.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsInstantiatedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInstantiatedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInstantiatedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInstantiatedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInstanceOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsInstanceOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInstanceOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInstanceOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInstanceOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsLocatedIn(ids, from_fields, rel_fields, to_fields)

A feature is a set of DNA sequence fragments. Most features
are a single contiquous fragment, so they are located in only one
DNA sequence; however, fragments have a maximum length, so even a
single contiguous feature may participate in this relationship
multiple times. A few features belong to multiple DNA sequences. In
that case, however, all the DNA sequences belong to the same genome.
A DNA sequence itself will frequently have thousands of features
connected to it.
It has the following fields:

=over 4


=item ordinal

Sequence number of this segment, starting from 1
and proceeding sequentially forward from there.


=item begin

Index (1-based) of the first residue in the contig
that belongs to the segment.


=item len

Length of this segment.


=item dir

Direction (strand) of the segment: "+" if it is
forward and "-" if it is backward.



=back

=cut

sub get_relationship_IsLocatedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsLocatedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsLocatedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsLocatedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsLocusFor(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsLocusFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsLocusFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsLocusFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsLocusFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsModeledBy(ids, from_fields, rel_fields, to_fields)

A genome can be modeled by many different models, but a model belongs
to only one genome.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsModeledBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsModeledBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsModeledBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsModeledBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Models(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Models
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Models",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Models: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Models: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsNamedBy(ids, from_fields, rel_fields, to_fields)

The normal case is that an identifier names a single
protein sequence, while a protein sequence can have many identifiers,
but some identifiers name multiple sequences.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsNamedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsNamedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsNamedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsNamedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Names(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Names
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Names",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Names: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Names: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsOwnerOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a genome to the features it
contains. Though technically redundant (the information is
available from the feature's contigs), it simplifies the
extremely common process of finding all features for a
genome.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsOwnerOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsOwnerOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsOwnerOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsOwnerOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsOwnedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsOwnedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsOwnedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsOwnedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsOwnedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsProposedLocationOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a reaction as it is used in
a complex to the compartments in which it usually takes place.
Most reactions take place in a single compartment. Transporters
take place in two compartments.
It has the following fields:

=over 4


=item type

role of the compartment in the reaction: 'primary'
if it is the sole or starting compartment, 'secondary' if
it is the ending compartment in a multi-compartmental
reaction



=back

=cut

sub get_relationship_IsProposedLocationOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsProposedLocationOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsProposedLocationOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsProposedLocationOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasProposedLocationIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasProposedLocationIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasProposedLocationIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasProposedLocationIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasProposedLocationIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsProteinFor(ids, from_fields, rel_fields, to_fields)

This relationship connects a peg feature to the protein
sequence it produces (if any). Only peg features participate in this
relationship. A single protein sequence will frequently be produced
by many features.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsProteinFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsProteinFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsProteinFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsProteinFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Produces(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Produces
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Produces",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Produces: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Produces: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRealLocationOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a model's instance of a reaction
to the compartments in which it takes place. Most instances
take place in a single compartment. Transporters use two compartments.
It has the following fields:

=over 4


=item type

role of the compartment in the reaction: 'primary'
if it is the sole or starting compartment, 'secondary' if
it is the ending compartment in a multi-compartmental
reaction



=back

=cut

sub get_relationship_IsRealLocationOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRealLocationOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRealLocationOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRealLocationOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasRealLocationIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasRealLocationIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasRealLocationIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasRealLocationIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasRealLocationIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRegulatedIn(ids, from_fields, rel_fields, to_fields)

This relationship connects a feature to the set of coregulated features.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsRegulatedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRegulatedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRegulatedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRegulatedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRegulatedSetOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsRegulatedSetOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRegulatedSetOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRegulatedSetOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRegulatedSetOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRelevantFor(ids, from_fields, rel_fields, to_fields)

This relationship connects a diagram to the subsystems that are depicted on
it. Only diagrams which are useful in curating or annotation the subsystem are
specified in this relationship.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsRelevantFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRelevantFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRelevantFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRelevantFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRelevantTo(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsRelevantTo
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRelevantTo",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRelevantTo: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRelevantTo: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRequiredBy(ids, from_fields, rel_fields, to_fields)

This relationship links a reaction to the way it is used in a model.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsRequiredBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRequiredBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRequiredBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRequiredBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Requires(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Requires
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Requires",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Requires: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Requires: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRoleOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a role to the machine roles that
represent its appearance in a molecular machine. A machine role has
exactly one associated role, but a role may be represented by many
machine roles.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsRoleOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRoleOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRoleOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRoleOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasRole(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasRole
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasRole",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasRole: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasRole: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRowOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a subsystem spreadsheet row to its
constituent spreadsheet cells.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsRowOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRowOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRowOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRowOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsRoleFor(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsRoleFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsRoleFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsRoleFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsRoleFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsSequenceOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a Contig as it occurs in a
genome to the Contig Sequence that represents the physical
DNA base pairs. A contig sequence may represent many contigs,
but each contig has only one sequence.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsSequenceOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsSequenceOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsSequenceOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsSequenceOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasAsSequence(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasAsSequence
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasAsSequence",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasAsSequence: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasAsSequence: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsSubInstanceOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a scenario to its subsystem it
validates. A scenario belongs to exactly one subsystem, but a
subsystem may have multiple scenarios.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsSubInstanceOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsSubInstanceOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsSubInstanceOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsSubInstanceOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Validates(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Validates
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Validates",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Validates: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Validates: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsSuperclassOf(ids, from_fields, rel_fields, to_fields)

This is a recursive relationship that imposes a hierarchy on
the subsystem classes.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsSuperclassOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsSuperclassOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsSuperclassOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsSuperclassOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsSubclassOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsSubclassOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsSubclassOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsSubclassOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsSubclassOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsTargetOf(ids, from_fields, rel_fields, to_fields)

This relationship connects a compound in a biomass to the
compartment in which it is supposed to appear.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsTargetOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsTargetOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsTargetOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsTargetOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Targets(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Targets
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Targets",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Targets: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Targets: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsTaxonomyOf(ids, from_fields, rel_fields, to_fields)

A genome is assigned to a particular point in the taxonomy tree, but not
necessarily to a leaf node. In some cases, the exact species and strain is
not available when inserting the genome, so it is placed at the lowest node
that probably contains the actual genome.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsTaxonomyOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsTaxonomyOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsTaxonomyOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsTaxonomyOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsInTaxa(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsInTaxa
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsInTaxa",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsInTaxa: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsInTaxa: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsTerminusFor(ids, from_fields, rel_fields, to_fields)

A terminus for a scenario is a compound that acts as its
input or output. A compound can be the terminus for many scenarios,
and a scenario will have many termini. The relationship attributes
indicate whether the compound is an input to the scenario or an
output. In some cases, there may be multiple alternative output
groups. This is also indicated by the attributes.
It has the following fields:

=over 4


=item group_number

If zero, then the compound is an input. If one, the compound is
an output. If two, the compound is an auxiliary output.



=back

=cut

sub get_relationship_IsTerminusFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsTerminusFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsTerminusFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsTerminusFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HasAsTerminus(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HasAsTerminus
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HasAsTerminus",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HasAsTerminus: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HasAsTerminus: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsTriggeredBy(ids, from_fields, rel_fields, to_fields)

A complex can be triggered by many roles. A role can
trigger many complexes.
It has the following fields:

=over 4


=item optional

TRUE if the role is not necessarily required to trigger the
complex, else FALSE


=item type

ask Chris



=back

=cut

sub get_relationship_IsTriggeredBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsTriggeredBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsTriggeredBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsTriggeredBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Triggers(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_Triggers
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Triggers",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Triggers: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Triggers: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsUsedAs(ids, from_fields, rel_fields, to_fields)

This relationship connects a reaction to its usage in
specific complexes.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_IsUsedAs
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsUsedAs",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsUsedAs: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsUsedAs: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsUseOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsUseOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsUseOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsUseOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsUseOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Manages(ids, from_fields, rel_fields, to_fields)

This relationship connects a model to the biomasses
that are monitored to determine whether or not the model
is effective.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Manages
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Manages",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Manages: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Manages: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsManagedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsManagedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsManagedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsManagedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsManagedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_OperatesIn(ids, from_fields, rel_fields, to_fields)

This relationship connects an experiment to the media in which the
experiment took place.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_OperatesIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_OperatesIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_OperatesIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_OperatesIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsUtilizedIn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsUtilizedIn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsUtilizedIn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsUtilizedIn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsUtilizedIn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Overlaps(ids, from_fields, rel_fields, to_fields)

A Scenario overlaps a diagram when the diagram displays a
portion of the reactions that make up the scenario. A scenario may
overlap many diagrams, and a diagram may be include portions of many
scenarios.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Overlaps
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Overlaps",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Overlaps: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Overlaps: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IncludesPartOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IncludesPartOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IncludesPartOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IncludesPartOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IncludesPartOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_ParticipatesAs(ids, from_fields, rel_fields, to_fields)

This relationship connects a compound to the reagents
that represent its participation in reactions.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_ParticipatesAs
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_ParticipatesAs",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_ParticipatesAs: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_ParticipatesAs: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsParticipationOf(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsParticipationOf
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsParticipationOf",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsParticipationOf: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsParticipationOf: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_ProducedResultsFor(ids, from_fields, rel_fields, to_fields)

This relationship connects a probe set to a genome for which it was
used to produce experimental results. In general, a probe set is used for
only one genome and vice versa, but this is not a requirement.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_ProducedResultsFor
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_ProducedResultsFor",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_ProducedResultsFor: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_ProducedResultsFor: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_HadResultsProducedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_HadResultsProducedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_HadResultsProducedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_HadResultsProducedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_HadResultsProducedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_ProjectsOnto(ids, from_fields, rel_fields, to_fields)

This relationship connects two protein sequences for which a clear
bidirectional best hit exists in known genomes. The attributes of the
relationship describe how good the relationship is between the proteins.
The relationship is bidirectional and symmetric, but is only stored in
one direction (lower ID to higher ID).
It has the following fields:

=over 4


=item gene_context

number of homologous genes in the immediate context of the
two proteins, up to a maximum of 10


=item percent_identity

percent match between the two protein sequences


=item score

score describing the strength of the projection, from 0 to 1,
where 1 is the best



=back

=cut

sub get_relationship_ProjectsOnto
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_ProjectsOnto",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_ProjectsOnto: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_ProjectsOnto: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsProjectedOnto(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsProjectedOnto
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsProjectedOnto",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsProjectedOnto: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsProjectedOnto: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Provided(ids, from_fields, rel_fields, to_fields)

This relationship connects a source (core) database
to the subsystems it submitted to the knowledge base.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Provided
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Provided",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Provided: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Provided: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_WasProvidedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_WasProvidedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_WasProvidedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_WasProvidedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_WasProvidedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Shows(ids, from_fields, rel_fields, to_fields)

This relationship indicates that a compound appears on a
particular diagram. The same compound can appear on many diagrams,
and a diagram always contains many compounds.
It has the following fields:

=over 4


=item location

Location of the compound's node on the diagram.



=back

=cut

sub get_relationship_Shows
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Shows",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Shows: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Shows: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsShownOn(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsShownOn
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsShownOn",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsShownOn: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsShownOn: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Submitted(ids, from_fields, rel_fields, to_fields)

This relationship connects a genome to the
core database from which it was loaded.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Submitted
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Submitted",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Submitted: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Submitted: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_WasSubmittedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_WasSubmittedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_WasSubmittedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_WasSubmittedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_WasSubmittedBy: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_Uses(ids, from_fields, rel_fields, to_fields)

This relationship connects a genome to the machines that form
its metabolic pathways. A genome can use many machines, but a
machine is used by exactly one genome.
It has the following fields:

=over 4



=back

=cut

sub get_relationship_Uses
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_Uses",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_Uses: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_Uses: " . $self->{client}->status_line;
    }
}



=head2 $result = get_relationship_IsUsedBy(ids, from_fields, rel_fields, to_fields)



=cut

sub get_relationship_IsUsedBy
{
    my($self, @args) = @_;

    @args == 4 or die "Invalid argument count (expecting 4)";
    my $result = $self->{client}->call($self->{url}, {
	method => "CDMI_EntityAPI.get_relationship_IsUsedBy",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    die "Error invoking get_relationship_IsUsedBy: " . $result->error_message;
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
	die "Error invoking get_relationship_IsUsedBy: " . $self->{client}->status_line;
    }
}




1;
