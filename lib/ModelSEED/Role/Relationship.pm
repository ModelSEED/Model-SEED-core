package ModelSEED::Role::Relationship;
use Moose::Util::TypeConstraints;
use MooseX::Role::Parameterized;
use ModelSEED::Role::RelationshipTrait;

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
    my $roseClass = ($rel->type =~ 'many to many') ?
        $rel->map_class : $rel->class;
    my $mooseClass = $roseClass;
    $mooseClass =~ s/::DB//;
    {
        my $moose_class_path = $mooseClass;
        $moose_class_path =~ s/::/\//g;
        eval {
            require "$moose_class_path.pm"
        };
        if($@) {
            die($@);
        }
    }
    my $mooseIsaType = $mooseClass;
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
                push(@$objs, $mooseClass->new($obj));
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
            $obj = $mooseClass->new($obj);
        } 
        if($obj->isa($mooseClass)) {
            $obj->save();
            return $obj->_rdbo;
        } elsif($obj->isa($roseClass)) {
            return $obj;
        } else {
            die("Could not save object of type ".ref($obj));
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
