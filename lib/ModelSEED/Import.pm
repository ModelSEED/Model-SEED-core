package ModelSEED::Import;
use strict;
use warnings;
use Cwd qw( abs_path );
use ModelSEED::Import::Cache::Tiered;
use ModelSEED::ObjectManager;
use ModelSEED::FIGMODEL;
use Digest::MD5 qw(md5_hex);
use DateTime;
use Carp;
use SAPserver;
use List::Util qw(reduce);
use Try::Tiny;
use BerkeleyDB;
use JSON::XS;

$Data::Dumper::Maxdepth = 3;
use Exporter qw( import );
our @EXPORT_OK = qw(parseReactionEquationBase);

# TODO - need to fix hashes of biochemsitry, compounds, etc.

sub new {
    my ($class, $config) = @_;
    my $self = {};
    if(defined($config->{clearOnStart}) && $config->{clearOnStart}) {
        rmtree($config->{berkeleydb}) if (-d $config->{berkeleydb});
        unlink($config->{database}) if(
            -f $config->{database} && $config->{driver} eq 'SQLite');
        system("cat lib/ModelSEED/ModelDB.sqlite | sqlite3 ".$config->{database});
    }
    $self->{om} = ModelSEED::ObjectManager->new({
        database => $config->{database},
        driver   => $config->{driver},
    });
    $self->{fm} = ModelSEED::FIGMODEL->new(); 
    $self->{fm}->authenticate({username => "sdevoid", password => "marcopolo"});
    $self->{typesToHashFns} = _makeTypesToHashFns();
    $self->{conversionFns}  = _makeConversionFns();
    $self->{objectToQueryFns} = _makeObjectToQueryFns();
    bless $self, $class;
    $self->{cache} = ModelSEED::Import::Cache::Tiered->new({ importer => $self,
        cacheSize => $config->{cacheSize}, directory => $config->{berkeleydb},
        om => $self->{om}, types => [keys %{$self->{typesToHashFns}}], debug => 1
    });
    return $self;
}


sub fm {
    return $_[0]->{fm};
}

sub om {
    return $_[0]->{om};
}

sub sap {
    return $_[0]->{sap};
}

# cache is the standard key-value store where keys are computed by the
# hash() function associated with that type. value is the rose db object
# which may be returned from memory or from the database.
sub cache {
    my ($self, $type, $key, $value) = @_;
    if(defined($value)) {
        return $self->{cache}->set($type, $key, $value);
    } else {
        return $self->{cache}->get($type, $key);
    }
}

# idCache is the key-value store where keys are "old" ids like
# cpd00001 and rxn12345. Values are rose db objects. Note that this
# uses cache() on the backside so it is as efficient as that function.
sub idCache {
    my ($self, $type, $key, $hash) = @_;
    if(defined($hash)) {
        return $self->{id_cache}->{$type}->{$key} = $hash;
    } elsif(defined($key)) {
        my $hash = $self->{id_cache}->{$type}->{$key};
        return $self->cache($type, $hash);
    } else {
        return $self->{id_cache};
    }
}

# clearIdCache - clears a set of id => object caches
# this is used whenever you are switching from one provenance object
# of a specific type to another provenance object (e.g. biochemistry
# to biochemistry). It accepts an array of object names (or removes
# everything).
sub clearIdCache {
    my ($self, $types) = @_;
    $types = [keys %{$self->{id_cache}} ] unless(defined($types));
    foreach my $type (@$types) {
        $self->{id_cache}->{$type} = {};
    }
}


# hash - returns an md5 hash (hex) of the (type, object) supplied.
# The hash functions are implemented per-type, and designed specifically
# to produce the same hash-sum for an "identical" object.
sub hash {
    my ($self, $type, $object) = @_;
    return $self->{typesToHashFns}->{$type}->($object);
}

# makeQuery - returns a HashRef "query object", which is essentially
# key => value pairs that would return a single object from the
# rose db database (specifically the object passed in).
sub makeQuery {
    my ($self, $type, $rdbObject) = @_;
    return $self->{objectToQueryFns}->{$type}->($rdbObject);
}

# convert - converts a (type, object) pair where the object
# is generally a FIGMODELTable row into a hashRef suitable
# to be passed to a rose db object constructor.
sub convert {
    my $self = shift;
    my $type = shift;
    my $obj  = shift;
    my $ctx  = shift @_ || $self->idCache();
    return $self->{conversionFns}->{$type}->($self, $obj, $ctx);
}

# returns the compartment hierarchy (hash of 'id' => level)
# e.g. e => 0, c => 2
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
        $config->{filename} = "$dir/$type.txt";
        next if(-e $config->{filename});
        my $objs = $self->fm->database->get_objects($type);        
        my $tbl = $self->fm->database->ppo_rows_to_table($config, $objs);
        $tbl->save();
    }
}

# hash()
sub _makeTypesToHashFns {
    my $f = {};
    $f->{complex} = sub { return md5_hex($_[0]->id . ($_[0]->name || '')); };
    $f->{role} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->exemplar || ''));
    };
    $f->{compound} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->formula || '' ));
    };
    $f->{compound_alias} = sub {
        return $_[0]->alias . $_[0]->type;
    };
    $f->{reaction} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ) . $_[0]->equation);
    };
    $f->{reactionset} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->class || '' ) .
        join(',', sort map { $f->{reaction}->($_) } $_[0]->reactions ));
    };
    $f->{compoundset} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->class || '' ) .
        join(',', sort map { $f->{compound}->($_) } $_[0]->compounds ));
    };
    $f->{reaction_alias} = sub {
        return md5_hex($f->{reaction}->($_[0]->reaction) . $_[0]->type);
    };
    $f->{compartment} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ));
    };
    $f->{reaction_rule_transport} = sub {
        return md5_hex($f->{reaction}->($_[0]->reaction) . $_[0]->compartmentIndex . $f->{compound}->($_[0]->compound));
    };
    $f->{reaction_rule} = sub {
        return md5_hex($f->{reaction}->($_[0]->reaction) . $f->{compartment}->($_[0]->compartment) .
            join(',', sort map { $f->{reaction_rule_transport}->($_) } $_[0]->reaction_rule_transports ));

    };
    $f->{reagent} = sub {
        my ($obj) = @_;
        return md5_hex($f->{reaction}->($obj->reaction) . $f->{compound}->($obj->compound) . $obj->compartmentIndex);
    };
    $f->{default_transported_reagent} = sub {
        return md5_hex($f->{reaction}->($_[0]->reaction) . $f->{compound}->($_[0]->compound) . $_[0]->compartmentIndex);
    }; 
    $f->{complex_role} = sub {
        return md5_hex($f->{complex}->($_[0]->complex) .
               $f->{role}->($_[0]->role));
    };
    $f->{media} = sub {
        return md5_hex($_[0]->id . ($_[0]->name || '') . ($_[0]->type || ''));
    };
    $f->{media_compound} = sub {
        return md5_hex($f->{media}->($_[0]->media) . $f->{compound}->($_[0]->compound));
    };
    $f->{biochemistry} = sub {
        return md5_hex(
        join(',', sort map { $f->{media}->($_) } $_[0]->media ) .
        join(',', sort map { $f->{compartment}->($_) } $_[0]->compartments ) .
        join(',', sort map { $f->{compound}->($_) } $_[0]->compounds) .
        join(',', sort map { $f->{reaction}->($_) } $_[0]->reactions) .
        join(',', sort map { $f->{reactionset}->($_) } $_[0]->reactionsets) .
        join(',', sort map { $f->{compoundset}->($_) } $_[0]->compoundsets));
    };
    $f->{mapping} = sub {
        return md5_hex(
        $f->{biochemistry}->($_[0]->biochemistry) .
        join(',', sort map { $f->{complex}->($_) } $_[0]->complexes) .
        join(',', sort map { $f->{reaction_rule}->($_) } $_[0]->reaction_rules) .
        join(',', sort map { $f->{reaction_rule}->($_) } $_[0]->reaction_rules) .
        join(',', sort map { $f->{role}->($_) } $_[0]->roles));
    };
    $f->{role} = sub {
        return md5_hex($_[0]->name . $_[0]->id);
    };
    $f->{roleset} = sub {
        return md5_hex(join(',', sort map { $f->{role}->($_) } $_[0]->roles)); 
    };
    $f->{genome} = sub {
        return md5_hex($_[0]->id);
    };
    $f->{feature} = sub {
        return md5_hex($f->{genome}->($_[0]->genome) . $_[0]->id . $_[0]->start . $_[0]->stop);
    };
    $f->{annotation_feature} = sub {
        return md5_hex($f->{feature}->($_[0]->feature) . $f->{role}->($_[0]->role));
    };
    $f->{annotation} = sub {
        return md5_hex($f->{genome}->($_[0]->genome) . ( $_[0]->name || '' ) . 
        join(',', sort map { $f->{annotation_feature}->($_) } $_[0]->annotation_features));
    };
    return $f;
};

# makeQuery()
sub _makeObjectToQueryFns {
    my $f = {};
    $f->{complex} = sub { return { uuid => $_[0]->uuid }};
    $f->{role} = sub { return  { uuid => $_[0]->uuid }};
    $f->{compound} = sub { return { uuid => $_[0]->uuid }};
    $f->{compound_alias} = sub { return { alias => $_[0]->alias, type => $_[0]->type }};
    $f->{reaction} = sub { return { uuid => $_[0]->uuid }};
    $f->{reactionset} = sub { return { uuid => $_[0]->uuid }};
    $f->{compoundset} = sub { return { uuid => $_[0]->uuid }};
    $f->{reaction_alias} = sub { return { alias => $_[0]->alias, type => $_[0]->type }};
    $f->{compartment} = sub { return { uuid => $_[0]->uuid }};
    $f->{reaction_rule_transport} = sub {
        return {
            reaction_uuid => $_[0]->reaction_uuid,
            compound_uuid => $_[0]->compound_uuid,
            compartmentIndex => $_[0]->compartmentIndex,
        };
    };
    $f->{reaction_rule} = sub { return { uuid => $_[0]->uuid }};
    $f->{reagent} = sub {
        return {
            reaction_uuid => $_[0]->reaction_uuid,
            compound_uuid => $_[0]->compound_uuid,
            compartmentIndex => $_[0]->compartmentIndex,
        };
    };
    $f->{default_transported_reagent} = sub {
        return {
            reaction_uuid => $_[0]->reaction_uuid,
            compound_uuid => $_[0]->compound_uuid,
            compartmentIndex => $_[0]->compartmentIndex,
        };
    };
    $f->{complex_role} = sub {
        return {
            complex_uuid => $_[0]->complex_uuid,
            role_uuid => $_[0]->role_uuid,
        };
    };
    $f->{media} = sub { return { uuid => $_[0]->uuid }};
    $f->{media_compound} = sub {
        return {
            media_uuid => $_[0]->media_uuid,
            compound_uuid => $_[0]->compound_uuid,
        };
    };
    $f->{biochemistry} = sub { return { uuid => $_[0]->uuid }};
    $f->{mapping} = sub { return { uuid => $_[0]->uuid }};
    $f->{role} = sub { return { uuid => $_[0]->uuid }};
    $f->{roleset} = sub { return { uuid => $_[0]->uuid }};
    $f->{genome} = sub { return { uuid => $_[0]->uuid }};
    $f->{feature} = sub { return { uuid => $_[0]->uuid }};
    $f->{annotation_feature} = sub { return { uuid => $_[0]->uuid }};
    $f->{annotation} = sub { return { uuid => $_[0]->uuid }};
    return $f;
}


# This is a set of functions converting a row object
# into a hash that can be used by getOrCreateObject()
sub _makeConversionFns {
    # Return a DateObject given default epoch timestamp
    my $date = sub {
        my ($self, $row, $ctx) = @_;
        return ($row->{modificationDate}->[0]) ? DateTime->from_epoch(epoch => $row->{modificationDate}->[0]) :
            ($row->{creationDate}->[0]) ? DateTime->from_epoch(epoch => $row->{creationDate}->[0]) : 
            DateTime->now();
    };
    my $f = {};
    $f->{compound} = sub {
        my ($self, $row, $ctx) = @_;
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
        my ($self, $row, $ctx) = @_;
        my $obj = $self->idCache("compound", $row->{COMPOUND}->[0]);
        return undef unless($obj);
        return {
            type => $row->{type}->[0],
            alias => $row->{alias}->[0],
            compound => $obj,
        };
    };
    $f->{reaction} = sub {
        my ($self, $row, $ctx) = @_;
        my $codes = { reversibility => '', thermoReversibility => ''};
        foreach my $key (keys %$codes) {
            my ($forward, $reverse) = (0, 0);
            $forward = 1 if(defined($row->{$key}->[0]) && $row->{$key}->[0] =~ />/);
            $reverse = 1 if(defined($row->{$key}->[0]) && $row->{$key}->[0] =~ /</);
            if(!$forward && $reverse) {
                $codes->{$key} = "<";
            } elsif(!$reverse && $forward) {
                $codes->{$key} = ">";
            } else {
                $codes->{$key} = "=";
            }
        }
        my $parts = parseReactionEquation($row);
        unless(@$parts) {
            warn "No equation for reaction: " . $row->{id}->[0] . "\n";
            return undef;
        }
        my $cmp = $self->determinePrimaryCompartment($parts);
        my $cmpObj = $self->idCache("compartment", $cmp);
        unless($cmpObj) {
            warn "Could not identify compartment for reaction: " .
            $row->{id}->[0] . " with compartment " . $cmp . "\n";
            return undef;
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
            defaultCompartment => $cmpObj,
        };
    };
    $f->{reaction_alias} = sub {
        my ($self, $row, $ctx) = @_;
        my $obj = $self->idCache("reaction", $row->{REACTION}->[0]);
        return undef unless($obj);
        return {
            type => $row->{type}->[0],
            alias => $row->{alias}->[0],
            reaction => $obj,
        };
    };
    $f->{reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->idCache("reaction", $row->{reaction}->[0]);
        my $cpd = $self->idCache("compound", $row->{compound}->[0]);
        unless(defined($rxn) && defined($cpd)) {
            return undef;
        }
        return {
            reaction => $rxn,
            compound => $cpd,
            coefficient => $row->{coefficient}->[0],
            cofactor => $row->{cofactor}->[0] || undef,
            compartmentIndex => $row->{compartmentIndex}->[0],
        };
    };    
    $f->{default_transported_reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->idCache("reaction", $row->{reaction}->[0]);
        my $cpd = $self->idCache("compound", $row->{compound}->[0]);
        my $cmp = $self->idCache("compartment", $row->{compartment}->[0]);
        unless(defined($rxn) && defined($cmp) && defined($cpd)) {
            my $str = (!defined($rxn)) ? "no reaction\n" : 
                      (!defined($cpd)) ? "no cpd\n" : "no compartment\n";
            warn $str;
            return undef;
        }
        return {
            reaction => $rxn,
            compound => $cpd,
            defaultCompartment => $cmp,
            compartmentIndex => $row->{compartmentIndex}->[0],
            transportCoefficient => $row->{transportCoefficient}->[0],
            isImport => $row->{isImport}->[0],
        };
    };
    $f->{role} = sub {
        my ($self, $row, $ctx) = @_;
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0] || undef,
            exemplar => $row->{exemplar}->[0] || undef,
        };
    };
    $f->{complex} = sub {
        my ($self, $row, $ctx) = @_;
        return {
            id => $row->{id}->[0],
            name => $row->{name}->[0] || undef,
            modDate => $date->($row),
        };
    };
    $f->{complexRole} = sub {
        my ($self, $row, $ctx) = @_;
        my $complex = $self->idCache("complex", $row->{COMPLEX}->[0]);
        my $role    = $self->idCache("role", $row->{ROLE}->[0]);
        if(defined($role) && defined($complex)) {
            return { 
                complex => $complex,
                role => $role,
                type => $row->{type}->[0] || '',
            };
        } else {
            return undef;
        }
    };

    $f->{reactionRule} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->idCache("reaction", $row->{REACTION}->[0]);
        my $cmp = $rxn->defaultCompartment;
        if(defined($rxn) && defined($cmp)) {
            return {
                reaction => $rxn,
                compartment => $cmp,
                direction => "=",
           };
        } else {
            return undef;
        }
    };
    $f->{feature} = sub {
        my ($self, $row, $ctx) = @_;
        my $genome = $self->idCache("genome", $row->{GENOME}->[0]);
        return undef unless(defined($genome));
        my $min = $row->{"MIN LOCATION"}->[0];
        my $max = $row->{"MAX LOCATION"}->[0];
        my $start = ($row->{DIRECTION}->[0] eq 'for') ? $min : $max;
        my $stop  = ($row->{DIRECTION}->[0] eq 'for') ? $max : $min;
        return {
            start => $start,
            stop  => $stop,
            id => $row->{ID}->[0],
            genome => $genome,
        };
    }; 
    $f->{compartment} = sub {
        my ($self, $row, $ctx) = @_;    
        return {
            id => $row->{ID}->[0],
            name => $row->{NAME}->[0],
            modDate => $date->($row),
        };
    };
    return $f;
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
        #reagent => 'reagent.txt',
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
    # Create compartments - for reactions, default_transported_reagents
    my $compartments = $self->getDefaultCompartments();
    $RDB_biochemistry->add_compartments(@$compartments);
    warn "importing compounds\n";
    # Compounds
    my $compound_id_map = {};
    for(my $i=0; $i<$files->{compound}->size(); $i++) {
        my $row = $files->{compound}->get_row($i);
        my $hash = $self->convert("compound", $row);
        my $RDB_compound = $self->getOrCreateObject("compound", $hash); 
        $RDB_biochemistry->add_compounds($RDB_compound); 
    }
    warn "imported " . scalar(keys %{$self->idCache()->{"compound"}}) . " compounds\n";
    warn "importing compound aliases\n";
    # CompoundAliases
    my $aliasRepeats = {};
    for(my $i=0; $i<$files->{compound_alias}->size(); $i++) {
        my $row = $files->{compound_alias}->get_row($i);
        my $hash = $self->convert("compound_alias", $row);
        next unless defined($hash);
        my $error;
        ($error, $aliasRepeats) = checkAliases($aliasRepeats, $hash, "compound");
        next if $error;
        my $RDB_compound_alias =
            $self->getOrCreateObject("compound_alias", $hash);
        my $id = $RDB_compound_alias->compound->id;
        my $RDB_compound = $self->idCache("compound", $id);
        unless(defined($RDB_compound)) {
            warn "Could not find compound for alias $id.\n";
            next;
        }
        $RDB_compound->add_compound_aliases($RDB_compound_alias);
        $RDB_compound_alias->compound;
        $RDB_compound->save();
    }
    warn Dumper($self->{cache}->debug_stats);
    # Reactions
    my $missed_rxn_count = 0;
    my ($missed_rxn_cpd_count, $missed_rxn_cpd_by_rxn) = (0, {});
    my ($missed_rt_count, $missed_rt_by_rxn) = (0, {});
    for(my $i=0; $i<$files->{reaction}->size(); $i++) {
        warn "imported $i reactions\n" if($i % 100 == 0 && $i != 0);
        my $row = $files->{reaction}->get_row($i);
        my $hash = $self->convert("reaction", $row);
        unless(defined($hash)) {
            $missed_rxn_count += 1;
            next;
        }
        my $RDB_reaction = $self->getOrCreateObject("reaction", $hash);
        $RDB_biochemistry->add_reactions($RDB_reaction);
        # Reagents and DefaultTransportedReagents
        my $data = $self->generateReactionDataset($row);
        foreach my $reagent (@{$data->{reagents}}) {
            if(!defined($reagent)) {
                $missed_rxn_cpd_count += 1;
                $missed_rxn_cpd_by_rxn->{$RDB_reaction->id} = 1 +
                    ($missed_rxn_cpd_by_rxn->{$RDB_reaction->id} || 0);
                next;
            }
            my $RDB_reagent = $self->getOrCreateObject("reagent", $reagent);
        }
        foreach my $rt (@{$data->{default_transported_reagents}}) {
            if(!defined($rt)) {
                $missed_rt_count += 1;
                $missed_rt_by_rxn->{$RDB_reaction->id} = 1 +
                    ($missed_rt_by_rxn->{$RDB_reaction->id} || 0);
                next;
            }
            my $RDB_rt = $self->getOrCreateObject("default_transported_reagent", $rt);
        }
            
    }
    if($missed_rxn_count > 0) {
        warn "Failed to add $missed_rxn_count reactions to database\n";
    }
    if($missed_rxn_cpd_count > 0) {
        # Error cases for reaction compound
        warn "Failed to add $missed_rxn_cpd_count reagents to database across " .
            scalar(keys %$missed_rxn_cpd_by_rxn) . " reactions.\n";
    }
    if($missed_rt_count > 0) {
        # Error cases for reagent transport 
        warn "Failed to add $missed_rt_count default transported reagents to database across " .
            scalar(keys %$missed_rt_by_rxn) . " reactions.\n";
    }
    warn "importing reaction aliases\n";
    # ReactionAlias
    $aliasRepeats = {};
    for(my $i=0; $i<$files->{reaction_alias}->size(); $i++) {
        my $row = $files->{reaction_alias}->get_row($i);
        my $hash = $self->convert('reaction_alias', $row);
        next unless(defined($hash));
        next if($hash->{type} eq "name" || $hash->{type} eq "searchname");
        my $error;
        ($error, $aliasRepeats) = checkAliases($aliasRepeats, $hash, "reaction");
        next if $error;
        my $RDB_reaction_alias =
            $self->getOrCreateObject("reaction_alias", $hash);
    }
    warn "importing media\n";
    # Media
    my $defaultMediaObjs = $self->getDefaultMedia(); 
    foreach my $obj (@$defaultMediaObjs) {
        $RDB_biochemistry->add_media($obj);
    }
    warn "finalizing\n";
    # Now create if it doesn't already exist
    my $biochem_hash = $self->hash("biochemistry", $RDB_biochemistry);
    unless(defined($self->cache("biochemistry", $biochem_hash))) {
        $RDB_biochemistry->save;
        $self->cache("biochemistry", $biochem_hash, $RDB_biochemistry);
    }
    # Add alias that we wanted
    my $bio = $self->cache("biochemistry", $biochem_hash);
    $bio->add_biochemistry_aliases({ username => $username, id => $name});
    # TODO - check if we've added this already, lock if not already locked
    $bio->save();
    $self->om->db->commit;
    return $bio;
}
    
    

sub importMappingFromDir {
    my ($self, $dir, $RDB_biochemObject, $username, $name) = @_;
    # first validate that the dir exists and has the right files
    my $ctx = $self->cache;
    unless(-d $dir) {
        warn "Unable to find $dir\n";
        return undef;
    }
    $dir = $self->standardizeDirectory($dir);
    my $files = {complex => 'complex.txt',
                 role => 'role.txt',
                 complexRole => 'cpxrole.txt',
                 reactionRule => 'rxncpx.txt'};
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
    $RDB_mappingObject->biochemistry($RDB_biochemObject);
    # Create complexes
    for(my $i=0; $i<$files->{complex}->size(); $i++) {
        my $row = $files->{complex}->get_row($i);
        my $hash = $self->convert("complex", $row);
        my $RDB_complexObject = $self->getOrCreateObject('complex', $hash);
        $RDB_mappingObject->add_complexes($RDB_complexObject);
    } 
    # Create roles 
    for(my $i=0; $i<$files->{role}->size(); $i++) {
        my $row = $files->{role}->get_row($i);
        my $hash = $self->convert("role", $row);
        my $RDB_roleObject = $self->getOrCreateObject('role', $hash);
        $RDB_mappingObject->add_roles($RDB_roleObject);
    } 
    # Create complexRole
    my $cpxRoleFailures = 0;
    for(my $i=0; $i<$files->{complexRole}->size(); $i++) {
        my $row = $files->{complexRole}->get_row($i);
        my $hash = $self->convert("complexRole", $row);
        if(!defined($hash)) {
            $cpxRoleFailures += 1;
            next;
        }
        my $RDB_complexRoleObject = $self->getOrCreateObject('complex_role', $hash);
        $RDB_complexRoleObject->save();
    }
    warn "Got $cpxRoleFailures complex_role failures, ".
        "this is probably normal.\n" if $cpxRoleFailures > 0;
    $RDB_mappingObject->add_mapping_aliases({username => $username, id => $name});
    # Create reactionRule 
    for(my $i=0; $i<$files->{reactionRule}->size(); $i++) {
        my $row = $files->{reactionRule}->get_row($i);
        my $hash = $self->convert("reactionRule", $row);
        my $cpx  = $self->cache("complex", $row->{COMPLEX}->[0]);
        unless(defined($cpx)) {
            warn "Could not find complex: " . $row->{COMPLEX}->[0] . " for reactionRule\n";
            next;
        }
        unless(defined($hash)) {
            warn "Could not convert reactionRule\n";
            next;
        }
        my $RDB_reactionRule = $self->getOrCreateObject("reaction_rule", $hash);
        my $rxn = $RDB_reactionRule->reaction;
        $cpx->add_reaction_rules($RDB_reactionRule);
        $cpx->save();
        $RDB_mappingObject->add_reaction_rules($RDB_reactionRule);
        # Create reaction_rule_transport
        foreach my $dtr ($rxn->default_transported_reagents) {
            my $hash =  {
                reaction => $dtr->reaction,
                reaction_rule => $RDB_reactionRule,
                compound => $dtr->compound,
                transportCoefficient => $dtr->transportCoefficient,
                compartment => $dtr->defaultCompartment,
                compartmentIndex => $dtr->compartmentIndex,
                isImport => $dtr->isImport,
            };
            my $RDB_reactionRuleTransport = $self->getOrCreateObject("reaction_rule_transport", $hash);
        } 
    }
    # Now create if it doesn't already exist
    my $mapping_hash = $self->hash("mapping", $RDB_mappingObject);
    unless(defined($self->cache("mapping", $mapping_hash))) {
        $RDB_mappingObject->save;
        $self->cache("mapping", $mapping_hash, $RDB_mappingObject);
    }
    # Add alias that we wanted
    my $map = $self->cache("mapping", $mapping_hash);
    $map->add_mapping_aliases({ username => $username, id => $name});
    # TODO - check if we've added this already, lock if not already locked
    $map->save();
    $self->om->db->commit;
    return $map; 
}

sub getGenomeObject {
    my ($self, $genomeID) = @_;
    unless(defined($self->cache("genome", $genomeID))) {
        my $columns = [ 'dna-size', 'gc-content', 'pegs', 'name', 'taxonomy', 'md5_hex' ]; 
        my $genomeData = $self->sap->genome_data({
            -ids => [ $genomeID ],
            -data => $columns,
        });
        my $hash = {
            id => $genomeID, 
            name => $genomeData->{$genomeID}->[3],
            source => 'SEED',
            cksum => $genomeData->{$genomeID}->[5],
            size => $genomeData->{$genomeID}->[0],
            genes => $genomeData->{$genomeID}->[2],
            gc => $genomeData->{$genomeID}->[1],
            taxonomy => $genomeData->{$genomeID}->[4],
        };
        my $obj = $self->getOrCreateObject("genome", $hash); 
        warn "Unable to create genome object $genomeID:\n".
            Dumper($hash) . "\n" unless(defined($obj));
    }
    return $self->cache("genome", $genomeID);
}

sub importAnnotationFromDir {
    my ($self, $dir, $username, $id) = @_;
    # Directory will contain a features.txt file
    my $file = "$dir/features.txt";
    my $config = { filename => $file, delimiter => "\t" };
    my $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    my ($RDB_annotation, $RDB_genome);
    # Rows in the table have columns: 
    # ID  GENOME  ESSENTIALITY    ALIASES TYPE    LOCATION    LENGTH
    # DIRECTION   MIN LOCATION    MAX LOCATION    ROLES   SOURCE  SEQUENCE
    for(my $i=0; $i<$tbl->size(); $i++) {
        my $row = $tbl->get_row($i);
        $RDB_genome = $self->getGenomeObject($row->{GENOME}->[0]) unless(defined($RDB_genome));
        unless(defined($RDB_genome)) {
            print "Could not retrive genome for " . $row->{GENOME}->[0] . "\n";
            return undef;
        }
        unless(defined($RDB_annotation)) {
            $RDB_annotation = $self->om->create_object("annotation", { genome => $RDB_genome });
        }
        my $hash = $self->convert("feature", $row); 
        unless(defined($hash)) {
            warn "Could not create feature for genome " . $RDB_genome->id . " ($i)\n";
            next;
        }
        my $RDB_feature = $self->getOrCreateObject("feature", $hash);
        unless(defined($RDB_feature)) {
            warn "Could not create feature: " . Dumper($hash) . "\n"; 
            next;
        }
        my $RDB_role = $self->cache("role", $row->{ROLES}->[0]);
        if(!defined($RDB_role)) {
            warn "Could not find role " . $row->{ROLES}->[0] . "\n";
            next;
        }
        my $annotation_feature = $self->getOrCreateObject(
            "annotation_feature", { 
                genome => $RDB_genome,
                role => $RDB_role,
                feature => $RDB_feature,
        });
    }
    return $RDB_annotation;
}
    

# returns a set of rdbo objects for compartments
# if those objects do not already exist, create them
sub getDefaultCompartments {
    my ($self) = @_;
    my $compartments = $self->om->get_objects("compartment");
    if(@$compartments == 0) { 
        my $values = [];
        my $oldCompartments = $self->fm->database->get_objects("compartment");
        foreach my $old (@$oldCompartments) {
            my $hash = { ID => [$old->id], NAME => [$old->name] };
            $hash = $self->convert("compartment", $hash);
            my $obj = $self->getOrCreateObject("compartment", $hash) if(defined($hash->{id}));
            unless(defined($obj)) {
                warn "Failed to add default compartment " . $old->name . "\n";
                next;
            }
            push(@$values, $obj);
        }
        my $defaultHierarchy = {
            'e' => 0,
            'w' => 1, 'p' => 1,
            'c' => 2,
            'g' => 3, 'r' => 3, 'l' => 3, 'n' => 3,
            'd' => 3, 'm' => 3, 'x' => 3, 'v' => 3, 'h' => '3'
        };
        foreach my $cmp (@$values) {
            if(!defined($defaultHierarchy->{$cmp->id})) {
                warn "No default compartment hierarchy for " . $cmp->name . " (".$cmp->id.")\n";
            }
        }
        return $values;
    }
    return $compartments;
}

sub getDefaultMedia {
    my ($self) = @_;
    my $media = $self->om->get_objects("media");
    if(@$media == 0) {
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
                my $compoundObj= $self->idCache("compound", $mediaCpd->entity());
                unless($compoundObj) {
                    warn "Couldn't find compound " . $mediaCpd->entity() . "\n";
                    next;
                }
                my $hash = {
                    compound => $compoundObj,
                    concentration => $mediaCpd->concentration(),
                    minflux => $mediaCpd->minFlux(),
                    maxflux => $mediaCpd->maxFlux(),
                };
                push(@$newMediaCpds, $hash);
            }
            $mediaObj->add_media_compounds(@$newMediaCpds);
            $mediaObj->save();
        }
    }
    return $media;
}
        



# getOrCreateObject - hashes and looks up object
# in lookupData. If it exists, returns that object.
# Otherwise, saves object to database and returns it.
# ( Also adds it to lookup tables. )
sub getOrCreateObject {
    my ($self, $type, $hash) = @_;
    # Delete keys where the value is undefined
    #map { delete $hash->{$_} } grep
    #    { !defined($hash->{$_}) } keys %$hash;
    my $obj;
    try {
        $obj = $self->om()->create_object($type, $hash);
    } catch {
        warn "Died when trying to create object ($type):\n".
        Dumper($hash) . "\n" . "With error: $_";
    };
    unless(defined($obj)) {
        warn "Failed to create object of type: $type,\n".
            Dumper($hash) . "\n";
        return undef;
    }
    my $val = $self->hash($type, $obj);
    # cache will return cached object, or save ours
    my $final =  $self->cache($type, $val, $obj);
    # only now try to save in idCache
    try {
        my $secondKey = $final->id;
        $self->idCache($type, $secondKey, $val);
    };
    return $final;
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
            ", alias => " . $hash->{alias} . " for $type: " . $existing->id . " )\n";
        $error = 1;
    } else {
        $aliasRepeats->{$hash->{type}.$hash->{alias}} = $hash->{$type};
    }
    return ($error, $aliasRepeats);
}

sub parseReactionEquation {
    my ($row) = @_;
    my $Equation = $row->{equation}->[0];
    my $Reaction = $row->{id}->[0];
    return parseReactionEquationBase($Equation, $Reaction);
}

sub parseReactionEquationBase {
    my ($Equation, $Reaction) = @_;
    my $Parts = [];
    if (defined($Equation)) {
        my @TempArray = split(/\s/,$Equation);
        my $CurrentlyOnReactants = 1;
        my $Coefficient = 1;
        for (my $i=0; $i < @TempArray; $i++) {
            if ($TempArray[$i] =~ m/^\(([\.\d]+)\)$/ || $TempArray[$i] =~ m/^([\.\d]+)$/) {
                $Coefficient = $1;
            } elsif ($TempArray[$i] =~ m/(cpd\d\d\d\d\d)/) {
                $Coefficient *= -1 if($CurrentlyOnReactants);
                my $NewRow;
                $NewRow->{"reaction"}->[0] = $Reaction;
                $NewRow->{"compound"}->[0] = $1;
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


sub generateReactionDataset {
    my ($self, $reactionRow) = @_;
    my $seenCompartments = {};
    my $rxn = $reactionRow->{id}->[0];
    my $parts = parseReactionEquation($reactionRow);
    my $reactionCompartment = $self->determinePrimaryCompartment($parts);
    my $final = { reagents => [], default_transported_reagents => [] };
    # 2 A[e] + B => C + A[p] + A
    # 1. Mass balance: add (and subtract) reagent stoichiometry to get balanced eq
    #    In this step we ignore compartments when looking at compounds
    # { A => 0, B => -1, C => 1 }
    # 2. Transport Coefficients
    # { A => { e => -2, p => 1 } }
    #
    #     B => C
    #       +
    # 2A[e] => 2A
    #       +
    #     A => A[p]
    #       ==
    # 2A[e] + B => A + A[p] + C
    my $massBalance = {};
    my $transports = {};
    foreach my $part (@$parts) {
        my $cpd  = $part->{compound}->[0];
        my $coff = $part->{coefficient}->[0];
        my $cmp  = $part->{compartment}->[0];
        if(defined($massBalance->{$cpd})) {
            $massBalance->{$cpd} += $coff;
        } else {
            $massBalance->{$cpd} = $coff;
        }
        if($cmp ne $reactionCompartment) {
            unless(defined($seenCompartments->{$cmp})) {
                $seenCompartments->{$cmp} = ( scalar(keys %$seenCompartments) + 1);
            }
            my $index = $seenCompartments->{$cmp};
            $transports->{$cpd}->{$cmp} = 0 unless(defined($transports->{$cpd}->{$cmp}));
            $transports->{$cpd}->{$cmp} += $coff;
        }
    }
    # Now construct Reagent and defaultTransportedReagent data:
    foreach my $part (@$parts) {
        my $cmp = $part->{compartment}->[0];
        my $cpd = $part->{compound}->[0];
        my $index = $seenCompartments->{$cmp} || 0;
        if($cmp ne $reactionCompartment) {
            next unless(defined($transports->{$cpd}->{$cmp}));
            # it's not in the same compartment, create default_transported_reagent entry
            my $isImport = ($transports->{$cpd}->{$cmp} < 0) ? 1 : 0;
            my $obj = $self->convert("default_transported_reagent", {
                compartment => [$cmp],
                compartmentIndex => [$index],
                compound => [$part->{compound}->[0]],
                isImport => [$isImport],
                reaction => [$rxn],
                transportCoefficient => [$transports->{$cpd}->{$cmp}],
            });
            delete $transports->{$cpd}->{$cmp};
            unless(defined($obj)) {
                warn "Could not create default_transported_reagent for $rxn:\n";
                next;
            }
            push(@{$final->{default_transported_reagents}}, $obj); 
        }
        if(defined($massBalance->{$cpd})) {
            my $obj = $self->convert("reagent", {
                compartmentIndex => [$index],
                compound => [$cpd],
                reaction => [$rxn],
                coefficient => [$massBalance->{$cpd}],
            });
            delete $massBalance->{$cpd};
            unless(defined($obj)) {
                warn "Could not convert reagent for $rxn:\n".
                Dumper($part) . "\n";
                next;
            }
            push(@{$final->{reagents}}, $obj);
        }
    }
    return $final;
}


# Situate the reaction in the cytosol (c) unless it does not exist.
# If it does not exist, select the innermost compartment.
sub determinePrimaryCompartment {
    my ($self, $parts) = @_;
    my $hierarchy = $self->compartmentHierarchy();
    my ($innermostScore, $innermost);
    foreach my $part (@$parts) {
        my $cmp = $part->{compartment}->[0];
        if($cmp eq 'c') {
            $innermost = $cmp;
            last;
        }
        my $score = $hierarchy->{$cmp};
        if(!defined($innermostScore) || $score > $innermostScore) {
            $innermostScore = $score;
            $innermost = $cmp;
        }
    }
    return $innermost;
}

1;
