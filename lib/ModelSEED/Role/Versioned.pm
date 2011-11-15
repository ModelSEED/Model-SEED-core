package ModelSEED::Role::Versioned;

use Moose::Role;
use Moose::Util::TypeConstraints;
use MooseX::Role::Parameterized;

requires 'uuid';

parameter type => (
    isa => 'Str',
    required => 1,
);

role {
    my $p = shift;
    my $type = $p->type;

    has locked => (
        is => 'rw', isa => 'Bool', default => 0,
    );
    
    has parents => (
        is => 'rw', isa => $type,
        lazy => 1, _builder => '_getParents'
    );

    sub _getParents {
        my ($self) = @_;
        return map { $type->new($_) } @{$self->_rdbo->parents};
    }
    
    # Fork protocol:
    # all attributes are copied into new object,
    # parent is set to old object, a new uuid is issued.
    # all one-to-many and many-to-many relationships are copied
    # with the new uuid
    method fork => sub {};
    
    # Copy Protocol
    # if object is not editable, fork()
    # if object is editable:
    # all attributes are copied into a new object,
    # parent is set to old-object parent, a new uuid is issued
    # all one-to-many and many-to-many relationships are copied
    # with the new uuid
    method copy => sub {};
    
    # Lock Protocol
    # lock() is called on the object,
    # editable attribute set to false
    # for all one-to-one, one-to-many and many-to-many relationships,
    # lockedCopy() is called on these objects
    method lock => sub {};
    
    # LockedCopy protocol:
    # call copy() on object
    # call lock() on object copy
    methpd lockedCopy => sub {
        my $self = shift @_;
        my $cpy = $self->copy();
        return $cpy->lock();
    };

};

1;
