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
        confess "undef here" if(!defined($_[0]));
        return $_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->formula || '' );
    };
    $f->{compound_alias} = sub {
        return $f->{compound}->($_[0]->compound_obj) . $_[0]->alias . $_[0]->type;
    };
    $f->{reaction} = sub {
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
        my $obj = $ctx->{compounds}->{$row->{COMPOUND}->[0]};
        return undef unless($obj);
        return {
            type => $row->{type}->[0],
            alias => $row->{type}->[0],
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
        my $obj = $ctx->{reactions}->{$row->{REACTION}->[0]};
        return undef unless($obj);
        return {
            type => $row->{type}->[0],
            alias => $row->{type}->[0],
            reaction => $obj->uuid,
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
        compound_alias => 'cpdals.txt',
        reaction_alias => 'rxnals.txt',
    };        
    my $config = { filename => undef, delimiter => "\t"};
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
    for(my $i=0; $i<$files->{compound_alias}->size(); $i++) {
        my $row = $files->{compound_alias}->get_row($i);
        my $hash = $self->convert("compound_alias", $row, $ctx);
        next unless defined($hash);
        my $RDB_compound_alias =
            $self->getOrCreateObject("compound_alias", $hash);
        $RDB_biochemistry->add_compound_alias($RDB_compound_alias);
    }
    # Reactions
    my $reaction_id_map = {};
    for(my $i=0; $i<$files->{reaction}->size(); $i++) {
        my $row = $files->{reaction}->get_row($i);
        my $hash = $self->convert("reaction", $row, $ctx);
        my $RDB_reaction = $self->getOrCreateObject("reaction", $hash);
        $reaction_id_map->{$RDB_reaction->id} = $RDB_reaction;
        $RDB_biochemistry->add_reaction($RDB_reaction);
        # ReactionCompound - TODO
    }
    # ReactionAlias
    for(my $i=0; $i<$files->{reaction_alias}->size(); $i++) {
        my $row = $files->{reaction_alias}->get_row($i);
        my $hash = $self->convert('reaction_alias', $row, $ctx);
        next unless defined($hash);
        my $RDB_reaction_alias =
            $self->getOrCreateObject("reaction_alias", $hash);
        $RDB_biochemistry->add_reaction_alias($RDB_reaction_alias);
    }
    # Media
    my $defaultMediaObjs = $self->getDefaultMedia(); 
    foreach my $obj (@$defaultMediaObjs) {
        $RDB_biochemistry->add_media($obj);
        # MediaCompound - TODO
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
        $RDB_mappingObject->add_complex($RDB_complexObject);
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
}

# returns a set of rdbo objects for compartments
# if those objects do not already exist, create them
sub getDefaultCompartments {
    my ($self) = @_;
    if(defined($self->cache->{compartment})) {
        return [ values %{$self->cache->{compartment}} ];
    } else {
        my $values = [];
        my $oldCompartments = $self->fm->database->get_objects("compartment");
        foreach my $old (@$oldCompartments) {
            my $hash = { id => $old->id(), name => $old->name };
            push(@$values, $self->getOrCreateObject("compartment", $hash));
        }
        return $values;
    }
}

sub getDefaultMedia {
    my ($self, $ctx) = @_;
    if(defined($self->cache->{media})) {
        return [ values %{$self->cache->{media}} ];
    } else {
        my $values = [];
        my $oldMedia = $self->fm->database->get_objects("media");
        foreach my $old (@$oldMedia) {
            my $hash = {
               id => $old->id(),
               name => $old->name(),
            }; 
            my $mediaObj = $self->getOrCreateObject("media", $hash);                  
            my $mediaCpds = $self->fm->database->get_objects('mediacpd', { MEDIA => $old->id() });
            my $newMediaCpds = [];
            foreach my $mediaCpd (@$mediaCpds) {
                my $compoundObj= $ctx->{compounds}->{$mediaCpd->compound()};
                next unless $compoundObj;
                my $hash = {
                    compound => $compoundObj,
                    concentration =>
                    minflux =>
                    maxflux => 
                };
                push(@$newMediaCpds, $hash);
            }
            $mediaObj->media_compound($newMediaCpds);
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

1;
