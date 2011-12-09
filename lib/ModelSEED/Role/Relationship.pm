package ModelSEED::Role::Relationship;
use Moose::Util::TypeConstraints;
use MooseX::Role::Parameterized;
use ModelSEED::Role::RelationshipTrait;
use Data::Dumper;

subtype 'RoseDBRelationship', as 'Object',
    where { $_->isa('Rose::DB::Object::Metadata::Relationship') };
    
parameter 'relationship'  => (
    isa => 'RoseDBRelationship',
    required => 1,
);

parameter 'attributeName' => (
    isa => 'Str',
);


role {
    my $p = shift;
    my $rel = $p->relationship;
    # 1. Create attribute parameter
    #    has () with lazy builder
    my ($roseClass, $mooseClass,
       $roseObjectClass, $mooseObjectClass);
    if($rel->type =~ 'many to many') {
        $roseClass = $rel->map_class;
        $roseObjectClass = ($rel->foreign_class) ?
            $rel->foreign_class : $roseClass;    
    } else {
        $roseClass = $rel->class;
        $roseObjectClass = $roseClass;
    }
    $mooseClass = $roseClass;
    $mooseClass =~ s/::DB//;
    $mooseObjectClass = $roseObjectClass;
    $mooseObjectClass =~ s/::DB//;
    foreach my $class ($mooseClass, $mooseObjectClass) {
        my $class_path = $class;
        $class_path =~ s/::/\//g;
        eval {
            require "$class_path.pm"
        };
        if($@) {
            die($@);
        }
    }
    my $mooseIsaType = $mooseObjectClass;
    my $attributeName = (defined($p->attributeName)) ?
        $p->attributeName : $rel->name;
    my $builderName = '_build'.$attributeName;
    my $builder;
    if($rel->type =~ 'to many') {
        # If we have many of them need an ArrayRef
        $mooseIsaType = 'ArrayRef['.$mooseIsaType.']';
        $builder = sub {
            my $self = shift @_;
            my $objs = [];
            foreach my $obj (@{$self->_rdbo->$attributeName || []}) {
                push(@$objs, $mooseObjectClass->new($obj));
            }
            return $objs;
        };
    } else {
        $builder = sub {
            my $self = shift @_;
            if(defined($self->_rdbo->$attributeName)) {
                return $mooseClass->new($self->_rdbo->$attributeName);
            } else {
                return undef; 
            }
        };
    }
    method $builderName => $builder;
    has $attributeName => ( is => 'rw', isa => 'Maybe['.$mooseIsaType.']',
        lazy => 1, builder => $builderName, traits => ['DoNotStore']);
    # 2. Add before save() hook
    my $forOneSaveHook = sub {
        my ($self, $obj) = @_;
        return unless(defined($obj));
        if(ref($obj) eq 'HASH') { # NEED?
            $obj = $mooseObjectClass->new($obj);
        } 
        if($obj->isa($mooseObjectClass)) {
            $obj->save();
            return $obj->_rdbo;
        } elsif($obj->isa($roseClass)) {
            return $obj;
        } elsif($obj->isa($rel->foreign_class)) {
            
        } else {
            die("Could not save object of type ".ref($obj) . " expecting something like $mooseObjectClass");
        }
    };
    if($rel->type =~ 'to many') {
        before 'save' => sub {
            my $self = shift @_;
            my $objs = [];
            foreach my $obj (@{$self->$attributeName}) {
                push(@$objs, $forOneSaveHook->($self, $obj));
            }
            $self->_rdbo->$attributeName($objs);
        };
    } else {
        before 'save' => sub {
            my $self = shift @_;
            my $obj = $self->$attributeName;
            return unless(defined($obj));
            $self->_rdbo->$attributeName($forOneSaveHook->($self, $obj));
        };
    }
};

1;
