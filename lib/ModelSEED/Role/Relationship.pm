package ModelSEED::Role::Relationship;

#use Moose::Role;
use MooseX::Role::Parameterized;
use ModelSEED::Role::RelationshipTrait;

parameter role_type => (
    isa => 'Str',
    required => 1,
); 

parameter object_type => (
    isa => 'Str',
    required => 1,
);

parameter object_name => (
    isa => 'Str',
);

role {
    my $p = shift;
    my $objName;
    if(defined($p->object_name)) {
        $objName = $p->object_name;
    } else { 
        $objName = $p->object_type;
        $objName =~ s/ModelSEED:://;
        $objName = lc($objName);
    }
    my $objType = $p->object_type;
    my $objAttrType = $objType;
    if($p->role_type eq 'many to many' ||
       $p->role_type eq 'one to many') {
        $objAttrType = 'ArrayRef[' . $objType . ']';
        method "_build$objName" => sub {
            my $self = shift @_;
            my $objs = [];
            foreach my $rdbObj (@{$self->_rdbo->$objName}) {
                push(@$objs, $objType->new($rdbObj));
            }
            return $objs;
        };
        my $addMethod = "add_$objName";
        method $addMethod => sub {
            my ($self, $obj) = @_;
            if(ref($obj) eq 'ARRAY') {
                map { $self->$addMethod($_) } @$obj;
            } elsif (ref($obj) ne $objType) {
                $obj = $objType->new($obj); 
            }   
            push(@{$self->$objName}, $obj);
        };
    } else {
        method "_build$objName" => sub {
            my $self = shift @_;
            return $self->_rdbo->$objName || undef;
        };
    }
    has $objName => ( is => 'rw', isa => $objType, lazy => 1,
        builder => "_build$objName",
        traits => ['RelationshipTrait'] );
};

1;
