#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  generateTablesForBruce.pl
#
#        USAGE:  ./generateTablesForBruce.pl --help
#
#  DESCRIPTION:  Generate tab delimited files for Kbase upload
#
#===============================================================================
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
use Cwd qw(abs_path);
use ModelSEED::ObjectManager;
use Tie::Hash::Sorted;

my ($mapping, $biochem, $directory, $help);
GetOptions( "directory|dir|d=s" => \$directory,
            "biochemistry|b|bio=s" => \$biochem,
            "mapping|m|map=s"   => \$mapping,
            "help|h|?" => \$help ) || pod2usage(2);
pod2usage(1) if $help;
unless(defined($directory) && -d $directory && defined($mapping) && defined($biochem)) {
    pod2usage(2);
}
# Normalize the output directory
$directory = abs_path($directory);
$directory =~ s/\/$//;
# Get the biochemistry and mapping objects
my $om = ModelSEED::ObjectManager->new({
    database => "$ENV{HOME}/test.db",
    driver   => "SQLite",
});
my ($Busername, $Bname) = split(/\//, $biochem);
my ($Musername, $Mname) = split(/\//, $mapping);
my $biochemObj = $om->get_object("biochemistry",
     query => [
        'alias.username' => $Busername,
        'alias.id' => $Bname ],
    require_objects => [ 'alias' ]
);
my $mappingObj = $om->get_object("mapping",
     query => [
        'alias.username' => $Musername,
        'alias.id' => $Mname ],
    require_objects => [ 'alias' ]
);
die "Could not find biochemistry $biochem!\n" unless($biochemObj);
die "Could not find mappingistry $mapping!\n" unless($mappingObj);
# Now start generating the files
sub buildTable {
    my ($filename, $columns, $dataObjects, $preimages, $append) = @_;
    # filename    : file to print to
    # columns     : hash where keys are column names and the values are either
    #               strings (in which case they are attributes of RoseDB objects)
    #               or CODE references (in which case they produce the column value
    #               when called on the RoseDB object.
    # dataObjects : array of data objects (RoseDB)
    # preimages   : array of sortedHashes
    my $mode = ($append) ? ">>" : ">"; # either append or overwrite
    open(my $fh, $mode, $filename) || die("Could not open file $filename!\n");
    my $allColumns = { map { $_ => 1 } keys %$columns };
    for(my $i=0; $i<@$dataObjects; $i++) {
        map { $allColumns->{$_} = 1 } keys %{$preimages->[$i]};
        foreach my $key (sort keys %$columns) {
            my $val = $columns->{$key};
            if(ref($val) eq "CODE") {
                $preimages->[$i]->{$key} = $val->($dataObjects->[$i]);
            } else {
                $preimages->[$i]->{$key} = $dataObjects->[$i]->$val || '';
            } 
        }
    }
    # Print column headers unless we're appending
    print $fh join("\t", sort keys %$allColumns) . "\n" unless($append);
    foreach my $preimage (@$preimages) {
        print $fh join("\t", map { $preimage->{$_} } sort keys %$preimage) . "\n";
    }
    close($fh);
}
#
#    Compartment: A compartment is a section of a single model that represents the
#                 environment in which a reaction takes place (e.g. cell wall).
#    
#        Table: Compartment
#            id (int): Unique identifier for this Compartment. # FIXME - ids are not ints
#            mod-date (date): date and time of the last modification to the compartment's
#                             definition
#            name (string): common name for the compartment
#    
{
    my $a = {
        id => 'id',
        'mod-date' => 'modDate',
        name => 'name',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/compartment.dtx", \%columns, [$mappingObj->compartment()]);
} 
#    
#    Complex: A complex is a set of chemical reactions that act in concert to effect
#             a role.
#    
#        Table: Complex
#            id (string): Unique identifier for this Complex.
#            mod-date (date): date and time of the last change to this complex's
#                             definition
{
    my $a = {
        id => 'id',
        'mod-date' => 'modDate',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/complex.dtx", \%columns, [$mappingObj->complexes()]);
} 
#    
#        Table: ComplexName
#            id (string): Unique identifier for this Complex.
#            name (string): name of this complex. Not all complexes have names.
#    
{
    my $a = {
        id => 'id',
        name => 'name',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/complexName.dtx", \%columns, [$mappingObj->complexes()]);
}
#    
#    Compound: A compound is a chemical that participates in a reaction. Both ligands
#              and reaction components are treated as compounds.
#    
#        Table: Compound
#            id (string): Unique identifier for this Compound.
#            mass (float): atomic mass of the compound
#            mod-date (date): date and time of the last modification to the compound
#                             definition
#            ubiquitous (boolean): TRUE if this compound is found in most reactions,
#                                  else FALSE
#            abbr (string): shortened abbreviation for the compound name
#            formula (string): a pH-neutral formula for the compound
#            label (string): primary name of the compound, for use in displaying
#                            reactions
#            uncharged-formula (string): a electrically neutral formula for the compound
#    
{
    my $a = {
        id => 'uuid',
        mass => 'mass',
        'mod-date' => 'modDate',
        abbr => 'abbreviation',
        formula => 'formula',
        label => 'name',
        'uncharged-formula' => 'unchargedFormula',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/compound.dtx", \%columns, [$biochemObj->compound()]);
}
#    
#    Media: A media describes the chemical content of the solution in which cells
#           are grown in an experiment or for the purposes of a model. The key is
#           the common media name. The nature of the media is described by its relationship
#           to its constituent compounds.
#    
#        Table: Media
#            id (string): Unique identifier for this Media.
#            defined (boolean): A media is considered defined if the exact chemical
#                               content is known.
#            mod-date (date): date and time of the last modification to the media's
#                             definition
#            name (string): descriptive name of the media
#            source (string): Publication or laboratory that provided the source
#                             information for the media.
#            type (string): type of the medium (aerobic or anaerobic)
{
    my $a = {
        id => 'uuid', 
        'mod-date' => 'modDate',
        name => 'name',
        type => 'type',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/media.dtx", \%columns, [$biochemObj->media()]);
}
#    
#    
#    Reaction: A reaction is a chemical process that converts one set of compounds
#              (substrate) to another set (products).
#    
#        Table: Reaction
#            id (string): Unique identifier for this Reaction.
#            mod-date (date): date and time of the last modification to this reaction's
#                             definition
#            reversability (char): direction of this reaction (> for forward-only,
#                                  < for backward-only, = for bidirectional)
#            abbr (string): abbreviated name of this reaction
#            name (string): descriptive name of this reaction
#            equation (text): displayable formula for the reaction
#    
{
    my $a = {
        id => 'uuid',
        'mod-date' => 'modDate',
        reversability => 'reversibility', # FIXME SPELLING
        abbr => 'abbreviation',
        name => 'name',
        equation => 'equation',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/reaction.dtx", \%columns, [$biochemObj->reaction()]);
}
#    
#    ReactionComplex: A reaction complex represents a reaction as it takes place
#                     within the context of a specific complex.
#    
#        Table: ReactionComplex
#            id (string): Unique identifier for this ReactionComplex.
#            direction (char): reaction directionality (> for forward, < for backward,
#                              = for bidirectional) with respect to this complex
#            transproton (float): ask Chris
#    
{
    my $a = {
        id => sub { return $_[0]->reaction . $_[0]->complex; },
        reaction => 'reaction',
        complex  => 'complex',
        direction => 'direction',
        'transproton-nature' => 'transprotonNature',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $rxncpxs = [];
    foreach my $complex ($mappingObj->complexes()) {
       push(@$rxncpxs, $complex->reaction_complex()); 
    }
    buildTable("$directory/reactionComplex.dtx", \%columns, $rxncpxs);
}
#    
#    HasCompoundAliasFrom: This relationship connects a source (database or organization)
#                          with the compounds for which it has assigned names (aliases).
#                          The alias itself is stored as intersection data.
#    
#        Table: HasCompoundAliasFrom
#            from-link (string): id of the source Source.
#            to-link (string): id of the target Compound.
#            alias (string): alias for the compound assigned by the source
#
{
    my $a = { 
        'from-link' => 'type',
        'to-link' => 'compound',
        alias => 'alias',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/hasCompoundAliasFrom.dtx", \%columns, [$biochemObj->compound_alias()]);
}
#    
#    HasPresenceOf: This relationship connects a media to the compounds that occur
#                   in it. The intersection data describes how much of each compound
#                   can be found.
#    
#        Table: HasPresenceOf
#            from-link (string): id of the source Media.
#            to-link (string): id of the target Compound.
#            concentration (float): concentration of the compound in the media
#            maximum-flux (float): maximum flux of the compound for this media
#            minimum-flux (float): minimum flux of the compound for this media
#    
{
    my $a = { 
        'from-link' => 'media',
        'to-link' => 'compound',
        concentration => 'concentration',
        'maximum-flux' => 'maxflux',
        'minimum-flux' => 'minflux',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $mediaCompounds = [];
    foreach my $media ($biochemObj->media()) {
        push(@$mediaCompounds, $media->media_compound());
    }
    buildTable("$directory/hasPresenceOf.dtx", \%columns, $mediaCompounds);
}
#    
#    HasReactionAliasFrom: This relationship connects a source (database or organization)
#                          with the reactions for which it has assigned names (aliases).
#                          The alias itself is stored as intersection data.
#    
#        Table: HasReactionAliasFrom
#            from-link (string): id of the source Source.
#            to-link (string): id of the target Reaction.
#            alias (string): alias for the reaction assigned by the source
#    
{
    my $a = { 
        'from-link' => 'type',
        'to-link' => 'reaction',
        alias => 'alias',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/hasReactionAliasFrom.dtx", \%columns, [$biochemObj->reaction_alias()]);
}
#    
#    HasStep: This relationship connects a complex to the reaction instances that
#             work together to make the complex happen.
#    
#        Table: HasStep
#            from-link (string): id of the source Complex.
#            to-link (string): id of the target Reaction.
#    
{
    my $a = { 
        'from-link' => 'complex',
        'to-link' => 'reaction',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $cpxrxns = [];
    foreach my $complex ($mappingObj->complexes()) {
        push(@$cpxrxns, $complex->reaction_complex());
    }
    buildTable("$directory/hasStep.dtx", \%columns, $cpxrxns);
}
#    
#    Involves: This relationship connects a reaction to the compounds that participate
#              in it. A reaction involves many compounds, and a compound can be involved
#              in many reactions. The relationship attributes indicate whether a
#              compound is a product or substrate of the reaction, as well as its
#              stoichiometry.
#    
#        Table: Involves
#            from-link (string): id of the source Reaction.
#            to-link (string): id of the target Compound.
#            cofactor (boolean): TRUE if the compound is a cofactor; FALSE if it
#                                is a major component of the reaction.
#            product (boolean): TRUE if the compound is a product of the reaction, # FIXME - no, not there
#                               FALSE if it is a substrate. When a reaction is written
#                               on paper in chemical notation, the substrates are
#                               left of the arrow and the products are to the right.
#                               Sorting on this field will cause the substrates to
#                               appear first, followed by the products. If the reaction
#                               is reversible, then the notion of substrates and
#                               products is not intuitive; however, a value here
#                               of FALSE still puts the compound left of the arrow
#                               and a value of TRUE still puts it to the right.
#            stoichiometry (float): Number of molecules of the compound that participate
#                                   in a single instance of the reaction. For example,
#                                   if a reaction produces two water molecules, the
#                                   stoichiometry of water for the reaction would
#                                   be two. When a reaction is written on paper in
#                                   chemical notation, the stoichiometry is the number
#                                   next to the chemical formula of the compound.
#    
{
    my $a = { 
        'from-link' => 'reaction',
        'to-link' => 'compound',
        cofactor => 'cofactor',
        stoichiometry => 'coefficient', 
        'exterior-compartment' => 'exteriorCompartment',
        product => sub { return ($_[0]->coefficient > 0) ? 1 : 0; },
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $rxncpd = [];
    my $preimages = [];
    foreach my $reaction ($biochemObj->reaction()) {
        push(@$rxncpd, $reaction->reaction_compound());
    }
    buildTable("$directory/Involves.dtx", \%columns, $rxncpd);
}
#    
#    IsProposedLocationOf: This relationship connects a reaction as it is used in
#                          a complex to the compartments in which it usually takes
#                          place. Most reactions take place in a single compartment.
#                          Transporters take place in two compartments.
#    
#        Table: IsProposedLocationOf
#            from-link (int): id of the source Compartment. # FIXME ids are not ints
#            to-link (string): id of the target ReactionComplex.
#            type (string): role of the compartment in the reaction: 'primary' if
#                           it is the sole or starting compartment, 'secondary' if
#                           it is the ending compartment in a multi-compartmental
#                           reaction
{
    my $a = { 
        'from-link' => 'interiorCompartment',
        'to-link' => sub { return $_[0]->reaction . $_[0]->complex; },
        type => sub { return 'interior'; },
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $rxncpd = [];
    my $preimages = [];
    foreach my $reaction ($biochemObj->reaction()) {
        push(@$rxncpd, $reaction->reaction_compound());
    }
    buildTable("$directory/Involves.dtx", \%columns, $rxncpd);
}
{
    my $a = { 
        'from-link' => 'exteriorCompartment',
        'to-link' => sub { return $_[0]->reaction . $_[0]->complex; },
        type => sub { return 'exterior'; },
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $rxncpd = [];
    my $preimages = [];
    foreach my $reaction ($biochemObj->reaction()) {
        push(@$rxncpd, $reaction->reaction_compound());
    }
    buildTable("$directory/Involves.dtx", \%columns, $rxncpd, $preimages, "append");
}
    
#    
#    
#    IsTriggeredBy: A complex can be triggered by many roles. A role can trigger
#                   many complexes.
#    
#        Table: IsTriggeredBy
#            from-link (string): id of the source Complex.
#            to-link (string): id of the target Role.
#            optional (boolean): TRUE if the role is not necessarily required to
#                                trigger the complex, else FALSE
#            type (char): ask Chris
#    
{
    my $a = { 
        'from-link' => 'complex',
        'to-link' => 'role',
        optional => 'optional',
        type => 'type',
    };
    my $cpxroles = [];
    foreach my $complex ($mappingObj->complexes()) {
        push(@$cpxroles, $complex->complex_role());
    }
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/isTriggeredBy.dtx", \%columns, $cpxroles);
}
#    
#    IsUsedAs: This relationship connects a reaction to its usage in specific complexes.
#    
#        Table: IsUsedAs
#            from-link (string): id of the source Reaction.
#            to-link (string): id of the target ReactionComplex.
{
    my $a = { 
        'from-link' => 'reaction',
        'to-link' => sub { return $_[0]->reaction . $_[0]->complex; },
    };
    my $cpxroles = [];
    foreach my $complex ($mappingObj->complexes()) {
        push(@$cpxroles, $complex->reaction_complex());
    }
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/isUsedAs.dtx", \%columns, $cpxroles);
}


__END__

=head1 generateTablesForKbase

generateTablesForKbase --map master/main --bio master/main --dir /path/to/dir

=cut
