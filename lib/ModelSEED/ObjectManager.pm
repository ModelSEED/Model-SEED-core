package ModelSEED::ObjectManager; 
use Moose;
use ModelSEED::DB;
use Try::Tiny;
use Data::Dumper;
use namespace::autoclean;
use Lingua::EN::Inflect qw(PL def_noun);

my $types = [ qw( Annotation AnnotationFeature Biochemistry
    BiochemistryAlias BiochemistryCompartment BiochemistryCompound
    BiochemistryCompoundset BiochemistryMedia BiochemistryReaction
    BiochemistryReactionset Biomass BiomassCompound Compartment Complex
    ComplexRole Compound CompoundAlias CompoundPk CompoundStructure
    Compoundset CompoundsetCompound DefaultTransportedReagent  Feature
    Genome Mapping MappingAlias MappingComplex MappingReactionRule
    MappingRole MappingRoleset Media MediaCompound Model ModelAlias ModelBiomass
    ModelCompartment ModelReaction ModelTransportedReagent ModelessFeature
    Modelfba ModelfbaCompound ModelfbaReaction Permission Reaction
    ReactionAlias ReactionRule ReactionRuleTransport Reagent Reactionset
    ReactionsetReaction Role Roleset RolesetRole
)];

# with 'ModelSEED::Role::ManagerRole' => { types => $types };

has db => ( is => 'rw', isa => 'ModelSEED::DB', builder => '_buildRDB', lazy => 1 );
has driver   => ( is => 'rw', isa => 'Str');
has database => ( is => 'rw', isa => 'Str');
has host => ( is => 'rw', isa => 'Str');
has username => ( is => 'rw', isa => 'Str');
has server_time_zone => ( is => 'rw', isa => 'Str', default => 'UTC' );
has types => ( is => 'rw', isa => 'HashRef', default => sub { return {map { $_ => '' } @$types}; });
has _managers => ( is => 'rw', isa => 'HashRef', default => sub { return {}; } );
has plurals => ( is => 'rw', isa => 'HashRef', builder => '_buildAllPluralObjects', lazy => 1);
has objectClasses => ( is => 'rw', isa => 'HashRef', lazy => 1,
    builder => '_buildObjectClassMap', traits => [ qw( Hash )],
    handles => { objectClass => 'accessor' });
has objectManagerClasses => ( is => 'rw', isa => 'HashRef', lazy => 1,
    builder => '_buildObjectManagerClassMap', traits => [ qw( Hash )],
    handles => { objectManagerClass => 'accessor' } );
has namingConventions => ( is => 'ro', isa => 'HashRef', lazy => 1,
    builder => '_defaultNamingConventions');

sub BUILD {
    my ($self) = @_;
    foreach my $type (keys %{$self->types}) {
        # attempt to convert names correctly
        $type =~ s/ModelSEED:://;
        $type =~ s/DB:://;
        my $name = $type;
        my $Rtype = "ModelSEED::DB::$type"."::Manager";
        my $Rtype_base = "ModelSEED::DB::$type";
        # require package names
        my $Rpkg = $Rtype;
        $Rpkg =~ s/::/\//g;
        $Rpkg .= ".pm";
        my $Rpkg_base = $Rtype_base;
        $Rpkg_base =~ s/::/\//g;
        $Rpkg_base .= ".pm";
        # convert type CamelCase into camel_case
        my $cc = $type;
        $cc =~ s/([A-Z])/_$1/g; # _Camel_Case
        $cc = lc($cc);         # _camel_case
        $cc =~ s/^_//;         # camel_case
        try {
            require $Rpkg; 
            require $Rpkg_base;
        } catch {
            die("Role::ManagerRole died on $type : $_");
        };
        # now create functions
        my $managerObj = {
            create_object => _create_object($Rtype_base),
            get_objects => _get_objects_wrapper($Rtype_base, $Rtype),
            get_objects_iterator => _get_objects_iterator_wrapper($Rtype_base, $Rtype),
            get_count => _other_wrappers($Rtype_base, $Rtype, "get_objects_count"),
            update_objects => _other_wrappers($Rtype_base, $Rtype, "update_objects"),
            delete_objects => _other_wrappers($Rtype_base, $Rtype, "delete_objects"),
        };
        my $tableName = $Rtype_base->meta->table;
        $self->_managers->{$tableName} = $managerObj;
        $self->_managers->{$cc} = $managerObj;
    }
}
    

sub _buildRDB {
    my $self = shift;
    my $params = {};
    foreach my $param (qw(driver database host username server_time_zone)) {
        $params->{$param} = $self->$param;
    }
    return ModelSEED::DB->new(%$params);
}

sub get_object {
    my $r = shift->get_objects(@_);
    return ($r > 0) ? $r->[0] : undef;
}

sub get_count {
    my $self = shift;
    my $type = shift;
    unshift(@_, $self);
    die "Unknown object $type\n" unless(defined($self->_managers->{$type}));
    die "Unknown method get_objects for $type\n" unless(
        defined($self->_managers->{$type}->{get_count}));
    return $self->_managers->{$type}->{get_count}->(@_);
}

sub get_object_by_alias {
    my ($self, $type, $user, $id) = @_;
    my $ptype = $self->plural($type);
    return $self->get_object($type, query =>
        [ $type."_aliases.username" => $user,
          $type."_aliases.id" => $id ], require_objects => [ $type."_aliases" ],
    );
}

sub get_objects {
    my $self = shift;
    my $type = shift;
    unshift(@_, $self);
    die "Unknown object $type\n" unless(defined($self->_managers->{$type}));
    die "Unknown method get_objects for $type\n" unless(
        defined($self->_managers->{$type}->{get_objects}));
    return $self->_managers->{$type}->{get_objects}->(@_);
}

sub create_object {
    my $self = shift;
    my $type = shift;
    unshift(@_, $self);
    die "Unknown object $type\n" unless(defined($self->_managers->{$type}));
    die "Unknown method create_object for $type\n" unless(
        defined($self->_managers->{$type}->{create_object}));
    return $self->_managers->{$type}->{create_object}->(@_);
}

sub new_object {
    my $self = shift @_;
    my $type = shift @_;
    my $args;
    if(ref($_[0]) eq 'HASH' && @_ == 1) {
        $args = shift @_;
    }
    my $class = $self->objectClass($type);
    return undef unless defined($class);
    return $class->new(%$args, db => $self->{db}, @_);
}
    

# MakePrimaryKeys - given an object type, and optionally a set
# of attribute values, return a hash of key => value where all keys
# are primary in that object type. If no attributes are provided,
# the returned hash will have 1 for attribute values.
sub getPrimaryKeys {
    my ($self, $type, $attrs) = @_;
    my $objectClass = $self->objectClass($type);
    return undef unless defined($objectClass);
    my $keys = $objectClass->meta->primary_key_column_names;
    my $rtv = { map { $_ => 1 } @$keys };
    foreach my $key (@$keys) {
        if(defined($attrs) && ref($attrs) eq 'HASH') {
            $rtv->{$key} = $attrs->{$key} if defined($attrs->{$key});
        } elsif(defined($attrs) && ref($attrs)) {
            $rtv->{$key} = $attrs->$key;
        }
    }
    return $rtv;
} 
    
sub _addDBObjectUnlessDefined {
    my $self = shift;
    # if we're getting a hash that does not contain the "db" key
    if(ref($_[0]) eq 'HASH' && !defined($_[0]->{db})) {
        $_[0]->{db} = $self->db;
    } elsif (ref($_[0]) ne 'HASH' && 0 == grep(/^db/, @_)) {
        # if we get an array that doesn't contain "db"
        push(@_, ( 'db', $self->db ));
    }
    return @_;
}

# Basic query syntax is:
# get_type({ key => 'value' })
# we convert this into:
# get_type({query => [ key => value ]})
sub _handleBasicQuerySyntax {
    my $self = shift;
    if(ref($_[0]) eq 'HASH' && !defined($_[0]->{query})) {
        return ( query => [%{$_[0]}] );
    } else {
        return (@_); 
    }
}

sub _create_object {
    my ($Rpkg) = @_;
    my $func = sub {
        my $self = shift;
        @_ = $self->_addDBObjectUnlessDefined(@_);
        if(ref($_[0]) eq 'HASH' && @_ == 1) {
            my $hash = shift @_;
            push(@_, %$hash);
        }
        return $Rpkg->new(@_);
    };
    return $func;
}
    

sub _get_objects_wrapper {
    my ($type, $Rpkg) = @_;    
    my $func = sub {
        my $self = shift;
        my @arr = (@_) ? @_ : ();
        @arr = $self->_handleBasicQuerySyntax(@arr);
        return $Rpkg->get_objects(@arr, object_class => $type, db => $self->db);
    }; 
    return $func;
}

sub _get_objects_iterator_wrapper {
    my ($type, $Rpkg, $Mpkg) = @_;
    my $func = sub {
        my $self = shift;
        @_ = $self->_handleBasicQuerySyntax(@_ || ());
        return $Rpkg->get_objects_iterator(@_, object_class => $type, db => $self->db);
    };
    return $func;
}

# get_objects_count, update_objects and delete_objects all
# have the same interface
sub _other_wrappers {
    my ($type, $Rpkg, $cmd) = @_;
    my $func = sub {
        my $self = shift;
        @_ = $self->_handleBasicQuerySyntax(@_);
        @_ = $self->_addDBObjectUnlessDefined(@_);
        return $Rpkg->$cmd(@_, object_clsss => $type, db => $self->db);
    };
    return $func;
}

sub _fixSyntax {
    my ($self, $args, $depth) = @_;
    if(!defined($depth) || $depth < 2) {
        if(ref($args) eq 'HASH') {
            return ( map { $_ => $self->_fixSyntax($args->{$_}, $depth+1) } keys %$args);
        } elsif(ref($args) eq 'ARRAY') {
            return ( map { $self->_fixSyntax($_, $depth+1) } @$args );
        }
    } else {
        return $args;
    }
}


sub singular {
    my ($self, $type) = @_;
    my $o = $self->plurals->{singles}->{$type};
    return ($o) ? $o : $type;
}

sub plural {
    my ($self, $type) = @_;
    my $o = $self->plurals->{plurals}->{$type};
    return ($o) ? $o : $type;
}

sub _buildAllPluralObjects {
    my ($self) = @_;
    my @types = keys %{$self->types};
    my ($singles, $plurals) = ({}, {});
    # Add important defaults for us
    def_noun 'media' => 'media';
    def_noun 'fba' => 'fba';
    def_noun 'alias' => 'aliases';
    foreach my $type (@types) {
        # CamelCase to under_score
        $type =~ s/([A-Z])/_$1/g;
        $type =~ s/^_//;
        # split on under_scores
        my @parts = split(/_/, $type);
        map { $_ = lc($_) } @parts;
        # convert last part to plural form
        my $last = scalar(@parts) - 1;
        my @plParts = @parts;
        $plParts[$last] = PL($plParts[$last]);
        my ($pl, $s) = (join("_", @plParts), join("_", @parts));
        # add bidirectional links in hash
        $plurals->{$s} = $pl;
        $singles->{$pl} = $s;
    }
    my $hash = { plurals => $plurals, singles => $singles };
    return $hash;
}

sub _buildObjectClassMap {
    my ($self) = @_;
    my $map = $self->_objectMapHelper("ModelSEED::DB::");
    return $self->objectClasses($map);
}

sub _buildObjectManagerClassMap {
    my ($self) = @_;
    my $map = $self->_objectMapHelper("ModelSEED::DB::", "::Manager");
    return $self->objectManagerClasses($map);
}

sub _objectMapHelper {
    my ($self, $classPrefix, $classSuffix) = @_;
    $classPrefix = '' unless defined $classPrefix;
    $classSuffix = '' unless defined $classSuffix;
    my $map = {};
    while( my ($class, $names) = each %{$self->namingConventions}) {
        my $real_class = $classPrefix.$class.$classSuffix;
        foreach my $name (@$names) {
            $map->{$name} = $real_class;
        }
    }
    return $map;
}
    
# The default naming conventions are
# ObjectClass => [ object_name, ObjectClass ],
sub _defaultNamingConventions {
    my ($self) = @_;
    my $nameMap = {};
    foreach my $type (@$types) {
        my $cc = $type; 
        $cc =~ s/([A-Z])/_$1/g; # _Camel_Case
        $cc = lc($cc);         # _camel_case
        $cc =~ s/^_//;         # camel_case
        $nameMap->{$type} = [ $type, $cc ];
    }
    return $nameMap; 
}

    
__PACKAGE__->meta->make_immutable;
1;
