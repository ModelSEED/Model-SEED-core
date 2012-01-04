package ModelSEED::ModelSEEDScripts::ContinuousDataImporter;
use strict;
use warnings;
use Cwd qw( abs_path );
use ModelSEED::ObjectManager;
use ModelSEED::FIGMODEL;
use DateTime;
use Carp;

sub new {
    my ($class, $config) = @_;
    my $self = {};
    $self->{om} = ModelSEED::ObjectManager->new({
        database => $config->{DATABASE},
        driver   => $config->{DRIVER},
    });
    $self->{fm} = ModelSEED::FIGMODEL->new(); 
    $self->{fm}->authenticate({username => "sdevoid", password => "marcopolo"});
    $self->{typesToHashFns} = _makeTypesToHashFns();
    $self->{conversionFns}  = _makeConversionFns();
    bless $self, $class;
    $self->{cache} = {};
    $self->_buildLookupData();
    return $self;
}


sub fm {
    return $_[0]->{fm};
}

sub om {
    return $_[0]->{om};
}

sub cache {
    return $_[0]->{cache};
}

sub hash {
    return $_[0]->{typesToHashFns};
}

sub convert {
    my $self = shift;
    my $type = shift;
    return $self->{conversionFns}->{$type}->(@_);
}

sub compartmentHierarchy {
    my $self = shift;
    my $set  = shift;
    $self->{compartmentHierarchy} = $set if(defined($set));
    return $self->{compartmentHierarchy};
}
    

sub printDBMappingsToDir {
    my ($self, $dir) = @_;
    $dir = $self->standardizeDirectory($dir);
    my $types = ['complex', 'cpxrole', 'rxncpx', 'role',
        'reaction', 'compound', 'rxnals', 'cpdals'];
    my $config = {
        delimiter => "\t",
        itemDelimiter => ";",
    };
    foreach my $type (@$types) {
        my $objs = $self->fm->database->get_objects($type);        
        $config->{filename} = "$dir/$type.txt";
        my $tbl = $self->fm->database->ppo_rows_to_table($config, $objs);
        $tbl->save();
    }
}

sub _makeTypesToHashFns {
    my $f = {};
    $f->{complex} = sub { return $_[0]->id . ($_[0]->name || ''); };
    $f->{role} = sub {
        return $_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->exemplar || '');
    };
    $f->{compound} = sub {
        return $_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->formula || '' );
    };
    $f->{compound_alias} = sub {
        return $_[0]->alias . $_[0]->type;
    };
    $f->{reaction} = sub {
        confess "got here" unless(defined($_[0]));
        return $_[0]->id . ( $_[0]->name || '' ) . $_[0]->equation;
    };
    $f->{reaction_alias} = sub {
        return $f->{reaction}->($_[0]->reaction_obj) . $_[0]->alias . $_[0]->type;
    };
    $f->{compartment} = sub {
        return $_[0]->id . ( $_[0]->name || '' );
    };
    $f->{reaction_complex} = sub {
        return $f->{reaction}->($_[0]->reaction_obj) .
            $f->{complex}->($_[0]->complex_obj) .
            ($_[0]->primaryCompartment) ? $f->{compartment}->($_[0]->primaryCompartment_obj) : "" .
            ($_[0]->secondaryCompartment) ? $f->{compartment}->($_[0]->secondaryCompartment_obj) : "" .
            ( $_[0]->direction || "" ) . ( $_[0]->transproton || "")
    };
    $f->{reaction_compound} = sub {
        return $f->{reaction}->($_[0]->reaction_obj) . $f->{compound}->($_->[0]->compound_obj) .
               $_[0]->coefficient . ($_[0]->cofactor || "") . ( $_->[0]->exteriorCompartment || "0" );
    };
    $f->{complex_role} = sub {
        return $f->{complex}->($_[0]->complex_obj) .
               $f->{role}->($_[0]->role_obj);
    };
    $f->{media} = sub {
        return $_[0]->id . ($_[0]->name || '') . ($_[0]->type || '');
    };
    $f->{media_compound} = sub {
        return $f->{media}->($_[0]->media_obj) . $f->{compound}->($_[0]->compound_obj);
    };
    return $f;
};

# This is a set of functions converting a row object
# into a hash that can be used by getOrCreateObject()
sub _makeConversionFns {
    # Return a DateObject given default epoch timestamp
    my $date = sub {
        my ($row, $ctx) = @_;
        return ($row->{modificationDate}->[0]) ? DateTime->from_epoch(epoch => $row->{modificationDate}->[0]) :
            ($row->{creationDate}->[0]) ? DateTime->from_epoch(epoch => $row->{creationDate}->[0]) : 
            DateTime->now();
    };
        
    my $f = {};
    $f->{compound} = sub {
        my ($row, $ctx) = @_;
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0],
            abbreviation => $row->{abbrev}->[0],
            formula => $row->{formula}->[0],
            mass => $row->{mass}->[0],
            defaultCharge => $row->{charge}->[0],
            deltaG => $row->{deltaG}->[0],
            deltaGErr => $row->{deltaGErr}->[0],
            modDate => $date->($row),
        };
    };
    $f->{compound_alias} = sub {
        my ($row, $ctx) = @_;
        my $obj = $ctx->{compound}->{$row->{COMPOUND}->[0]};
        return undef unless($obj);
        return {
            type => $row->{type}->[0],
            alias => $row->{alias}->[0],
            compound => $obj->uuid,
        };
    };
    $f->{reaction} = sub {
        my ($row, $ctx) = @_;
        my $codes = { reversibility => '', thermoReversibility => ''};
        foreach my $key (keys %$codes) {
            my $forward = 1 if defined($row->{$key}->[0]) && $row->{$key}->[0] =~ />/;
            my $reverse = 1 if defined($row->{$key}->[0]) && $row->{$key}->[0] =~ />/;
            $codes->{$key} = ($forward && $reverse) ? "=" : ($forward) ? ">" : "<";
        }
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0],
            abbreviation => $row->{abbrev}->[0],
            modDate => $date->($row),
            equation => $row->{equation}->[0],
            deltaG => $row->{deltaG}->[0],
            deltaGErr => $row->{deltaGErr}->[0],
            reversibility => $codes->{reversibility}, 
            thermoReversibility => $codes->{thermoReversibility},
        };
    };
    $f->{reaction_alias} = sub {
        my ($row, $ctx) = @_;
        my $obj = $ctx->{reaction}->{$row->{REACTION}->[0]};
        return undef unless($obj);
        return {
            type => $row->{type}->[0],
            alias => $row->{alias}->[0],
            reaction => $obj->uuid,
        };
    };
    $f->{reaction_compound} = sub {
        my ($row, $ctx) = @_;
        my $rxn = $ctx->{reaction}->{$row->{reaction}->[0]};
        my $cpd = $ctx->{compound}->{$row->{compound}->[0]};
        unless(defined($rxn) && defined($cpd)) {
            return undef;
        }
        return {
            reaction => $rxn->uuid,
            compound => $cpd->uuid,
            coefficient => $row->{coefficient}->[0],
            cofactor => $row->{cofactor}->[0] || undef,
            exteriorCompartment => $row->{exteriorCompartment}->[0] || undef,
        };
    };    
    $f->{role} = sub {
        my ($row, $ctx) = @_;
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0] || undef,
            exemplar => $row->{exemplar}->[0] || undef,
        };
    };
    $f->{complex} = sub {
        my ($row, $ctx) = @_;
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0] || undef,
        };
    };
    $f->{complexRole} = sub {
        my ($row, $ctx) = @_;
        my $complex = $ctx->{complex}->{$row->{COMPLEX}->[0]};
        my $role    = $ctx->{role}->{$row->{ROLE}->[0]};
        if(defined($role) && defined($complex)) {
            return { 
                complex_obj => $complex,
                role_obj => $role,
                type => $row->{type}->[0] || '',
            };
        } else {
            return undef;
        }
    };
        
            
    return $f;
}; 
        
    
# addNewValueToLookupData - simple wrapper
# to generate rdbo to hash key and insert into lookup table
sub addNewValueToLookupData {
    my ($self, $type, $rdbo) = @_;
    my $key = $self->hash->{$type}->($rdbo);
    $self->cache->{$type}->{$key} = $rdbo;
}

# _buildLookupData - construct hash-keys for each
# 
# Input:  ( hash<type, subroutine> )
# Output: hash<type, hash<key,RDBO> >
sub _buildLookupData {
    my ($self) = @_;
    my $hash = {};
    my $fns = $self->hash;
    foreach my $type (keys %$fns) {
        $self->cache->{$type} = {};
        my $objs = $self->om()->get_objects($type);
        foreach my $obj (@$objs) {
           $self->addNewValueToLookupData($type, $obj);
        }
        warn "Prefetched $type, ".scalar(keys %{$self->cache->{$type}})." objects\n";
    }
    return $hash;
}

sub importBiochemistryFromDir {
    my ($self, $dir, $username, $name) = @_;
    $self->om->db->begin_work;
    $dir = $self->standardizeDirectory($dir);
    unless(-d $dir) {
        warn "Unable to filed $dir\n";
        return undef;
    }
    my $files = {
        reaction => 'reaction.txt',
        compound => 'compound.txt',
        reaction_compound => 'rxncpd.txt',
        compound_alias => 'cpdals.txt',
        reaction_alias => 'rxnals.txt',
    };        
    my $config = { filename => undef, delimiter => "\t"};
    unless(-f $files->{reaction_compound}) {
        $config->{filename} = "$dir/".$files->{reaction},
        my $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
        $self->generateReactionCompoundFile("$dir/".$files->{reaction_compound}, $tbl);
    } 
    foreach my $file (values %$files) {
        $file = "$dir/$file";
        unless(-f "$file") {
            warn "Unable to find $file!";
            return undef;
        }
        # now open files as FIGMODELTables
        $config->{filename} = $file;
        $file = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    # Now create biochemistry object
    my $RDB_biochemistry = $self->om->create_object('biochemistry');
    my $ctx = {};
    # Compounds
    my $compound_id_map = {};
    for(my $i=0; $i<$files->{compound}->size(); $i++) {
        my $row = $files->{compound}->get_row($i);
        my $hash = $self->convert("compound", $row, $ctx);
        my $RDB_compound = $self->getOrCreateObject("compound", $hash); 
        $ctx->{compound}->{$RDB_compound->id} = $RDB_compound;
        $RDB_biochemistry->add_compound($RDB_compound); 
    }
    # CompoundAliases
    my $aliasRepeats = {};
    for(my $i=0; $i<$files->{compound_alias}->size(); $i++) {
        my $row = $files->{compound_alias}->get_row($i);
        my $hash = $self->convert("compound_alias", $row, $ctx);
        next unless defined($hash);
        my $error;
        ($error, $aliasRepeats) = checkAliases($aliasRepeats, $hash, "compound");
        next if $error;
        my $RDB_compound_alias =
            $self->getOrCreateObject("compound_alias", $hash);
        $RDB_biochemistry->add_compound_alias($RDB_compound_alias);
    }
    # Reactions
    my $reaction_id_map = {};
    my $missed_rxn_count = 0;
    for(my $i=0; $i<$files->{reaction}->size(); $i++) {
        my $row = $files->{reaction}->get_row($i);
        my $hash = $self->convert("reaction", $row, $ctx);
        unless(defined($hash)) {
            $missed_rxn_count += 1;
            next;
        }
        my $RDB_reaction = $self->getOrCreateObject("reaction", $hash);
        $reaction_id_map->{$RDB_reaction->id} = $RDB_reaction;
        $RDB_biochemistry->add_reaction($RDB_reaction);
    }
    # Reaction Compound
    my ($missed_rxn_cpd_count, $missed_rxn_cpd_by_rxn) = (0, {});
    for(my $i=0; $i<$files->{reaction_compound}->size(); $i++) {
        my $row = $files->{reaction_compound}->get_row($i);
        my $hash = $self->convert("reaction_compound", $row, $ctx);
        unless(defined($hash)) {
            $missed_rxn_cpd_count += 1;
            $missed_rxn_cpd_by_rxn->{$hash->{reaction}} =  1 + 
                ($missed_rxn_cpd_by_rxn->{$hash->{reaction}} || 0);
            next;
        }
        my $RDB_reaction_compound = $self->getOrCreateObject("reaction_compound", $hash);
    }
    if($missed_rxn_cpd_count > 0) {
        # Error cases for reaction compound
        warn "Failed to add $missed_rxn_cpd_count reactants to database across " .
            scalar(keys %$missed_rxn_cpd_by_rxn) . " reactions.\n";
        while( my ($rxn, $count) = each %$missed_rxn_cpd_by_rxn ) {
            my $total = scalar($files->{reaction_compound}->get_rows_by_key($rxn, "REACTION"));
            if($total != $count) {
                warn "Failed to add $count reactants to db for" .
                " reaction: $rxn, which has $total reactants.\n";
            }
        }
    }
    # ReactionAlias
    $aliasRepeats = {};
    for(my $i=0; $i<$files->{reaction_alias}->size(); $i++) {
        my $row = $files->{reaction_alias}->get_row($i);
        my $hash = $self->convert('reaction_alias', $row, $ctx);
        next unless(defined($hash));
        my $error;
        ($error, $aliasRepeats) = checkAliases($aliasRepeats, $hash, "reaction");
        next if $error;
        my $RDB_reaction_alias =
            $self->getOrCreateObject("reaction_alias", $hash);
        $RDB_biochemistry->add_reaction_alias($RDB_reaction_alias);
    }
    # Media
    my $defaultMediaObjs = $self->getDefaultMedia($ctx); 
    foreach my $obj (@$defaultMediaObjs) {
        $RDB_biochemistry->add_media($obj);
        # MediaCompound - handled by getDefaultMedia 
    }
    $RDB_biochemistry->add_alias({ username => $username, id => $name});
    $RDB_biochemistry->save;
    $self->om->db->commit;
    return $RDB_biochemistry;
}
    
    

sub importMappingFromDir {
    my ($self, $dir, $RDB_biochemObject, $username, $name) = @_;
    # first validate that the dir exists and has the right files
    my $ctx = {};
    unless(-d $dir) {
        warn "Unable to find $dir\n";
        return undef;
    }
    $dir = $self->standardizeDirectory($dir);
    my $files = {complex => 'complex.txt',
                 role => 'role.txt',
                 complexRole => 'cpxrole.txt',
                 reactionComplex => 'rxncpx.txt'};
    my $config = {filename => undef, delimiter => "\t"};
    foreach my $file (values %$files) {
        $file = "$dir/$file";
        unless(-f "$file") {
            warn "Unable to find $file";
            return undef;
        }
        # now open files as FIGMODELTables
        $config->{filename} = $file;
        $file = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    # Now create mapping object
    my $RDB_mappingObject = $self->om()->create_object('mapping');
    $RDB_mappingObject->biochemistry_obj($RDB_biochemObject);
    # Create complexes
    for(my $i=0; $i<$files->{complex}->size(); $i++) {
        my $row = $files->{complex}->get_row($i);
        my $hash = $self->convert("complex", $row, $ctx);
        my $RDB_complexObject = $self->getOrCreateObject('complex', $hash);
        $ctx->{complex}->{$RDB_complexObject->id} = $RDB_complexObject;
        $RDB_mappingObject->add_complexes($RDB_complexObject);
    } 
    # Create roles 
    for(my $i=0; $i<$files->{role}->size(); $i++) {
        my $row = $files->{role}->get_row($i);
        my $hash = $self->convert("role", $row, $ctx);
        my $RDB_roleObject = $self->getOrCreateObject('role', $hash);
        $ctx->{role}->{$RDB_roleObject->id} = $RDB_roleObject;
        $RDB_mappingObject->add_role($RDB_roleObject);
    } 
    # Create complexRole
    my $cpxRoleFailures = 0;
    for(my $i=0; $i<$files->{complexRole}->size(); $i++) {
        my $row = $files->{complexRole}->get_row($i);
        my $hash = $self->convert("complexRole", $row, $ctx);
        if(!defined($hash)) {
            $cpxRoleFailures += 1;
            next;
        }
        my $RDB_complexRoleObject = $self->getOrCreateObject('complex_role', $hash);
        $RDB_complexRoleObject->save();
    }
    warn "Got $cpxRoleFailures complex_role failures, ".
        "this is probably normal.\n" if $cpxRoleFailures > 0;
    # Create compartments
    my $compartments = $self->getDefaultCompartments();
    foreach my $cmp (@$compartments) {
        $RDB_mappingObject->add_compartment($cmp);
    }
    $RDB_mappingObject->add_alias({username => $username, id => $name});
    $RDB_mappingObject->save();
    return $RDB_mappingObject; 
    # Create ComplexReaction - TODO
    for(my $i=0; $i<$files->{reactionComplex}->size(); $i++) {
        my $row = $files->{reactionComplex}->get_row($i);
        my $hash = $self->convert("reactionComplex", $row, $ctx);
        unless(defined($hash)) {
            warn "Could not import complexReaction\n";
            next;
        }
        my $RDB_reactionComplex = $self->getOrCreateObject("reaction_complex", $hash);
        $RDB_reactionComplex->save();
    }
}

# returns a set of rdbo objects for compartments
# if those objects do not already exist, create them
sub getDefaultCompartments {
    my ($self) = @_;
    if(defined($self->cache->{compartment}) && (keys %{$self->cache->{compartment}}) > 0) {
        return [ values %{$self->cache->{compartment}} ];
    } else {
        my $values = [];
        my $oldCompartments = $self->fm->database->get_objects("compartment");
        foreach my $old (@$oldCompartments) {
            my $hash = { id => $old->id(), name => $old->name };
            push(@$values, $self->getOrCreateObject("compartment", $hash));
        }
        my $defaultHierarchy = {
            'e' => 0,
            'w' => 1, 'p' => 1,
            'c' => 2,
            'g' => 3, 'r' => 3, 'l' => 3, 'n' => 3,
            'd' => 3, 'm' => 3, 'x' => 3, 'v' => 3,
        };
        foreach my $cmp (@$values) {
            if(!defined($defaultHierarchy->{$cmp->id})) {
                warn "No default compartment hierarchy for " . $cmp->name . " (".$cmp->id.")\n";
            }
        }
        return $values;
    }
}

sub getDefaultMedia {
    my ($self, $ctx) = @_;
    if(!defined($self->cache->{media}) || 
        0 == (keys %{$self->cache->{media}})) {
        my $values = [];
        my $oldMedia = $self->fm->database->get_objects("media");
        foreach my $old (@$oldMedia) {
            my $hash = {
               id => $old->id(),
               name => $old->id(),
            }; 
            my $mediaObj = $self->getOrCreateObject("media", $hash);                  
            my $mediaCpds = $self->fm->database->get_objects('mediacpd', { MEDIA => $old->id() });
            my $newMediaCpds = [];
            foreach my $mediaCpd (@$mediaCpds) {
                my $compoundObj= $ctx->{compound}->{$mediaCpd->entity()};
                unless($compoundObj) {
                    warn "Couldn't find compound " . $mediaCpd->entity() . "\n";
                    next;
                }
                my $hash = {
                    compound_obj => $compoundObj,
                    concentration => $mediaCpd->concentration(),
                    minflux => $mediaCpd->minFlux(),
                    maxflux => $mediaCpd->maxFlux(),
                };
                push(@$newMediaCpds, $hash);
            }
            $mediaObj->add_media_compound(@$newMediaCpds);
            $mediaObj->save();
            $ctx->{media}->{$mediaObj->id} = $mediaObj;
        }
    }
    return [ values %{$self->cache->{media}} ];
}
        



# getOrCreateObject - hashes and looks up object
# in lookupData. If it exists, returns that object.
# Otherwise, saves object to database and returns it.
# ( Also adds it to lookup tables. )
sub getOrCreateObject {
    my ($self, $type, $hash) = @_;
    # Delete keys where the value is undefined
    map { delete $hash->{$_} } grep
        { !defined($hash->{$_}) } keys %$hash;
    my $obj = $self->om()->create_object($type, $hash);
    my $val = $self->hash->{$type}->($obj);
    if(defined($self->cache->{$type}->{$val})) {
        return $self->cache->{$type}->{$val};
    } else {
        $obj->save();
        $self->addNewValueToLookupData($type, $obj);
        return $obj;
    }
}
        
# Make directory absolute and remove trailing slash if it exists
sub standardizeDirectory {
    my ($self, $dir) = @_;
    $dir = abs_path($dir);
    $dir =~ s/\/$//;
    return $dir;
} 


sub checkAliases {
    my ($aliasRepeats, $hash, $type) = @_;
    my $existing = $aliasRepeats->{$hash->{type}.$hash->{alias}};
    my $error = 0;
    if (defined($existing)) {
        warn "Existing alias: type => " . $hash->{type} .
            ", alias => " . $hash->{alias} . " for $type: (" .
            $hash->{$type} . ", $existing)\n";
        $error = 1;
    } else {
        $aliasRepeats->{$hash->{type}.$hash->{alias}} = $hash->{$type};
    }
    return ($error, $aliasRepeats);
}

sub parseReactionEquation {
    my ($args) = @_;
    my $Equation = $args->{equation};
    my $Parts = [];
    if (defined($Equation)) {
        my @TempArray = split(/\s/,$Equation);
        my $CurrentlyOnReactants = 1;
        for (my $i=0; $i < @TempArray; $i++) {
            my $Coefficient = 1;
            if ($TempArray[$i] =~ m/^\(([\.\d]+)\)$/ || $TempArray[$i] =~ m/^([\.\d]+)$/) {
                $Coefficient = $1;
                $Coefficient *= -1 if($CurrentlyOnReactants);
            } elsif ($TempArray[$i] =~ m/(cpd\d\d\d\d\d)/) {
                my $NewRow;
                $NewRow->{"compound"}->[0] = $1;
                $NewRow->{"compartment"}->[0] = "c";
                $NewRow->{"coefficient"}->[0] = $Coefficient;
                if ($TempArray[$i] =~ m/cpd\d\d\d\d\d\[([a-zA-Z]+)\]/) {
                    $NewRow->{"compartment"}->[0] = lc($1);
                }
                push(@$Parts, $NewRow);
            } elsif ($TempArray[$i] =~ m/=/) {
                $CurrentlyOnReactants = 0;
            }
        }
    }
    return $Parts;
}

sub determinReactionCompartmentOrdering {
    my ($self, $reactionRow) = @_;
    # get reactants and products
    my $parts = parseReactionEquation({equation => $reactionRow->{equation}->[0]});
    # Now figure out what compartment will be "interior" based on
    # compartment hierarchy defined in configuration. Reactions must
    # have at most two compartments.
    my ($exCmpId, $inCmpId) = undef;
    my $allCompartments = {};
    my $hierarchy = $self->compartmentHierarchy();
    # Generate mapping compartment_id => position in hierarchy for each compound in reaction
    map { $allCompartments->{$_} = $hierarchy->{$_} || -1 } # map id to hierarchy or -1
        map { $_->{compartment}->[0] }  @$parts; # extract compartment for brevity
    if((keys %$allCompartments) > 2) {
        warn "Too many compartments for reaction " . $reactionRow->{id}->[0] .
        "! Got: " . join(", ", keys %$allCompartments) . "\n";
        return undef;
    }
    if((keys %$allCompartments) == 2) {
        my ($cmpA, $cmpApos, $cmpB, $cmpBpos) = %$allCompartments; # unroll
        if($cmpApos == $cmpBpos) {
            warn "Cannot create reaction between two compartments ($cmpA, " .
            "$cmpB) at the same level in compartment hierarchy ($cmpApos)\n".
            return undef;
        }
        $exCmpId = ($cmpApos < $cmpBpos) ? $cmpA : $cmpB;
        $inCmpId = ($cmpApos < $cmpBpos) ? $cmpB : $cmpA;
        return ($inCmpId, $exCmpId);
    } elsif((keys %$allCompartments) == 1) {
        my ($cmpA, $cmpApos) = %$allCompartments;
        return ($cmpA);
    } else {
        return ('c');
    }
}

sub generateReactionCompoundFile {
    my ($self, $filename, $reactionTable) = @_;
    open(my $fh, ">", $filename) || die("Could not open $filename for writing!\n");
    my $columns = [qw(reaction compound coefficient cofactor exteriorCompartment)];
    print $fh join("\t", sort @$columns) . "\n";
    my $compartments = $self->getDefaultCompartments();
    for(my $i=0; $i<$reactionTable->size(); $i++) {
        my $row = $reactionTable->get_row($i);
        # produce row [ reaction, compound, coefficient, cofactor, exteriorCompartment ]
        my ($in, $ex) = $self->determinReactionCompartmentOrdering($row);
        next unless(defined($in));        
        my $parts = parseReactionEquation({equation => $row->{equation}->[0]});
        foreach my $part (@$parts) {
            $part->{reaction} = [$row->{id}->[0]];
            $part->{cofactor} = [""];
            $part->{exteriorCompartment} = ($part->{compartment}->[0] eq $in) ? [0] : [1];
            print $fh join("\t", map { join(",", @{($part->{$_} || [])}) } sort @$columns) . "\n";
        }
    }
    close($fh);
}

1;
