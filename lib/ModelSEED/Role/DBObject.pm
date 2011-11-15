package ModelSEED::Role::DBObject;

use MooseX::Role::Parameterized;
use Moose::Util::TypeConstraints;
use Rose::DB::Object;
use Scalar::Util;
use Data::Dumper;

use ModelSEED::Role::DoNotStore;

parameter 'type' => ( isa => 'Str', required => 1 );

role {

    has '_rdbo' => (
        is => 'rw', isa => 'RoseDBObject', lazy => 1, builder => '_buildRDBO',
        handles => [ qw( db dbh delete DESTROY error init_db _init_db insert
            load not_found save update) ],
        traits => [ 'DoNotStore' ],
    );

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    if(@_ == 1 && ref($_[0]) && blessed $_[0] &&
       $_[0]->can('isa') && $_[0]->isa('Rose::DB::Object')) {
        return $class->$orig({_rdbo => $_[0]});
    } else {
        return $class->$orig(@_);
    }
};

# Construct Rose::DB::Object if not provided
sub _buildRDBO {
    my $self = shift;
    my $obj = ref($self);
    $obj =~ s/ModelSEED:://;
    eval { 
        require "ModelSEED/DB/$obj.pm";
    };
    if($@) {
        die $@;
    }
    return "ModelSEED::DB::$obj"->new();
}

sub asStorableHash {
    my ($self) = shift @_;
    my $hash = {};
    foreach my $attribute ( map { $self->meta->get_attribute($_) }
        sort $self->meta->get_attribute_list ) {
        if($attribute->does('ModelSEED::Role::DoNotStore')) {
        } elsif($attribute->does('ModelSEED::Role::RelationshipTrait')) {
        } else {
            my $name = $attribute->name;
            $hash->{$name} = $self->$name;
        }
    }
    return $hash;
}


# copy attributes from moose class to rose class
before ['insert', 'save'] => sub {
    my $self = shift @_;
    my $hash = $self->asStorableHash();
    foreach my $attr (keys %$hash) {
        $self->_rdbo->$attr($hash->{$attr});
    }
};

before ['load'] => sub {
    my $self = shift @_;
    my $hash = $self->asStorableHash();
    foreach my $attr (keys %$hash) {
        $self->_rdbo->$attr($hash->{$attr});
    }
};
    

# copy attributes from rose class to moose class 
after ['load'] => sub {
    my $self = shift @_;
    my $hash = $self->asStorableHash();
    foreach my $attr (keys %$hash) {
        $self->$attr($self->_rdbo->$attr);
    }
};

1;
