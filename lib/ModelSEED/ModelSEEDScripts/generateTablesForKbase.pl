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

my ($mapping, $biochem, $directory, $database, $help);
GetOptions( "directory|dir|d=s" => \$directory,
            "biochemistry|b|bio=s" => \$biochem,
            "mapping|m|map=s"   => \$mapping,
            "db|database=s" => \$database,
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
    database => abs_path($database),
    driver   => "SQLite",
});
my ($Busername, $Bname) = split(/\//, $biochem);
my ($Musername, $Mname) = split(/\//, $mapping);
my $biochemObj = $om->get_object("biochemistry",
     query => [
        'biochemistry_aliases.username' => $Busername,
        'biochemistry_aliases.id' => $Bname ],
    require_objects => [ 'biochemistry_aliases' ]
);
my $mappingObj = $om->get_object("mapping",
     query => [
        'mapping_aliases.username' => $Musername,
        'mapping_aliases.id' => $Mname ],
    require_objects => [ 'mapping_aliases' ]
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
            } elsif(ref($dataObjects->[$i]) eq 'HASH') {
                $preimages->[$i]->{$key} = $dataObjects->[$i]->{$val} || ''; 
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
#            id (int): Unique identifier for this Compartment.
#            mod-date (date): date and time of the last modification to
#                             the compartment's definition
#            name (string): common name for the compartment
#    
{
    my $a = {
        id => 'uuid',
        msid => 'id',
        'mod-date' => 'modDate',
        name => 'name',
        abbr => 'id',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/compartment.dtx", \%columns, [$biochemObj->compartments()]);
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
        id => 'uuid',
        msid => 'id',
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
        id => 'uuid',
        msid => 'id',
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
        msid => 'id',
        mass => 'mass',
        'mod-date' => 'modDate',
        abbr => 'abbreviation',
        formula => 'formula',
        label => 'name',
        'uncharged-formula' => 'unchargedFormula',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/compound.dtx", \%columns, [$biochemObj->compounds()]);
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
        msid => 'id',
        'mod-date' => 'modDate',
        reversibility => 'reversibility',
        abbr => 'abbreviation',
        name => 'name',
        equation => 'equation',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/reaction.dtx", \%columns, [$biochemObj->reactions()]);
}
#   ReactionRule: A rule for how a reaction will be implemented in a model.
#
#       Table: ReactionRule
#           id (string): Unique identifier for this ReactionRule.
#           reaction (string): Unique identifer for reaction that this rule implements.
#           direction (char): reaction directionality (> for forward, < for backward, = for bidirectional)
#           compartment (string): Unique identifer for compartment that reaction is implemented in.
#           transproton-nature (string): Description of cues for transport change balance.
#
{
    my $a = {
        id => 'uuid',
        reaction => 'reaction_uuid',
        direction => 'direction',
        compartment => 'compartment_uuid',
        'transproton-nature' => 'transprotonNature',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/reactionComplex.dtx", \%columns, [$mappingObj->reaction_rules()]);
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
        'to-link' => 'compound_uuid',
        alias => 'alias',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $compound_aliases = [];
    foreach my $cpd ($biochemObj->compounds()) {
        push(@$compound_aliases, $cpd->compound_aliases); 
    }
    buildTable("$directory/hasCompoundAliasFrom.dtx", \%columns, $compound_aliases);
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
        'from-link' => 'media_uuid',
        'to-link' => 'compound_uuid',
        concentration => 'concentration',
        'maximum-flux' => 'maxflux',
        'minimum-flux' => 'minflux',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $mediaCompounds = [];
    foreach my $media ($biochemObj->media()) {
        push(@$mediaCompounds, $media->media_compounds());
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
        'to-link' => 'reaction_uuid',
        alias => 'alias',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $reaction_aliases = [];
    foreach my $rxn ($biochemObj->reactions()) {
        push(@$reaction_aliases, $rxn->reaction_aliases);
    }
    buildTable("$directory/hasReactionAliasFrom.dtx", \%columns, $reaction_aliases);
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
        'from-link' => 'complex_uuid',
        'to-link' => 'reaction_rule_uuid',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $rxnrules = [];
    foreach my $cpx ($mappingObj->complexes) {
        foreach my $rule ($cpx->reaction_rules) {
            push(@$rxnrules, { 'complex_uuid' => $cpx->uuid, 'reaction_rule_uuid' => $rule->uuid });
        }
    }
    buildTable("$directory/hasStep.dtx", \%columns, $rxnrules);
}
#    
#    Reagent: This relationship connects a reaction to the compounds that participate
#              in it. A reaction involves many compounds, and a compound can be involved
#              in many reactions. The relationship attributes indicate whether a
#              compound is a product or substrate of the reaction, as well as its
#              stoichiometry.
#    
#        Table: Reagent 
#            id (string) : Unique identifier for this Reagent
#            cofactor (boolean): TRUE if the compound is a cofactor; FALSE if it
#                                is a major component of the reaction.
#            compartment-index (int): Abstract number that groups this reagent into
#                                     a compartment. Each group can then be assigned
#                                     to real compartments when doing comparative
#                                     analysis.
#            stoichiometry (float): Number of molecules of the compound that participate
#                                   in a single instance of the reaction. For example,
#                                   if a reaction produces two water molecules, the
#                                   stoichiometry of water for the reaction would
#                                   be two. When a reaction is written on paper in
#                                   chemical notation, the stoichiometry is the number
#                                   next to the chemical formula of the compound.
#            transport-coefficient (float): Number of reagents of this type transported.
#                                           A positive value implies transport into
#                                           the reactions default compartment; a
#                                           negative value implies export to the
#                                           reagent's specified compartment.
#    

{
    my $a = { 
        'id' => 'id',
        cofactor => 'cofactor',
        stoichiometry => 'coefficient', 
        'compartment-index' => 'compartmentIndex',
        'transport-coefficient' => 'transportCoefficient',
        'compartment' => 'compartment',
    };
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    my $reagents = [];
    foreach my $reaction ($biochemObj->reactions()) {
        my $mainCompartment = $reaction->compartment_uuid;
        my $dtrs = {0 => $mainCompartment};
        foreach my $dtr ($reaction->default_transported_reagents) {
            $dtrs->{ $dtr->compound_uuid . $dtr->compartmentIndex } = $dtr;
        } 
        foreach my $reagent ($reaction->reagents()) {
            my ($cpd, $cmpIdx) = ($reagent->compound_uuid, $reagent->compartmentIndex);
            my $hash = {
                id => $reagent->reaction_uuid . $reagent->compound_uuid,
                coefficient => $reagent->coefficient,
                compartmentIndex => $reagent->compartmentIndex,
            };
            $hash->{cofactor} = $reagent->cofactor if defined($reagent->cofactor);
            if(defined($dtrs->{$cpd.$cmpIdx})) {
                my $dtr = $dtrs->{$cpd.$cmpIdx};
                $hash->{compartment} = $dtr->compartment_uuid;
                $hash->{transportCoefficient} = $dtr->transportCoefficient;
            } else {
                $hash->{compartment} = $dtrs->{0};
                $hash->{compartmentIndex} = 0;
                $hash->{transportCoefficient} = 0;
            } 
            push(@$reagents, $hash);
        } 
    }
    buildTable("$directory/Reagent.dtx", \%columns, $reagents);
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
        'from-link' => 'complex_uuid',
        'to-link' => sub { return $_[0]->role->name },
        msid => sub { return $_[0]->role->id }, 
        optional => 'optional',
        type => 'type',
    };
    my $cpxroles = [];
    foreach my $complex ($mappingObj->complexes()) {
        push(@$cpxroles, $complex->complex_roles());
    }
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/isTriggeredBy.dtx", \%columns, $cpxroles);
}
#    
#    IsUsedAs: This relationship connects a reaction to its usage in specific complexes.
#    
#        Table: IsUsedAs
#            from-link (string): id of the source Reaction.
#            to-link (string): id of the target ReactionRule.
{
    my $a = { 
        'from-link' => 'reaction_uuid',
        'to-link' => 'uuid',
    };
    my $reaction_rules = [];
    foreach my $complex ($mappingObj->complexes()) {
        push(@$reaction_rules, $complex->reaction_rules());
    }
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/isUsedAs.dtx", \%columns, $reaction_rules);
}
#    
#    ParticipatesAs: This relationship connects a compound to the reagents that represent
#                    its participation in reactions.
#    
#        Table: ParticipatesAs
#            from-link (string): id of the source Compound.
#            to-link (string): id of the target Reagent.
#    
#    
{
    my $a = { 
        'from-link' => 'compound_uuid',
        'to-link' => sub { return $_[0]->reaction_uuid . $_[0]->compound_uuid; },
    };
    my $reagents = [];
    foreach my $rxn ($biochemObj->reactions()) {
        push(@$reagents, $rxn->reagents);
    }
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/ParticipatesAs.dtx", \%columns, $reagents);
}
#    
#    Involves: This relationship connects a reaction to the reagents representing
#              the compounds that participate in it.
#    
#        Table: Involves
#            from-link (string): id of the source Reaction.
#            to-link (string): id of the target Reagent.
#    
#    
{
    my $a = { 
        'from-link' => 'reaction_uuid',
        'to-link' => sub { return $_[0]->reaction_uuid . $_[0]->compound_uuid; },
    };
    my $reagents = [];
    foreach my $rxn ($biochemObj->reactions()) {
        push(@$reagents, $rxn->reagents);
    }
    tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
    buildTable("$directory/Involves.dtx", \%columns, $reagents);
}

__END__

=head1 generateTablesForKbase

generateTablesForKbase --map master/main --bio master/main --dir /path/to/dir

=cut
