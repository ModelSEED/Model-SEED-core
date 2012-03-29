#===============================================================================
#
#         FILE: Biochemistry.pm
#
#  DESCRIPTION: A factory object for creating a biochemistry. This
#               can be used for importing a biochemistry from PPO or
#               a flat-file based directory structure containing:
#                   /biochemistry/
#                       reaction.txt
#                       compound.txt
#                       rxnals.txt      (optional)
#                       cpdals.txt      (optional)
#                       media.txt       (optional)
#                       compartment.txt (optional)
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 03/19/2012 11:40:24
#     REVISION: ---
#===============================================================================
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Compartment;
use ModelSEED::MS::Compound;
use ModelSEED::MS::Reaction;
use ModelSEED::MS::Media;
use ModelSEED::MS::MediaCompound;
use DateTime;
package ModelSEED::MS::Factories::Biochemistry;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use Try::Tiny;

has conversionFns => (is => 'rw', isa => 'HashRef', builder => '_makeConversionFns', lazy => 1);
has compartmentHierarchy => ( is => 'rw', isa => 'HashRef', default => sub { return {}} );

# Generate a new biochemistry object from
# a directory structure.
sub newBiochemistryFromDirectory {
    my ($self, $args) = @_;
    my $missed = {};
    unless(defined($args->{directory})) {
        die "Required argument 'directory' not defined";
    }
    my $dir = $self->_standardizeDirectory($args->{directory});
    # If a FIGMODELdatabase was supplied, pull in missing data
    # from this database where $args->{type} is true.
    if(defined($args->{database}) && ref($args->{database})) {
        my $db = $args->{database};
        foreach my $type (qw(cpdals rxnals media compartment mediacpd)) {
            next if( -f "$dir/$type.txt" );
            my $objects = $db->get_objects($type, {});
            my $table = $db->ppo_rows_to_table({filename => "$dir/$type.txt"}, $objects); 
            $table->save();
        }
    }
    my $files = {
        reaction       => 'reaction.txt',
        compound       => 'compound.txt',
        compound_alias => 'cpdals.txt',
        reaction_alias => 'rxnals.txt',
        media          => 'media.txt',
        compartment    => 'compartment.txt',
        media_compound => 'mediacpd.txt',
    };
    foreach my $file (values %$files) {
        $file = "$dir/$file";
        die "Unable to find $file!" unless (-f "$file");
    }
    my $tables = {%$files};
    my $config = {filename => undef, delimiter => "\t", itemDelimiter => ";"};
    foreach my $key (keys %$tables) {
        $config->{filename} = $tables->{$key};
        $tables->{$key}
            = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    my $bio = ModelSEED::MS::Biochemistry->new();
    # Compartments
    for(my $i=0; $i<$tables->{compartment}->size(); $i++) {
        my $row = $tables->{compartment}->get_row($i);
        my $obj = $self->convert("compartment", $row, $bio);
        unless(defined($obj)) {
            push(@{$missed->{compartment}}, $row->{id}->[0]);
            next;
        }
        $bio->create("Compartment", $obj);
    }
    $self->buildCompartmentHierarchy($bio);
    # Compounds
    my $cpds = [];
    for (my $i = 0; $i < $tables->{compound}->size(); $i++) {
        my $row = $tables->{compound}->get_row($i);
        my $obj = $self->convert("compound", $row, $bio);
        unless(defined($obj)) {
            push(@{$missed->{compound}}, $row->{id}->[0]);
            next;
        }
        $bio->create("Compound", $obj);
    }
    # CompoundAliases
    my $aliasRepeats = {};
    my $compoundAliasSets = {};
    for (my $i = 0; $i < $tables->{compound_alias}->size(); $i++) {
        my $row = $tables->{compound_alias}->get_row($i);
        my $hash = $self->convert("compound_alias", $row, $bio);
        my $error;
        ($error, $aliasRepeats)
            = checkAliases($aliasRepeats, $hash, "compound")
            if (defined($hash));
        if (!defined($hash) || $error) {
            push(
                @{$missed->{compound_alias}},
                $row->{COMPOUND}->[0] . ":" . $row->{type}->[0]
            );
            next;
        }
        my $type = $hash->{type};
        delete $hash->{type};
        my $set = $compoundAliasSets->{$type};
        unless(defined($set)) {
            $set = $bio->create("CompoundAliasSet", { type => $type });
            $compoundAliasSets->{$type} = $set;
        }
        $set->create("CompoundAlias", $hash);
    }
    # Reactions
    for (my $i = 0; $i < $tables->{reaction}->size(); $i++) {
        my $row = $tables->{reaction}->get_row($i);
        my $hash = $self->convert("reaction", $row, $bio);
        unless (defined($hash)) {
            push(@{$missed->{reaction}}, $row->{id}->[0]);
            next;
        }
        warn "No id for reaction : " . Dumper($hash). "\n" . Dumper($row) unless(defined($hash->{id}));
        my $rxn = $bio->create("Reaction", $hash);
        my $parts = parseReactionEquation($row);
        if(@$parts == 0) {
            # Some reactions don't have any real compounds
            # (e.g. rxn14003 (abstract)
            warn "No parts for " . $rxn->id . "\n";
            next;
        }
        my ($reagents, $transport)
            = $self->makeReagentsAndInstance($parts, $bio, $rxn->uuid, $row);
        unless(defined($reagents) && defined($transport)) {
            push(@{$missed->{reaction}}, $row->{id}->[0]);
            die "Unable to remove reaction" unless($bio->remove("Reaction", $rxn));
            next;
        }
        $rxn->reagents($reagents);
        $rxn->instances([$transport]);
    }
    # ReactionAlias
    my $reactionAliasSets = {};
    for (my $i = 0; $i < $tables->{reaction_alias}->size(); $i++) {
        my $row = $tables->{reaction_alias}->get_row($i);
        next if($row->{type}->[0] eq "name" || $row->{type}->[0] eq "searchname");
        my $hash = $self->convert('reaction_alias', $row, $bio);
        my $error;
        ($error, $aliasRepeats)
            = checkAliases($aliasRepeats, $hash, "reaction")
            if (defined($hash));
        if (!defined($hash) || $error) {
            push(
                @{$missed->{reaction_aliases}},
                $row->{REACTION}->[0] . ":" . $row->{type}->[0]
            );
            next;
        }
        my $type = $hash->{type};
        delete $hash->{type};
        my $set = $reactionAliasSets->{$type};
        unless(defined($set)) {
            $set = $bio->create("ReactionAliasSet", { type => $type });
            $reactionAliasSets->{$type} = $set;
        }
        $set->create("ReactionAlias", $hash);
    }
    # Media
    for(my $i = 0; $i < $tables->{media}->size(); $i++) {
        my $row = $tables->{media}->get_row($1);
        my $hash = $self->convert("media", $row, $bio);
        my $media = $bio->create("Media", $hash);
        my $mediaCpds = $self->getMediaCompounds(
            $media, $tables->{media_compound}, $bio);
        unless(defined($mediaCpds)) {
            $bio->remove("Media", $media);
            next;
        }
        $media->mediacompounds($mediaCpds);
    }
    return ($bio, $missed);
}

sub newBiochemistryFromPPO {
    my ($self, $args) = @_;
    unless(defined($args->{database})) {
        die "Required argument 'database' not defined";
    }
    my $db = $args->{database};
    my $tempDir = $self->_standardizeDirectory(File::Temp::tempdir());
    warn $tempDir . "\n";
    foreach my $type (qw(compound reaction cpdals rxnals media compartment mediacpd)) {
        my $objects = $db->get_objects($type, {});
        my $config = {
            filename => "$tempDir/$type.txt",
            delimiter => "\t",
            itemDelimiter => ";",
        };
        my $table = $db->ppo_rows_to_table($config, $objects); 
        $table->save();
    }
    return $self->newBiochemistryFromDirectory({directory => $tempDir});
}

sub _standardizeDirectory {
    my ($self, $dir) = @_;
    $dir = Cwd::abs_path($dir);
    $dir =~ s/\/$//;
    return $dir;
}

sub _makeConversionFns {
    my ($self, $type, $row) = @_;
    # Return a DateObject given default epoch timestamp
    my $date = sub {
        my ($self, $row) = @_;
        my $dt = ($row->{modificationDate}->[0])
            ? DateTime->from_epoch(epoch => $row->{modificationDate}->[0])
            : ($row->{creationDate}->[0])
            ? DateTime->from_epoch(epoch => $row->{creationDate}->[0])
            : DateTime->now();
        return $dt->datetime();
    };
    my $f = {};
    $f->{compound} = sub {
        my ($self, $row) = @_;
        return {
            id            => $row->{id}->[0],
            name          => $row->{name}->[0],
            abbreviation  => $row->{abbrev}->[0],
            formula       => $row->{formula}->[0],
            mass          => $row->{mass}->[0],
            defaultCharge => $row->{charge}->[0],
            deltaG        => $row->{deltaG}->[0],
            deltaGErr     => $row->{deltaGErr}->[0],
            modDate       => $date->($row),
        };
    };
    $f->{compound_alias} = sub {
        my ($self, $row, $ctx) = @_;
        my $uuid = $self->uuidCache("compound", $row->{COMPOUND}->[0], $ctx);
        return undef unless ($uuid);
        return {
            type          => $row->{type}->[0],
            alias         => $row->{alias}->[0],
            compound_uuid => $uuid,
        };
    };
    $f->{reaction} = sub {
        my ($self, $row, $ctx) = @_;
        # Determine reversibility
        my $codes = {reversibility => '', thermoReversibility => ''};
        foreach my $key (keys %$codes) {
            my ($forward, $reverse) = (0, 0);
            $forward = 1
                if (defined($row->{$key}->[0]) && $row->{$key}->[0] =~ />/);
            $reverse = 1
                if (defined($row->{$key}->[0]) && $row->{$key}->[0] =~ /</);
            if (!$forward && $reverse) {
                $codes->{$key} = "<";
            } elsif (!$reverse && $forward) {
                $codes->{$key} = ">";
            } else {
                $codes->{$key} = "=";
            }
        }
        return {
            id                  => $row->{id}->[0],
            name                => $row->{name}->[0],
            abbreviation        => $row->{abbrev}->[0],
            modDate             => $date->($row),
            deltaG              => $row->{deltaG}->[0],
            deltaGErr           => $row->{deltaGErr}->[0],
            reversibility       => $codes->{reversibility},
            thermoReversibility => $codes->{thermoReversibility},
        };
    };
    $f->{reaction_alias} = sub {
        my ($self, $row, $ctx) = @_;
        my $uuid = $self->uuidCache("reaction", $row->{REACTION}->[0], $ctx);
        return undef unless ($uuid);
        return {
            type          => $row->{type}->[0],
            alias         => $row->{alias}->[0],
            reaction_uuid => $uuid,
        };
    };
    $f->{reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction", $row->{reaction}->[0], $ctx);
        my $cpd = $self->uuidCache("compound", $row->{compound}->[0], $ctx);
        unless (defined($rxn) && defined($cpd)) {
            return undef;
        }
        return {
            reaction_uuid    => $rxn,
            compound_uuid    => $cpd,
            coefficient      => $row->{coefficient}->[0],
            cofactor         => $row->{cofactor}->[0] || undef,
            compartmentIndex => $row->{compartmentIndex}->[0],
        };
    };
    $f->{default_transported_reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction",    $row->{reaction}->[0], $ctx);
        my $cpd = $self->uuidCache("compound",    $row->{compound}->[0], $ctx);
        my $cmp = $self->uuidCache("compartment", $row->{compartment}->[0], $ctx);
        unless (defined($rxn) && defined($cmp) && defined($cpd)) {
            my $str
                = (!defined($rxn)) ? "no reaction\n"
                : (!defined($cpd)) ? "no cpd\n"
                :                    "no compartment\n";
            warn $str;
            return undef;
        }
        return {
            reaction_uuid        => $rxn,
            compound_uuid        => $cpd,
            compartment_uuid     => $cmp,
            compartmentIndex     => $row->{compartmentIndex}->[0],
            transportCoefficient => $row->{transportCoefficient}->[0],
            isImport             => $row->{isImport}->[0],
        };
    };
    $f->{compartment} = sub {
        my ($self, $row) = @_;
        return {
            id      => $row->{id}->[0],
            name    => $row->{name}->[0],
            modDate => $date->($row),
        };
    };
    $f->{media} = sub {
        my ($self, $row, $ctx) = @_;
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0],
            type => ($row->{aerobic}->[0] eq '1') ? "aerobic" : "anaerobic",
        };
    };
    $f->{media_compound} = sub {
        my ($self, $row, $ctx) = @_; 
        my $media_uuid = $self->uuidCache("media", $row->{MEDIA}->[0], $ctx);
        my $compound_uuid = $self->uuidCache("compound", $row->{entity}->[0], $ctx);
        warn "Unable to find compound " . $row->{entity}->[0] unless defined($compound_uuid);
        warn "Unable to find media " . $row->{MEDIA}->[0] unless defined($media_uuid);
        return undef unless(defined($media_uuid) && defined($compound_uuid));
        return {
            media_uuid    => $media_uuid,
            compound_uuid => $compound_uuid,
            concentration => $row->{concentration}->[0],
            minFlux => $row->{minFlux}->[0],
            maxFlux => $row->{maxFlux}->[0],
         };
    };
    return $f;
}

sub convert {
    my ($self, $type, $row, $ctx) = @_;
    my $f = $self->conversionFns->{$type};
    die "No converter for $type!" unless(defined($f));
    return _removeUndefs($f->($self, $row, $ctx));
}

sub _removeUndefs {
    my ($hash) = @_;
    return unless defined($hash);
    for (grep { !defined($hash->{$_}) } keys %$hash) {
        delete $hash->{$_};
    }
    return $hash;
}

sub uuidCache {
    my ($self, $type, $key, $ctx) = @_;
    my $map = {
        compound => { type => 'Compound', key => 'id' },
        reaction => { type => 'Reaction', key => 'id' },
        compartment => { type => 'Compartment', key => 'id' },
        media => { type => 'Media', key => 'id' },
    };
    my $Type = $map->{$type}->{type};
    my $KeyName = $map->{$type}->{key};
    confess "Bad call to uuidCache" unless (defined($Type) && defined($KeyName) && defined($ctx));
    my $o = $ctx->getObject($Type, { $KeyName => $key });
    return (defined($o)) ? $o->uuid : undef;
}

sub checkAliases {
    my ($aliasRepeats, $hash, $kind) = @_;
    my ($type, $alias) = ($hash->{type}, $hash->{alias});
    unless(defined($type) && defined($alias)) {
        return (1, $aliasRepeats);
    }
    my $existing = $aliasRepeats->{$type . $alias};
    my $error    = 0;
    if (defined($existing)) {
        warn "Existing alias: type => "
            . $hash->{type}
            . ", alias => "
            . $hash->{alias}
            . " for $kind: "
            . $existing->id . " )\n";
        $error = 1;
    } else {
        $aliasRepeats->{$type . $alias} = $hash->{$kind};
    }
    return ($error, $aliasRepeats);
}

sub getMediaCompounds {
    my ($self, $media, $mediaCpdTable, $bio) = @_;
    my $mediaCompounds = [];
    my @rows = $mediaCpdTable->get_rows_by_key($media->id, "MEDIA");
    foreach my $row (@rows) {
        my $hash = $self->convert("media_compound", $row, $bio);
        unless(defined($hash)) {
            warn "Failed to load media on: ".
                $row->{entity}->[0] . " " . $row->{MEDIA}->[0];
            return undef;
        }
        push(@$mediaCompounds, ModelSEED::MS::MediaCompound->new($hash));
    }
    return $mediaCompounds;
}

sub parseReactionEquation {
    my ($row)    = @_;
    my $Equation = $row->{equation}->[0];
    my $Reaction = $row->{id}->[0];
    return parseReactionEquationBase($Equation, $Reaction);
}

sub parseReactionEquationBase {
    my ($Equation, $Reaction) = @_;
    my $Parts = [];
    if (defined($Equation)) {
        my @TempArray            = split(/\s/, $Equation);
        my $CurrentlyOnReactants = 1;
        my $Coefficient          = 1;
        for (my $i = 0; $i < @TempArray; $i++) {
            if (   $TempArray[$i] =~ m/^\(([\.\d]+)\)$/
                || $TempArray[$i] =~ m/^([\.\d]+)$/)
            {
                $Coefficient = $1;
            } elsif ($TempArray[$i] =~ m/(cpd\d\d\d\d\d)/) {
                $Coefficient *= -1 if ($CurrentlyOnReactants);
                my $NewRow;
                $NewRow->{"reaction"}->[0]    = $Reaction;
                $NewRow->{"compound"}->[0]    = $1;
                $NewRow->{"compartment"}->[0] = "c";
                $NewRow->{"coefficient"}->[0] = $Coefficient;
                if ($TempArray[$i] =~ m/cpd\d\d\d\d\d\[([a-zA-Z]+)\]/) {
                    $NewRow->{"compartment"}->[0] = lc($1);
                }
                push(@$Parts, $NewRow);
                $Coefficient = 1;
            } elsif ($TempArray[$i] =~ m/=/) {
                $CurrentlyOnReactants = 0;
            }
        }
    }
    return $Parts;
}

# Situate the reaction in the cytosol (c) unless it does not exist.
# If it does not exist, select the innermost compartment.
sub determinePrimaryCompartment {
    my ($self, $parts, $ctx) = @_;
    my $hierarchy = $self->compartmentHierarchy;
    my ($innermostScore, $innermost);
    foreach my $part (@$parts) {
        my $cmp = $part->{compartment}->[0];
        if ($cmp eq 'c') {
            $innermost = $cmp;
            last;
        }
        my $score = $hierarchy->{$cmp};
        if (!defined($innermostScore) || $score > $innermostScore) {
            $innermostScore = $score;
            $innermost      = $cmp;
        }
    }
    return $innermost;
}
sub makeReagentsAndInstance {
    my ($self, $parts, $bio, $rxn_uuid, $row) = @_;
    my $reagents            = [];
    my $instanceTransports  = [];
    my $seenCompartments    = {};
    my $reactionCompartment = $self->determinePrimaryCompartment($parts, $bio);
    my $reactionCompartment_uuid = $self->uuidCache("compartment", $reactionCompartment, $bio);
    warn "Unable to find compartment: " . $reactionCompartment unless(defined($reactionCompartment_uuid));
    return (undef, undef) unless(defined($reactionCompartment_uuid));
    my $reactionInstance = ModelSEED::MS::ReactionInstance->new({
        reaction_uuid => $rxn_uuid,
        compartment_uuid => $reactionCompartment_uuid,
    });
    foreach my $part (@$parts) {
        my $cpd_uuid = $self->uuidCache("compound", $part->{compound}->[0], $bio);
        my $cmp_uuid =  $self->uuidCache("compartment", $part->{compartment}->[0], $bio);
        my $coff = $part->{coefficient}->[0];
        warn "Unable to find compound: " . $part->{compound}->[0] unless(defined($cpd_uuid));
        warn "Unable to find compartment: " . $part->{compartment}->[0] unless(defined($cmp_uuid));
        return (undef, undef) unless(defined($cpd_uuid) && defined($cmp_uuid));
        # Compartment Index
        my $cmpIdx = 0;
        if ($cmp_uuid ne $reactionCompartment_uuid) {
            unless (defined($seenCompartments->{$cmp_uuid})) {
                $seenCompartments->{$cmp_uuid}
                    = (scalar(keys %$seenCompartments) + 1);
            }
            $cmpIdx = $seenCompartments->{$cmp_uuid};
            # Build instanceTransport
            my $instanceTransport = ModelSEED::MS::InstanceTransport->new({
                reactioninstance_uuid => $reactionInstance->uuid,
                compound_uuid => $cpd_uuid,
                compartment_uuid => $cmp_uuid,
                compartmentIndex => $cmpIdx,
                coefficient => $coff,
                equation => $row->{equation}->[0],
            });
            push(@$instanceTransports, $instanceTransport);
        }
        my $reagent = ModelSEED::MS::Reagent->new({
            compound_uuid => $cpd_uuid,
            reaction_uuid => $rxn_uuid,
            compartmentIndex => $cmpIdx,
            cofactor => 0,
            coefficient => $coff,
        });
        push(@$reagents, $reagent);
    }
    $reactionInstance->transports($instanceTransports);
    return ($reagents, $reactionInstance);
}

sub buildCompartmentHierarchy {
    my ($self, $bio) = @_;
    my $defaultHierarchy = {
        e => 0, # Extracellular
        p => 1, # Periplasm
        w => 1, # Cell Wall
        c => 2, # Cytosol
        g => 3, # Golgi
        r => 3, # Endoplasmic Reticulum
        l => 3, # Lysosome
        n => 3, # Nucleus
        h => 3, # Chloroplast
        m => 3, # Mitochondria
        x => 3, # Peroxisome
        v => 3, # Vacuole
        d => 3, # Plastid
    };
    my $hierarchy = {};
    foreach my $cmp (@{$bio->compartments}) {
        my $default = $defaultHierarchy->{$cmp->id};
        if(defined($default)) {
            $hierarchy->{$cmp->id} = $default;
        } else {
            warn "Unable to locate compartment " . $cmp->id .
            " in compartment hierarchy, skipping!\n";
        }
    }
    return $self->compartmentHierarchy($hierarchy);
}

__PACKAGE__->meta->make_immutable;
1;
