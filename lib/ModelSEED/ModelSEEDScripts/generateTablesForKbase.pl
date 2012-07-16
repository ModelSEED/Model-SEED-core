#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  generateTablesForKbase.pl
#
#        USAGE:  ./generateTablesForKbase.pl --help
#
#  DESCRIPTION:  Generate tab delimited files for Kbase upload
#
#===============================================================================
=pod

=head2 NAME

generateTablesForKabase - build KBASE CDM tables

=head2 SYNOPSIS

generateTablesForKbase --dir <directory> [ arguments ]

=head2 OPTIONS

    --directory --dir -d       Directory to output tab-delimited files to
    --biochemistry --bio -b    Reference to biochemistry object to export
    --mapping --map -m         Reference to mapping object to export
    --model                    Reference to model object to export (accepts multiple)
    --store -s                 Which storage interface to use
    --help -? -h               Print this help message

=cut
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Cwd qw(abs_path);
use ModelSEED::Store;
use ModelSEED::Auth::Factory;
use ModelSEED::Configuration;
use ModelSEED::Database::Composite;
use Tie::Hash::Sorted;
use Carp qw(confess);

my ($mapping, $biochem, $directory, $store, $help, @models);
GetOptions(
    "directory|dir|d=s"    => \$directory,
    "biochemistry|b|bio=s" => \$biochem,
    "model:s"              => \@models,
    "mapping|m|map:s"      => \$mapping,
    "store|s:s"            => \$store,
    "help|h|?"             => \$help
) || pod2usage(1);
pod2usage(-exitval => 0, -verbose => 2) if $help;
unless ( defined($directory) && -d $directory ) {
    pod2usage(1);
}

unless(@models > 0 || (defined($mapping) && defined($biochem))) {
    pod2usage(2);
}

# Normalize the output directory
$directory = abs_path($directory);
$directory =~ s/\/$//;

# Set up Storage interface
my $auth = ModelSEED::Auth::Factory->new->from_config;
if(defined $store) {
    my $config = ModelSEED::Configuration->instance;
    my $db_config;
    foreach my $conf (@{$config->{stores}}) {
        if($conf->{name} eq $store) {
            $db_config = $conf;
            last;
        }
    }
    my $db = ModelSEED::Database::Composite->new(databases => [ $db_config ]);
    $store = ModelSEED::Store->new(auth => $auth, database => $db);
} else {
    $store = ModelSEED::Store->new(auth => $auth);
}

if(defined($mapping) && defined($biochem)) {
    my $biochemObj = $store->get_object($biochem);
    my $mappingObj = $store->get_object($mapping);
    die "Could not find biochemistry $biochem!\n" unless($biochemObj);
    die "Could not find mapping $mapping!\n" unless($mappingObj);
    doBiochemistryAndMapping($biochemObj, $mappingObj);
}

if(@models > 0) {
    my $model_names = \@models;
    doModels($model_names, $store);
}

# Now start generating the files
sub buildTable {
    my ($filename, $columns, $dataObjects, $append) = @_;
    # filename    : file to print to
    # columns     : hash where keys are column names and the values are either
    #               strings (in which case they are either attributes or hash values of the dataObject)
    #               or CODE references (in which case they produce the column value
    #               when called on the dataObject.
    # dataObjects : array of data objects 
    # append      : a HASH, if defined, append to the files
    #             : if defined and a HASH, key is filename, value is an open filehandle
    my $mode = (defined $append) ? ">>" : ">"; # either append or overwrite
    my ($fh, $doHeader, $close);
    if($mode eq ">>" && !defined($append->{$filename})) {
        if ( !-f $filename ) {
            $doHeader = 1;
        }
        open($fh, $mode, $filename) || die("Could not open file $filename!\n");
        $append->{$filename} = $fh;
    } elsif($mode eq ">>") {
        $fh = $append->{$filename};
    } else {
        open($fh, $mode, $filename) || die("Could not open file $filename!\n");
        $doHeader = 1;
        $close = 1;
    }
    my $allColumns = { map { $_ => 1 } keys %$columns };
    my $preimages = [];
    for(my $i=0; $i<@$dataObjects; $i++) {
        foreach my $key (sort keys %$columns) {
            my $val = $columns->{$key};
            if(ref($val) eq "CODE") {
                $preimages->[$i]->{$key} = $val->($dataObjects->[$i]);
            } elsif(ref($dataObjects->[$i]) eq 'HASH') {
                $preimages->[$i]->{$key} = $dataObjects->[$i]->{$val} // ''; 
            } elsif(ref($dataObjects->[$i])) {
                $preimages->[$i]->{$key} = $dataObjects->[$i]->$val // '';
            } else {
                confess "Can't figure out what to do with this object";
            }
        }
    }
    # Print column headers unless we're appending
    print $fh join("\t", sort keys %$allColumns) . "\n" if($doHeader);
    foreach my $preimage (@$preimages) {
        print $fh join("\t", map { $preimage->{$_} } sort keys %$preimage) . "\n";
    }
    close($fh) if($close);
}

sub doBiochemistryAndMapping {
    my ($biochemObj, $mappingObj) = @_;
#    LOCATION ( a.k.a. COMPARTMENT )
#    Location: A location is a place where a reaction's compounds can originate or
#              end up (e.g. cell wall, extracellular, cytoplasm).
#
#        Table: Location
#            id (string): Unique identifier for this Location.
#            hierarchy (int): a number indicating where this location occurs in relation
#                             other locations in the cell. Zero indicates extra-cellular.
#            mod-date (date): date and time of the last modification to the compartment's
#                             definition
#            msid (string): common modeling ID of this location
#            name (string): common name for the location
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
        buildTable("$directory/location.dtx", \%columns, $biochemObj->compartments);
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
            msid => 'name',
            'mod-date' => 'modDate',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/complex.dtx", \%columns, $mappingObj->complexes);
    } 
    #    
    #        Table: ComplexName
    #            id (string): Unique identifier for this Complex.
    #            name (string): name of this complex. Not all complexes have names.
    #    
    {
        my $a = {
            id => 'uuid',
            msid => 'name',
            name => 'name',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/complexName.dtx", \%columns, $mappingObj->complexes);
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
    #            default-charge (float): computed charge of the compound in a pH-neutral
    #                                    solution
    #            deltaG (float): Gibbs free-energy coefficient for this compound
    #            deltaG-error (float): error bounds on the deltaG value
    #            formula (string): a pH-neutral formula for the compound
    #            label (string): primary name of the compound, for use in displaying
    #                            reactions
    #            msid (string): common modeling ID of this compound
    #            uncharged-formula (string): a electrically neutral formula for the compound
    #    
    {
        my $a = {
            id => 'uuid',
            msid => 'id',
            mass => 'mass',
            'mod-date' => 'modDate',
            abbr => 'abbreviation',
            'default-charge' => 'defaultCharge',
            'deltaG' => 'deltaG',
            'deltaG-error' => 'deltaGErr',
            formula => 'formula',
            label => 'name',
            'uncharged-formula' => 'unchargedFormula',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/compound.dtx", \%columns, $biochemObj->compounds);
    }
#    Media: A media describes the chemical content of the solution in which cells
#           are grown in an experiment or for the purposes of a model. The key is
#           the common media name. The nature of the media is described by its relationship
#           to its constituent compounds.
#
#        Table: Media
#            id (string): Unique identifier for this Media.
#            is-minimal (boolean): TRUE if this media condition is considered minimal
#            mod-date (date): date and time of the last modification to the media's
#                             definition
#            name (string): descriptive name of the media
#            type (string): type of the medium (aerobic or anaerobic)
    {
        my $a = {
            id => 'uuid', 
            msid => 'id',
            'is-minimal' => 'isMinimal',
            'mod-date' => 'modDate',
            name => 'name',
            type => 'type',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/media.dtx", \%columns, $biochemObj->media);
    }
#    Reaction: A reaction is a chemical process that converts one set of compounds
#              (substrate) to another set (products).
#
#        Table: Reaction
#            id (string): Unique identifier for this Reaction.
#            default-protons (float): number of protons absorbed by this reaction
#                                     in a pH-neutral environment
#            deltaG (float): Gibbs free-energy coefficient for the reaction
#            deltaG-error (float): error bounds on the deltaG value
#            direction (char): direction of this reaction (> for forward-only, <
#                              for backward-only, = for bidirectional)
#            mod-date (date): date and time of the last modification to this reaction's
#                             definition
#            thermodynamic-reversibility (char): computed reversibility of this reaction
#                                                in a pH-neutral environment
#            abbr (string): abbreviated name of this reaction
#            msid (string): common modeling ID of this reaction
#            name (string): descriptive name of this reaction
#            status (string): string indicating additional information about this
#                             reaction, generally indicating whether the reaction
#                             is balanced and/or accurate
    {
        my $a = {
            id => 'uuid',
            'default-protons' => 'defaultProtons',
            deltaG => 'deltaG',
            'deltaG-error' => 'deltaGErr',
            direction => 'direction',
            'mod-date' => 'modDate',
            'thermodynamic-reversibility' => 'thermoReversibility',
            abbr => 'abbreviation',
            msid => 'id',
            name => 'name',
            status => 'status',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/reaction.dtx", \%columns, $biochemObj->reactions);
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
        my $compound_alias_sets = $biochemObj->queryObjects("aliasSets", { attribute => "compounds" });
        foreach my $set (@$compound_alias_sets) {
            my $aliases = $set->aliases;
            foreach my $als_name (keys %$aliases) {
                my $uuids = $aliases->{$als_name};
                foreach my $uuid (@$uuids) {
                    push(@$compound_aliases, {
                        type => $set->name,
                        compound_uuid => $uuid,
                        alias => $als_name,
                    });
                }
            }
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
            'maximum-flux' => 'maxFlux',
            'minimum-flux' => 'minFlux',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        my $mediaCompounds = [];
        foreach my $media (@{$biochemObj->media}) {
            foreach my $mediacpd (@{$media->mediacompounds}) {
                my $hash = {
                    media_uuid    => $media->uuid,
                    compound_uuid => $mediacpd->compound_uuid,
                    concentration => $mediacpd->concentration,
                    maxFlux       => $mediacpd->maxFlux,
                    minFlux       => $mediacpd->minFlux,
                };
                push(@$mediaCompounds, $hash);
            }
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
        my $reaction_alias_sets = $biochemObj->queryObjects("aliasSets", { attribute => "reactions" });
        foreach my $set (@$reaction_alias_sets) {
            my $aliases = $set->aliases;
            foreach my $als_name (keys %$aliases) {
                my $uuids = $aliases->{$als_name};
                foreach my $uuid (@$uuids) {
                    push(@$reaction_aliases, {
                        type => $set->name,
                        reaction_uuid => $uuid,
                        alias => $als_name,
                    });
                }
            }
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
            'to-link' => 'reaction_uuid',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        my $rxnrules = [];
        foreach my $cpx (@{$mappingObj->complexes}) {
            foreach my $rule (@{$cpx->complexreactions}) {
                push(@$rxnrules, { 'complex_uuid' => $cpx->uuid, 'reaction_uuid' => $rule->reaction_uuid });
            }
        }
        buildTable("$directory/hasStep.dtx", \%columns, $rxnrules);
    }

#    LocalizedCompound: This entity represents a compound occurring in a specific
#                       location. A reaction always involves localized compounds.
#                       If a reaction occurs entirely in a single location, it will
#                       frequently only be represented by the cytoplasmic versions
#                       of the compounds; however, a transport always uses specifically
#                       located compounds.
#
#        Table: LocalizedCompound
#            id (string): Unique identifier for this LocalizedCompound.
    {
        my $a = { 
            id => 'localized_compound',
         };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        my $localized = [];
        my $seen = {};
        my $reactions = $biochemObj->reactions;
        foreach my $reaction (@$reactions) {
            my $reagents = $reaction->reagents;
            foreach my $reagent (@$reagents) {
                my $cmp_id = $reagent->destinationCompartment_uuid;
                my $localized_compound = $reagent->compound_uuid() . $cmp_id;
                next if defined $seen->{$localized_compound};
                my $hash = {
                    localized_compound => $localized_compound,
                };
                push(@$localized, $hash);
                $seen->{$localized_compound} = 1;
            } 
        }
        buildTable("$directory/Reagent.dtx", \%columns, $localized);

    }
#    INVOLVES ( a.k.a. REAGENT )
#    Involves: This relationship connects a reaction to the specific localized compounds
#              that participate in it.
#
#        Table: Involves
#            from-link (string): id of the source Reaction.
#            to-link (string): id of the target LocalizedCompound.
#            coefficient (float): Number of molecules of the compound that participate
#                                 in a single instance of the reaction. For example,
#                                 if a reaction produces two water molecules, the
#                                 stoichiometry of water for the reaction would be
#                                 two. When a reaction is written on paper in chemical
#                                 notation, the stoichiometry is the number next
#                                 to the chemical formula of the compound. The value
#                                 is negative for substrates and positive for products.
#            cofactor (boolean): TRUE if the compound is a cofactor; FALSE if it
#                                is a major component of the reaction.
#            is-transport (boolean): TRUE if the compound is being transported out
#                                    of or into the reaction's compartment, FALSE
#                                    if it stays in the same compartment
    {
        my $a = { 
            'from-link' => 'reaction_uuid',
            'to-link' => 'localized_compound',
            coefficient => 'coefficient',
            cofactor => 'isCofactor',
            'is-transport' => 'isTransport',
         };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        my $reagents = [];
        my $reactions = $biochemObj->reactions;
        foreach my $reaction (@$reactions) {
            foreach my $reagent (@{$reaction->reagents}) {
                my $cmp_id = $reagent->destinationCompartment_uuid;
                my $hash = {
                    reaction_uuid => $reaction->uuid,
                    localized_compound => $reagent->compound_uuid . $cmp_id,
                    coefficient => $reagent->coefficient,
                    isCofactor => $reagent->isCofactor,
                    isTransport => $reagent->isTransport,
                };
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
    #            triggering (boolean): TRUE if the presence of the role requires including
    #            the complex in the model, else FALSE.
    #    
    {
        my $a = { 
            'from-link' => 'complex_uuid',
            'to-link' => 'role_name',
            msid => 'msid', 
            optional => 'optional',
            type => 'type',
            triggering => 'triggering',
        };
        my $cpxroles = [];
        foreach my $complex (@{$mappingObj->complexes}) {
            foreach my $cpxrole (@{$complex->complexroles}) {
                my $hash = {
                    complex_uuid => $complex->uuid,
                    role_name => $cpxrole->role->name,
                    msid => $cpxrole->role->uuid,
                    optional => $cpxrole->optional,
                    type => $cpxrole->type,
                    triggering => $cpxrole->triggering,
                };
                push(@$cpxroles, $hash);
            }
        }
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/isTriggeredBy.dtx", \%columns, $cpxroles);
    }
    #   IsParticipatingAt: This relationship connects a localized compound to the location
    #                      in which it occurs during one or more reactions.
    #
    #       Table: IsParticipatingAt
    #           from-link (string): id of the source Location.
    #           to-link (string): id of the target LocalizedCompound.
    #    
    #    ParticipatesAs: This relationship connects a compound to the reagents that represent
    #                    its participation in reactions.
    #    
    #        Table: ParticipatesAs
    #            from-link (string): id of the source Compound.
    #            to-link (string): id of the target LocalizedCompound.
    #    
    #    
    {
        my $at = {
            'from-link' => 'compartment_uuid',
            'to-link' => 'localized_compound',
        };
        my $as = { 
            'from-link' => 'compound_uuid',
            'to-link' => 'localized_compound',
        };
        my $IsParticipatingAt = [];
        my $ParticipatesAs = [];
        my $seen = {};
        foreach my $rxn (@{$biochemObj->reactions}) {
            foreach my $reagent (@{$rxn->reagents}) {
                my $cmp   = $reagent->destinationCompartment_uuid;
                my $local = $reagent->compound_uuid . $cmp;
                next if defined($seen->{$local});
                my $at = {
                    compartment_uuid => $cmp,
                    localized_compound => $local,
                };
                my $as = {
                    compound_uuid => $reagent->compound_uuid,
                    localized_compound => $local,
                };
                $seen->{$local} = 1;
                push(@$ParticipatesAs, $as);
                push(@$IsParticipatingAt, $at);
            }
        }
        tie my %columnsAt, 'Tie::Hash::Sorted', 'Hash' => $at;
        tie my %columnsAs, 'Tie::Hash::Sorted', 'Hash' => $as;
        buildTable("$directory/IsParticipatingAt.dtx", \%columnsAt, $IsParticipatingAt);
        buildTable("$directory/ParticipatesAs.dtx", \%columnsAs, $ParticipatesAs);
    }
}

sub doModels {
    my ($models, $store) = @_;
    my $append = {};
    foreach my $model (@$models) {
        my $obj = $store->get_object($model);
        die "Could not find model $model\n" unless(defined($obj));
        doModel($obj, $append);
    }
}

sub doModel {
    my ($model, $append) = @_;
    $append //= {};
    ## Summary
    ## - Main Model Tables
    ## - Linker Tables ( within the Model )
    ## - Linker Tables ( Model Parts to Base Objects )
    ## - Linker Tables ( Model to Model Parts )
    ##
    ##      - Model
    ##      - LocationInstnace ( ModelCompartment )
    ##      - CompoundInstnace ( ModelCompound )
    ##      - ReactionInstance ( ModelReaction )
    ##      - Biomass
    ##          - IsComprisedOf ( BiomassCompound )
    ##
    ## Model
    {
        my $a = {
            id         => 'uuid',
            'mod-date' => 'modDate',
            name       => 'name',
            'reaction-count' => sub {
                return scalar(@{$_[0]->modelreactions});
            },
            'compound-count' => sub {
                return scalar(@{$_[0]->modelcompounds});
            },
            'annotation-count' => sub {
                return scalar(@{$_[0]->modelcompounds});
            },
            'annotation-count' => sub {
                return scalar(@{$_[0]->annotation->features});
            },
            status  => 'status',
            version => 'version',
            type    => 'type',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/Model.dtx", \%columns, [$model], $append);
    }
    ## LocationInstance ( ModelCompartment )
    {
        my $a = {
            id                  => 'uuid',
            'compartment-index' => 'compartmentIndex',
            pH                  => 'pH',
            potential           => 'potential',
            label               => 'label',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/LocationInstance.dtx", \%columns, $model->modelcompartments, $append);
    }
    ## CompoundInstance ( ModelCompound )
    {
        my $mdl_cpds = $model->modelcompounds;
        my $a = {
            id      => 'uuid',
            charge  => 'charge',
            formula => 'formula',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/CompoundInstance.dtx", \%columns, $mdl_cpds, $append);
    }
    ## ReactionInstance ( ModelReaction )
    {
        my $a = {
            id        => 'uuid',
            direction => 'direction',
            proton    => 'protons',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/ReactionInstance.dtx", \%columns, $model->modelreactions, $append);

    }
    ## Biomass
    {
        my $mdls_bios = $model->biomasses;
        my $a = {
            id          => 'uuid',
            'cell-wall' => 'cellwall',
            cofactor    => 'cofactor',
            dna         => 'dna',
            energy      => 'energy',
            lipid       => 'lipid',
            protein     => 'protein',
            'mod-date'  => 'modDate',
        };
        my $b = {
            id   => 'uuid',
            name => 'name',
        };
        tie my %columnsa, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/Biomass.dtx", \%columnsa, $mdls_bios, $append);
        tie my %columnsb, 'Tie::Hash::Sorted', 'Hash' => $b; 
        buildTable("$directory/BiomassName.dtx", \%columnsb, $mdls_bios, $append);
    }
    ## IsComprisedOf ( Biomass <> CompoundInstance )
    {
        my $mdls_bios = $model->biomasses;
        my $bios_cpds = [];
        foreach my $bio (@$mdls_bios) {
            foreach my $biocpd (@{$bio->biomasscompounds}) {
                my $hash = {
                    biomass_uuid       => $bio->uuid,
                    modelcompound_uuid => $biocpd->modelcompound_uuid,
                    coefficient        => $biocpd->coefficient,
                };
                push(@$bios_cpds, $hash);
            }
        }
        my $a = {
            'from-link' => 'biomass_uuid',
            'to-link'   => 'modelcompound_uuid',
            coefficient => 'coefficient',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/IsComprisedOf.dtx", \%columns, $bios_cpds, $append);
    }
    ## Linker TABLES - Within Model Parts
    ##
    ##     - IsRealLocationOf ( ModelCompartment <> ModelCompound ) 
    ##     - IsReagentIn ( ModelCompound <> ModelReaction )

    ## IsRealLocationOf ( ModelCompartment <> ModelCompound )
    {
        my $mdl_cpds = $model->modelcompounds;
        my $a = {
            'from-link' => 'modelcompartment_uuid',
            'to-link' => 'uuid',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/IsRealLocationOf.dtx", \%columns, $mdl_cpds, $append);
    }
    ## IsReagentIn ( ModelCompound <> ModelReaction )
    {
        my $reagents = [];
        my $rxns = $model->modelreactions;
        foreach my $rxn (@$rxns) {
            foreach my $reagent (@{$rxn->modelReactionReagents}) {
                my $hash = {
                    modelcompound_uuid => $reagent->modelcompound_uuid,
                    modelreaction_uuid => $rxn->uuid,
                    coefficient        => $reagent->coefficient,
                };
                push(@$reagents, $hash);
            }
        }
        my $a = {
            'from-link' => 'modelcompound_uuid',
            'to-link'   => 'modelreaction_uuid',
            coefficient => 'coefficient',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/IsReagentIn.dtx", \%columns, $reagents, $append);
    }

    ## LINKER TABLES - Model Parts to Base Objects
    ##      
    ##     - IsInstantiatedBy ( Compartment <> ModelCompartment )
    ##     - HasUsage ( LocalizedCompound <> CompoundInstance )
    ##     - IsExecutedAs ( Reaction <> ModelReaction )
    ##
    ## IsInstantiatedBy ( Compartment <> ModelCompartment )
    {
        my $mdls_cmps = $model->modelcompartments;
        my $a = {
            'from-link' => 'compartment_uuid',
            'to-link'   => 'uuid',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/IsInstantiatedBy.dtx", \%columns, $mdls_cmps, $append);
    }
    ## HasUsage ( LocalizedCompound <> CompoundInstance )
    {
        my $mdl_cpds = $model->modelcompounds;
        my $a = {
            'from-link' => sub {
                return $_[0]->compound_uuid . $_[0]->modelcompartment->compartment_uuid;
            },
            'to-link' => 'uuid'
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/HasUsage.dtx", \%columns, $mdl_cpds, $append);
    }
    ## IsExecutedAs ( Reaction <> ModelReaction )
    {
        my $mdls_rxns = $model->modelreactions;
        my $a = {
            'from-link' => 'reaction_uuid',
            'to-link'   => 'uuid',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/IsExecutedAs.dtx", \%columns, $mdls_rxns, $append);
    }

    ## LINKER TABLES - Model to Model Parts
    ##      
    ##     - IsDividedInto ( Model <> ModelCompartment )
    ##     - HasRequirementOf ( Model <> ModelReaction )
    ##     - Manages ( Model <> Biomass )

    ## IsDividedInto ( Model <> ModelCompartment )
    {
        my $mdl_cmps = [];
        foreach my $cmp (@{$model->modelcompartments}) {
            my $hash = {
                model_uuid => $model->uuid,
                modelcompartment_uuid => $cmp->uuid,
            };
            push(@$mdl_cmps, $hash);
        }
        my $a = {
            'from-link' => 'model_uuid',
            'to-link'   => 'modelcompartment_uuid',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/IsDividedInto.dtx", \%columns, $mdl_cmps, $append);
    }
    # HasRequirementOf ( model <-> model_reaction )
    {
        my $mdls_rxns = [];
        foreach my $rxn (@{$model->modelreactions}) {
            my $hash = {
                model_uuid         => $model->uuid,
                modelreaction_uuid => $rxn->uuid,
            };
            push(@$mdls_rxns, $hash);
        }
        my $a = {
            'from-link' => 'model_uuid',
            'to-link'   => 'modelreaction_uuid',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/HasRequirementOf.dtx", \%columns, $mdls_rxns, $append);
    }
    # Manages ( model <-> biomass ) 
    {
        my $mdls_bios = [];
        foreach my $bio (@{$model->biomasses}) {
            push(@$mdls_bios, {model => $model->uuid, bio => $bio->uuid});
        }
        my $a = {
            'from-link' => 'model',
            'to-link'   => 'bio',
        };
        tie my %columns, 'Tie::Hash::Sorted', 'Hash' => $a;
        buildTable("$directory/Manages.dtx", \%columns, $mdls_bios, $append);
    }
}
