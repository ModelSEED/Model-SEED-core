package ModelSEED::Import;
use strict;
use warnings;
use Cwd qw( abs_path );
use ModelSEED::Import::Cache::Tiered;
use ModelSEED::Import::Checker;
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
use Moose;
use Time::HiRes qw(time);

with 'MooseX::Log::Log4perl';

# Configurable
has database     => ( is => 'rw', isa => 'Str', required => 1 );
has driver       => ( is => 'rw', isa => 'Str', required => 1 );
has berkeleydb   => ( is => 'rw', isa => 'Str', required => 1 );
has clearOnStart => ( is => 'rw', isa => 'Int', default => 0 );
has cacheSize    => ( is => 'rw', isa => 'Str');
has expectedMisses => ( is => 'rw', isa => 'Str');


# Non-configurable parameters
has om => ( is => 'rw', isa => 'ModelSEED::ObjectManager',
    builder => '_makeObjectManager', lazy => 1);
has fm => ( is => 'rw', isa => 'ModelSEED::FIGMODEL',
    default => sub { return ModelSEED::FIGMODEL->new() });
has sap => ( is => 'rw', isa => 'SAPserver',
    default => sub { return SAPserver->new() });
has typesToHashFns => ( is => 'rw', isa => 'HashRef',
    builder => '_makeTypesToHashFns', lazy => 1);
has conversionFns => ( is => 'rw', isa => 'HashRef',
    builder => '_makeConversionFns', lazy => 1);
has objectToQueryFns => ( is => 'rw', isa => 'HashRef',
    builder => '_makeObjectToQueryFns', lazy => 1);
has _file_cache => ( is => 'rw', isa => 'HashRef', default => sub { return {} });
has _cache => ( is => 'rw', isa => 'ModelSEED::Import::Cache::Tiered', 
    builder => '_makeCache', lazy => 1);
has checker => ( is => 'rw', isa => 'ModelSEED::Import::Checker');



$Data::Dumper::Maxdepth = 3;
use Exporter qw( import );
our @EXPORT_OK = qw(parseReactionEquationBase);

# FIXME - do features have multiple roles ? (annotation_feature needs all of them)
# TODO - model_biomass, biomass
# FIXME - transaction rollback when cached result

my $time = time;

sub elapsed {
    my $elapsed = time - $time;
    $time = time;
    return $elapsed;
} 

sub BUILD {
    my ($self) = @_;
    if($self->clearOnStart) {
        rmtree($self->berkeleydb) if(-d $self->berkeleydb);
        unlink($self->database) if(-f $self->database && $self->driver eq 'SQLite');
        system("cat lib/ModelSEED/ModelDB.sqlite | sqlite3 ".$self->database);
    }
    if(defined($self->expectedMisses) && -f abs_path($self->expectedMisses)) {
        $self->checker(ModelSEED::Import::Checker->new({efFile => $self->expectedMisses}));
    } else {
        $self->checker(ModelSEED::Import::Checker->new());
    }
    $self->fm->authenticate({username => "sdevoid", password => "marcopolo"});
}

sub _makeCache {    
    my ($self) = @_;
    return ModelSEED::Import::Cache::Tiered->new({
        importer => $self, cacheSize => $self->cacheSize,
        directory => $self->berkeleydb, om => $self->om,
    });
}

sub _makeObjectManager {
    my ($self) = @_;
    return ModelSEED::ObjectManager->new({
        database => $self->database,
        driver   => $self->driver,
    });
}


# cache is the standard key-value store where keys are computed by the
# hash() function associated with that type. value is the rose db object
# which may be returned from memory or from the database.
sub cache {
    my ($self, $type, $key, $value) = @_;
    if(defined($value)) {
        return $self->_cache->set($type, $key, $value);
    } else {
        return $self->_cache->get($type, $key);
    }
}

sub uuidCache {
    my ($self, $type, $key, $uuid) = @_;
    if(defined($uuid)) {
        return $self->{uuid_cache}->{$type}->{$key} = $uuid;
    } elsif(defined($key)) {
        return $self->{uuid_cache}->{$type}->{$key};
    } else {
        die "Must pass in at least key for $type";
    }
}

    
# idCache is the key-value store where keys are "old" ids like
# cpd00001 and rxn12345. Values are rose db objects. Note that this
# uses cache() on the backside so it is as efficient as that function.
sub idCache {
    my ($self, $type, $key, $hash) = @_;
    if(defined($hash)) {
        confess "undefined key $type, $hash" unless(defined($key));
        return $self->{id_cache}->{$type}->{$key} = $hash;
    } elsif(defined($key)) {
        my $hash = $self->{id_cache}->{$type}->{$key};
        return $self->cache($type, $hash);
    } else {
        return $self->{id_cache};
    }
}

sub fileCache {
    my ($self, $type, $files, $cacheHash) = @_;
    my $fileHash = hashFiles($files);
    if(defined($cacheHash)) {
        return $self->_file_cache->{$type}->{$fileHash} = $cacheHash;
    } else {
        $cacheHash = $self->_file_cache->{$type}->{$fileHash};
        if(defined($cacheHash)) {
            return $self->cache($type, $cacheHash);
        }
    }
    return undef;
}
        
sub hashFiles {
    my ($files) = @_;
    my $total = '';
    foreach my $file (sort @$files) {
        my $md5sum = `md5sum $file`;
        $md5sum =~ s/\s.*//;        
        chomp $md5sum;
        $total .= $md5sum;
    }
    $total = md5_hex($total);
    return $total;
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
    return $self->typesToHashFns->{$type}->($object);
}

# makeQuery - returns a HashRef "query object", which is essentially
# key => value pairs that would return a single object from the
# rose db database (specifically the object passed in).
sub makeQuery {
    my ($self, $type, $rdbObject) = @_;
    return $self->objectToQueryFns->{$type}->($rdbObject);
}

# convert - converts a (type, object) pair where the object
# is generally a FIGMODELTable row into a hashRef suitable
# to be passed to a rose db object constructor.
sub convert {
    my $self = shift;
    my $type = shift;
    my $obj  = shift;
    my $ctx  = shift @_ || $self->idCache();
    confess "type or object not defined" unless(defined($type) && defined($obj));
    confess "no subroutine for $type" unless(defined($self->conversionFns->{$type}));
    return $self->conversionFns->{$type}->($self, $obj, $ctx);
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
        return md5_hex(($_[0]->id || '') . ( $_[0]->name || '' ) . ( $_[0]->exemplar || ''));
    };
    $f->{compound} = sub {
        return md5_hex($_[0]->id . ( $_[0]->name || '' ) . ( $_[0]->formula || '' ) . 
        join(',', sort map { $f->{compound_alias}->($_) } $_[0]->compound_aliases));
    };
    $f->{compound_alias} = sub {
        return $_[0]->alias . $_[0]->type;
    };
    $f->{reaction} = sub {
        confess "got here!" unless defined $_[0];
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
        return md5_hex(($_[0]->name || '') . ($_[0]->id || ''));
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
    $f->{model} = sub {
        return md5_hex($_[0]->id . join(',', sort map { $_->id } $_[0]->parents));
    };
    $f->{model_compartment} = sub {
            return md5_hex($f->{compartment}->($_[0]->compartment) . $_[0]->compartmentIndex .
            $f->{model}->($_[0]->model));
    };
    $f->{model_reaction} = sub {
            return md5_hex($f->{reaction}->($_[0]->reaction) . $_[0]->direction .
            $f->{model_compartment}->($_[0]->model_compartment) . $f->{model}->($_[0]->model));
    };
    $f->{model_transported_reagent} = sub {
            return md5_hex($f->{reaction}->($_[0]->reaction) . $f->{model}->($_[0]->model) .
                $_[0]->compartmentIndex);
    };
    $f->{biomass_compound} = sub {
        return md5_hex($f->{compound}->($_[0]->compound) . $_[0]->coefficient .
            $f->{model_compartment}->($_[0]->model_compartment));
    };
    $f->{biomass} = sub {
        return md5_hex($_[0]->id . join(',', sort map {
            $f->{biomass_compound}->($_) } $_[0]->biomass_compounds));
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
    $f->{annotation_feature} = sub { return {
        annotation_uuid => $_[0]->annotation_uuid,
        feature_uuid => $_[0]->feature_uuid,
        role_uuid => $_[0]->role_uuid,
    }};
    $f->{annotation} = sub { return { uuid => $_[0]->uuid }};
    $f->{model} = sub { return { uuid => $_[0]->uuid }};
    $f->{model_reaction} = sub { return {
        reaction_uuid => $_[0]->reaction_uuid,
        model_uuid => $_[0]->model_uuid,
    }};
    $f->{model_transported_reagent} = sub { return {
        reaction_uuid => $_[0]->reaction_uuid,
        model_uuid => $_[0]->model_uuid,
        compartmentIndex => $_[0]->compartmentIndex,
    }};
    $f->{model_compartment} = sub { return {
        uuid => $_[0]->uuid,
    }};
    $f->{biomass} = sub { return {
        uuid => $_[0]->uuid,
    }};
    $f->{biomass_compound} = sub { return {
        biomass_uuid => $_[0]->biomass_uuid, 
        compound_uuid => $_[0]->compound_uuid, 
        model_compartment_uuid => $_[0]->model_compartment_uuid, 
    }};
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
        my $uuid = $self->uuidCache("compound", $row->{COMPOUND}->[0]);
        return undef unless($uuid);
        return {
            type => $row->{type}->[0],
            alias => $row->{alias}->[0],
            compound_uuid => $uuid,
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
            return undef;
        }
        my $cmp = $self->determinePrimaryCompartment($parts);
        my $cmp_uuid = $self->uuidCache("compartment", $cmp);
        unless($cmp_uuid) {
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
            compartment_uuid => $cmp_uuid,
        };
    };
    $f->{reaction_alias} = sub {
        my ($self, $row, $ctx) = @_;
        my $uuid = $self->uuidCache("reaction", $row->{REACTION}->[0]);
        return undef unless($uuid);
        return {
            type => $row->{type}->[0],
            alias => $row->{alias}->[0],
            reaction_uuid => $uuid,
        };
    };
    $f->{reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction", $row->{reaction}->[0]);
        my $cpd = $self->uuidCache("compound", $row->{compound}->[0]);
        unless(defined($rxn) && defined($cpd)) {
            return undef;
        }
        return {
            reaction_uuid => $rxn,
            compound_uuid => $cpd,
            coefficient => $row->{coefficient}->[0],
            cofactor => $row->{cofactor}->[0] || undef,
            compartmentIndex => $row->{compartmentIndex}->[0],
        };
    };    
    $f->{default_transported_reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction", $row->{reaction}->[0]);
        my $cpd = $self->uuidCache("compound", $row->{compound}->[0]);
        my $cmp = $self->uuidCache("compartment", $row->{compartment}->[0]);
        unless(defined($rxn) && defined($cmp) && defined($cpd)) {
            my $str = (!defined($rxn)) ? "no reaction\n" : 
                      (!defined($cpd)) ? "no cpd\n" : "no compartment\n";
            warn $str;
            return undef;
        }
        return {
            reaction_uuid => $rxn,
            compound_uuid => $cpd,
            compartment_uuid => $cmp,
            compartmentIndex => $row->{compartmentIndex}->[0],
            transportCoefficient => $row->{transportCoefficient}->[0],
            isImport => $row->{isImport}->[0],
        };
    };
    $f->{role} = sub {
        my ($self, $row, $ctx) = @_;
        return {
            id => $row->{id}->[0] || undef,
            name => $row->{name}->[0] || undef,
            exemplar => $row->{exemplar}->[0] || undef,
            modDate => $date->($row),
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
        my $complex = $self->uuidCache("complex", $row->{COMPLEX}->[0]);
        my $role    = $self->uuidCache("role", $row->{ROLE}->[0]);
        if(defined($role) && defined($complex)) {
            return { 
                complex_uuid => $complex,
                role_uuid => $role,
                type => $row->{type}->[0] || '',
            };
        } else {
            return undef;
        }
    };

    $f->{reactionRule} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn_uuid = $self->uuidCache("reaction", $row->{REACTION}->[0]);
        my $rxn = $self->om->get_object("reaction", { uuid => $rxn_uuid});
        return undef unless(defined($rxn));
        my $cmp = $rxn->defaultCompartment;
        return undef unless(defined($cmp));
        return {
            reaction_uuid => $rxn_uuid,
            compartment_uuid => $cmp->uuid,
            direction => "=",
        };
    };
    $f->{feature} = sub {
        my ($self, $row, $ctx) = @_;
        my $genome = $self->uuidCache("genome", $row->{GENOME}->[0]);
        return undef unless(defined($genome));
        my $min = $row->{"MIN LOCATION"}->[0];
        my $max = $row->{"MAX LOCATION"}->[0];
        my $start = ($row->{DIRECTION}->[0] eq 'for') ? $min : $max;
        my $stop  = ($row->{DIRECTION}->[0] eq 'for') ? $max : $min;
        return {
            start => $start,
            stop  => $stop,
            id => $row->{ID}->[0],
            genome_uuid => $genome,
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
    $f->{model_reaction} = sub {
        my ($self, $row, $ctx) = @_;
        my $reaction = $self->uuidCache("reaction", $row->{REACTION}->[0]);
        my $codes = { directionality => ''};
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
        # compartment is actually a model_compartment object
        return {
            reaction_uuid => $reaction,
            direction => $codes->{directionality} || '=',
            model_compartment => $row->{compartment}->[0],
        };
    };
    $f->{model_transported_reagent} = sub {
        my ($self, $row, $ctx) = @_;
        my $rxn = $self->uuidCache("reaction", $row->{reaction}->[0]);
        my $cpd = $self->uuidCache("compound", $row->{compound}->[0]);
        my $cmp = $self->uuidCache("model_compartment", $row->{model_compartment}->[0]);
        unless(defined($rxn) && defined($cmp) && defined($cpd)) {
            my $str = (!defined($rxn)) ? "no reaction\n" : 
                      (!defined($cpd)) ? "no cpd\n" : "no compartment\n";
            warn $str;
            return undef;
        }
        return {
            reaction_uuid => $rxn,
            compound_uuid => $cpd,
            model_compartment_uuid => $cmp,
            compartmentIndex => $row->{compartmentIndex}->[0],
            transportCoefficient => $row->{transportCoefficient}->[0],
            isImport => $row->{isImport}->[0],
        };
    };
    $f->{biomass_compound} = sub {
        my ($self, $row) = @_;
        my $compound    = $self->uuidCache("compound", $row->{compound}->[0]);
        my $compartment = $self->uuidCache("model_compartment", $row->{compartment}->[0]);
        return {
            model_compartment_uuid => $compartment,
            compound_uuid => $compound,
            coefficient => $row->{coefficient}->[0],
        };
    };
    return $f;
} 
        
    

sub importBiochemistryFromDir {
    my ($self, $dir, $username, $name) = @_;
    my $missed = {};
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
    foreach my $file (values %$files) {
        $file = "$dir/$file";
        unless(-f "$file") {
            warn "Unable to find $file!";
            return undef;
        }
    }
    my $tables = { %$files };
    elapsed();
    # Skip all processing if we've seen the data
    my $existingBiochem = $self->fileCache("biochemistry", [values %$files]);
    if($existingBiochem) {
        $existingBiochem->add_biochemistry_aliases(
            { username => $username, id => $name});
        $existingBiochem->save();
        $self->om->db->commit;
        $self->checker->check("Imported biochemistry $username/$name [filehash] ", elapsed(), $missed);
        return $existingBiochem;
    }
    my $config = { filename => undef, delimiter => "\t"};
    foreach my $key (keys %$tables) {
        # now open tables as FIGMODELTables
        $config->{filename} = $tables->{$key};
        $tables->{$key} = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    # Now create biochemistry object
    my $RDB_biochemistry = $self->om->create_object('biochemistry');
    # Create compartments - for reactions, default_transported_reagents
    my $compartments = $self->getDefaultCompartments();
    $RDB_biochemistry->add_compartments(@$compartments);
    # Compounds
    for(my $i=0; $i<$tables->{compound}->size(); $i++) {
        my $row = $tables->{compound}->get_row($i);
        my $hash = $self->convert("compound", $row);
        my $RDB_compound = $self->getOrCreateObject("compound", $hash); 
        $RDB_biochemistry->add_compounds($RDB_compound); 
        if(!defined($hash) || !defined($RDB_compound)) {
            push(@{$missed->{compound}}, $row->{id}->[0]);
        }
    }
    # CompoundAliases
    my $aliasRepeats = {};
    for(my $i=0; $i<$tables->{compound_alias}->size(); $i++) {
        my $row = $tables->{compound_alias}->get_row($i);
        my $hash = $self->convert("compound_alias", $row);
        my $error;
        ($error, $aliasRepeats) = checkAliases($aliasRepeats, $hash, "compound") if(defined($hash));
        if(!defined($hash) || $error) {
            push(@{$missed->{compound_alias}}, $row->{COMPOUND}->[0].":".$row->{type}->[0]);
            next;
        }
        my $RDB_compound_alias =
            $self->getOrCreateObject("compound_alias", $hash);
    }
    # Reactions
    for(my $i=0; $i<$tables->{reaction}->size(); $i++) {
        my $row = $tables->{reaction}->get_row($i);
        my $hash = $self->convert("reaction", $row);
        unless(defined($hash)) {
            push(@{$missed->{reaction}}, $row->{id}->[0]);
            next;
        }
        my $RDB_reaction = $self->getOrCreateObject("reaction", $hash);
        $RDB_biochemistry->add_reactions($RDB_reaction);
        # Reagents and DefaultTransportedReagents
        my $data = $self->generateReactionDataset($row, $missed);
        foreach my $reagent (@{$data->{reagents}}) {
            next if(!defined($reagent));
            my $RDB_reagent = $self->getOrCreateObject("reagent", $reagent);
        }
        foreach my $rt (@{$data->{default_transported_reagents}}) {
            next if(!defined($rt));
            my $RDB_rt = $self->getOrCreateObject("default_transported_reagent", $rt);
        }
            
    }
    # ReactionAlias
    $aliasRepeats = {};
    for(my $i=0; $i<$tables->{reaction_alias}->size(); $i++) {
        my $row = $tables->{reaction_alias}->get_row($i);
        my $hash = $self->convert('reaction_alias', $row);
        next if(!defined($hash) || $hash->{type} eq "name" || $hash->{type} eq "searchname");
        my $error;
        ($error, $aliasRepeats) = checkAliases($aliasRepeats, $hash, "reaction") if(defined($hash));
        if(!defined($hash) || $error) {
            push(@{$missed->{reaction_aliases}}, $row->{REACTION}->[0].":".$row->{type}->[0]); 
            next;
        }
        my $RDB_reaction_alias =
            $self->getOrCreateObject("reaction_alias", $hash);
    }
    # Media
    my $defaultMediaObjs = $self->getDefaultMedia(); 
    foreach my $obj (@$defaultMediaObjs) {
        $RDB_biochemistry->add_media($obj);
    }
    # Now create if it doesn't already exist
    my $biochem_hash = $self->hash("biochemistry", $RDB_biochemistry);
    my $bio = $self->cache("biochemistry", $biochem_hash, $RDB_biochemistry);
    $self->checker->check("Imported biochemistry $username/$name [complete] ", elapsed(), $missed);
    # Add alias that we wanted
    $self->fileCache("biochemistry", [values %$files], $biochem_hash);
    $bio->add_biochemistry_aliases({ username => $username, id => $name});
    # TODO - check if we've added this already, lock if not already locked
    $bio->save();
    $self->om->db->commit;
    return $bio;
}
    
    

sub importMappingFromDir {
    my ($self, $dir, $RDB_biochemObject, $username, $name) = @_;
    my $missed = {};
    # first validate that the dir exists and has the right files
    $self->om->db->begin_work;
    my $ctx = $self->cache;
    unless(-d $dir) {
        $self->logger->log("Unable to find $dir\n");
        $self->om->db->commit;
        return undef;
    }
    $dir = $self->standardizeDirectory($dir);
    my $files = {complex => 'complex.txt',
                 role => 'role.txt',
                 complexRole => 'cpxrole.txt',
                 reactionRule => 'rxncpx.txt'};
    map { $files->{$_} = "$dir/".$files->{$_} } keys %$files;
    my $tables = { %$files };
    elapsed();
    # Skip all processing if we've seen the data
    my $existingMap = $self->fileCache("mapping", [values %$files]);
    if($existingMap) {
        $existingMap->add_mapping_aliases(
            { username => $username, id => $name});
        $existingMap->save();
        $self->om->db->commit;
        $self->checker->check("Imported Mapping $username/$name [filehash] ", elapsed(), $missed);
        return $existingMap;
    }
    my $config = {filename => undef, delimiter => "\t"};
    foreach my $file (values %$tables) {
        if($file =~ "role.txt" && !-f $file) {
            $config->{filename} = $file;
            my $objs = $self->fm->database->get_objects("role");
            my $tbl = $self->fm->database->ppo_rows_to_table($config, $objs);
            $tbl->save();
        }
        # now open files as FIGMODELTables
        $config->{filename} = $file;
        $file = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    # Now create mapping object
    my $RDB_mappingObject = $self->om()->create_object('mapping');
    $RDB_mappingObject->biochemistry($RDB_biochemObject);
    # Create complexes
    for(my $i=0; $i<$tables->{complex}->size(); $i++) {
        my $row = $tables->{complex}->get_row($i);
        my $hash = $self->convert("complex", $row);
        my $RDB_complexObject = $self->getOrCreateObject('complex', $hash);
        $RDB_mappingObject->add_complexes($RDB_complexObject);
    } 
    # Create roles 
    for(my $i=0; $i<$tables->{role}->size(); $i++) {
        my $row = $tables->{role}->get_row($i);
        my $hash = $self->convert("role", $row);
        my $RDB_roleObject = $self->getOrCreateObject('role', $hash);
        $RDB_mappingObject->add_roles($RDB_roleObject);
        # have to cache roles by names for annotation
        my $cksum = $self->hash("role", $RDB_roleObject);
        $self->idCache("role", $RDB_roleObject->name, $cksum); 
    } 
    # Create complexRole
    my $cpxRoleFailures = 0;
    for(my $i=0; $i<$tables->{complexRole}->size(); $i++) {
        my $row = $tables->{complexRole}->get_row($i);
        my $hash = $self->convert("complexRole", $row);
        if(!defined($hash)) {
            push(@{$missed->{complexRole}},
                $row->{COMPLEX}->[0].":".$row->{ROLE}->[0]);
            next;
        }
        my $RDB_complexRoleObject = $self->getOrCreateObject('complex_role', $hash);
        $RDB_complexRoleObject->save();
    }
    $RDB_mappingObject->add_mapping_aliases({username => $username, id => $name});
    # Create reactionRule 
    for(my $i=0; $i<$tables->{reactionRule}->size(); $i++) {
        my $row = $tables->{reactionRule}->get_row($i);
        my $hash = $self->convert("reactionRule", $row);
        my $cpx_uuid  = $self->uuidCache("complex", $row->{COMPLEX}->[0]);
        my $cpx = $self->om->get_object("complex", { uuid => $cpx_uuid});
        unless(defined($cpx) && defined($hash) ) {
            push(@{$missed->{reactionRule}}, $row->{COMPLEX}->[0].":".$row->{REACTION}->[0]);
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
    $self->fileCache("mapping", [values %$files], $mapping_hash);
    my $map = $self->cache("mapping", $mapping_hash, $RDB_mappingObject);
    $self->checker->check("Imported mapping $username/$name [complete] ", elapsed(), $missed);
    # Add alias that we wanted
    $map->add_mapping_aliases({ username => $username, id => $name});
    # TODO - check if we've added this already, lock if not already locked
    $map->save();
    $self->om->db->commit;
    return $map; 
}

sub getGenomeObject {
    my ($self, $genomeID) = @_;
    unless(defined($self->idCache("genome", $genomeID))) {
        my $columns = [ 'dna-size', 'gc-content', 'pegs', 'name', 'taxonomy', 'md5_hex' ]; 
        my $genomeData = $self->sap->genome_data({
            -ids => [ $genomeID ],
            -data => $columns,
        });
        unless(defined($genomeData)) {
            warn "Unable to get genome data from SAPserver!\n";
            return undef;
        }
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
    return $self->idCache("genome", $genomeID);
}

sub importAnnotationFromDir {
    my ($self, $dir, $username, $id) = @_;
    my $missed = {};
    $self->om->db->begin_work;
    elapsed();
    # Directory will contain a features.txt file
    my $file = "$dir/features.txt";
    # Try to get from file-hash
    my $existingAnno = $self->fileCache("annotation", [$file]);
    if($existingAnno) {
        $existingAnno->add_mapping_aliases(
            { username => $username, id => $id});
        $existingAnno->save();
        $self->om->db->commit;
        $self->checker->check("Imported Annotation $username/$id [filehash] ", elapsed(), $missed);
        return $existingAnno;
    }
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
            push(@{$missed->{genome}}, $row->{GENOME}->[0]);
            $self->om->db->commit;
            $self->checker->check("Failed to import annotation for $username/$id ", elapsed(), $missed);
            return undef;
        }
        unless(defined($RDB_annotation)) {
            $RDB_annotation = $self->om->create_object("annotation", { genome => $RDB_genome });
        }
        my $hash = $self->convert("feature", $row); 
        my $RDB_feature = $self->getOrCreateObject("feature", $hash) if(defined($hash));
        unless(defined($hash) && defined($RDB_feature)) {
            push(@{$missed->{feature}}, $row->{ID}->[0]); 
            next;
        }
        foreach my $roleName (@{$row->{ROLES}}) {
            my $RDB_role = $self->idCache("role", $roleName);
            if(!defined($RDB_role)) {
                my $role_hash = $self->convert("role", { name => [ $roleName ] });
                $RDB_role = $self->getOrCreateObject("role", $role_hash);
                my $role_cksum = $self->hash("role", $RDB_role);
                $self->idCache("role", $RDB_role->name, $role_cksum);
            }
            if(!defined($RDB_role)) {
                push(@{$missed->{role}}, $roleName);
                next;
            }
            my $annotation_feature = $self->getOrCreateObject(
                "annotation_feature", { 
                    annotation => $RDB_annotation,
                    role => $RDB_role,
                    feature => $RDB_feature,
            });
        }
    }
    # Now create if it doesn't already exist
    my $annotation_hash = $self->hash("annotation", $RDB_annotation);
    $self->fileCache("annotation", [$file], $annotation_hash);
    my $final = $self->cache("annotation", $annotation_hash, $RDB_annotation);
    $self->checker->check("Imported annotation $username/$id [complete] ", elapsed(), $missed);
    $self->om->db->commit;
    return $final;
}

sub importModelFromDir {
    my ($self, $dir, $username, $id) = @_;
    my $missed = {};
    my $RDB_model = $self->om->create_object("model", {id => $id, name => $id});
    my ($RDB_annotation, $RDB_biochemistry, $RDB_mapping);
    if(-d "$dir/biochemistry") {
        my $biochemId = $id . "-biochemistry";
        $RDB_biochemistry = $self->importBiochemistryFromDir(
            "$dir/biochemistry", $username, $biochemId);
        $RDB_model->biochemistry($RDB_biochemistry);
    } else {
        die "No biochemistry for model $dir!\n";
    }
    if(-d "$dir/mapping") {
        my $mappingId = $id . "-mapping";
        $RDB_mapping = $self->importMappingFromDir(
            "$dir/mapping", $RDB_biochemistry, $username, $mappingId);
        $RDB_model->mapping($RDB_mapping);
    } else {
        push(@{$missed->{mapping}}, "$id-file-missing");
    }
    if(-d "$dir/annotations") {
        my $genomeId = $id . "-annotation";
        $RDB_annotation = $self->importAnnotationFromDir(
            "$dir/annotations", $username, $genomeId);
        if(defined($RDB_annotation)) {
            $RDB_model->annotation($RDB_annotation);
        } else {
            push(@{$missed->{annotations}}, "$id-with-file");
        }
    } else {
            push(@{$missed->{annotations}}, "$id-file-missing");
    }
    warn "done annotations\n";
    # do rxnmdl
    $self->om->db->begin_work;
    my $file = "$dir/rxnmdl.txt";
    my $tbl;
    my $config = {
            delimiter => ";",
            itemDelimiter => "|",
            filename => $file,
    };
    if(!-f $file) { # generate rxn-mdl data from database
        die "could not find file $file!\n"; #FIXME
        my $objs = $self->fm->database->get_objects('rxnmdl', { MODEL => $id });        
        $tbl = $self->fm->database->ppo_rows_to_table($config, $objs);
    } else { # or load it from the file
        $tbl = ModelSEED::FIGMODEL::FIGMODELTable::load_table($config);
    }
    my $size = $tbl->size();
    my $biomassIds = [];
    for(my $i=0; $i<$size; $i++) {
        my $row = $tbl->get_row($i);
        # do model-compartments
        my $compartmentId = $row->{compartment}->[0];
        my $mdl_cmp = $self->idCache("model_compartment", $compartmentId); 
        if(!defined($mdl_cmp)) {
            $mdl_cmp = $self->makeModelCompartment($compartmentId, $RDB_biochemistry, $RDB_model);
        }
        # don't add biomass functions to reaction_model. Instead handle them separately.
        if(defined($row->{REACTION}->[0]) && $row->{REACTION}->[0] =~ m/bio\d+/) {
            warn "Got biomass: " . $row->{REACTION}->[0] . " for $id\n";
            push(@$biomassIds, $row->{REACTION}->[0]);
            next;
        }
        $row->{compartment}->[0] = $mdl_cmp;
        my $hash = $self->convert("model_reaction", $row);
        $hash->{model} = $RDB_model;
        my $RDB_model_reaction = $self->getOrCreateObject("model_reaction", $hash);
        # do model transported reagent
        my $dtrs = $RDB_model_reaction->reaction->default_transported_reagents;
        foreach my $dtr (@$dtrs) {
            my $cmp_id = $dtr->defaultCompartment->id;
            my $mdl_cmp = $self->idCache("model_compartment", $cmp_id);
            if(!defined($mdl_cmp)) {
                $mdl_cmp = $self->makeModelCompartment($cmp_id, $RDB_biochemistry, $RDB_model);
            }
            my $hash = {
                model => $RDB_model,
                reaction => $dtr->reaction,
                compound => $dtr->compound,
                model_compartment => $mdl_cmp,
                compartmentIndex => $dtr->compartmentIndex,
                transportCoefficient => $dtr->transportCoefficient,
                isImport => $dtr->isImport,
            };
            my $mtr = $self->getOrCreateObject("model_transported_reagent", $hash);
        }
    }
    my $rdb_biomasses = [];
    foreach my $biomassId (@$biomassIds) {
        my $biomass = $self->getBiomass($biomassId, $RDB_model);
        if(defined($biomass)) {
            push(@$rdb_biomasses, $biomass);
        } else {
            push(@{$missed->{biomass}}, $biomassId); 
        }
    }
    $RDB_model->biomasses($rdb_biomasses);
    my $model_hash = $self->hash("model", $RDB_model);
    # TODO - file hash for models
    $self->checker->check("Imported model $username/$id [complete] ", elapsed(), $missed);
    $self->om->db->commit;
    return $RDB_model;
}

sub makeModelCompartment {
    my ($self, $compartmentId, $RDB_biochemistry, $RDB_model) = @_;;
    my $compartment_uuid = $self->uuidCache("compartment", $compartmentId);
    my $hash = {
        compartment_uuid => $compartment_uuid,
        compartmentIndex => 0,
        model => $RDB_model,
    };
    my $obj = $self->getOrCreateObject("model_compartment", $hash);
    $hash = $self->hash("model_compartment", $obj);
    # need to use idCache on model_compartment to go from
    # compartment id => model_compartment
    $self->idCache("model_compartment", $compartmentId, $hash);
    return $obj;
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
                my $compound_uuid= $self->uuidCache("compound", $mediaCpd->entity());
                unless($compound_uuid) {
                    warn "Couldn't find compound " . $mediaCpd->entity() . "\n";
                    next;
                }
                my $hash = {
                    compound_uuid => $compound_uuid,
                    concentration => $mediaCpd->concentration(),
                    minflux => $mediaCpd->minFlux(),
                    maxflux => $mediaCpd->maxFlux(),
                };
                push(@$newMediaCpds, $hash);
            }
            $mediaObj->add_media_compounds(@$newMediaCpds);
            $mediaObj->save();
            push(@$media, $mediaObj);
        }
    }
    return $media;
}

sub getBiomass {
    my ($self, $biomassId, $RDB_model) = @_;
    my $oldBiomass = $self->fm->database->get_object("bof", { id => $biomassId });
    unless(defined($oldBiomass)) {
        warn "Could not find old biomass: $biomassId\n";
        return undef; 
    }
    my $oldBiomassCompounds = $self->fm->database->get_objects("cpdbof", { BIOMASS => $biomassId});
    unless(@$oldBiomassCompounds) {
        warn "Could not find old biomass compounds: $biomassId\n";
        return undef; 
    }
    my $biomassHash = {
        modDate => (defined $oldBiomass->modificationDate ) ?
            DateTime->from_epoch(epoch => $oldBiomass->modificationDate) : DateTime->now(),
        id => $oldBiomass->id,
        name => $oldBiomass->name || '',
    };
    my $biomassCompounds = [];
    foreach my $cpdbof (@$oldBiomassCompounds) {
        my $row = {
            compound => [ $cpdbof->COMPOUND ],
            coefficient => [ $cpdbof->coefficient ],
            compartment => [ $cpdbof->compartment ],
        };
        my $hash = $self->convert("biomass_compound", $row);
        push(@$biomassCompounds, $hash);
    }
    $biomassHash->{biomass_compounds} = $biomassCompounds;
    my $RDB_biomass = $self->getOrCreateObject("biomass", $biomassHash);
    return $RDB_biomass || undef;
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
        #$self->idCache($type, $secondKey, $val);
        $self->uuidCache($type, $secondKey, $obj->uuid);
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
    my ($self, $reactionRow, $missed) = @_;
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
                push(@{$missed->{default_transported_reagent}}, "$rxn:$cpd");
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
                push(@{$missed->{reagent}}, "$rxn:$cpd");
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
