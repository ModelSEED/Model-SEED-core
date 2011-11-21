package ModelSEED::Role::DBObject;
use MooseX::Role::Parameterized;
use Moose::Util::TypeConstraints;
use Scalar::Util;
use ModelSEED::Role::DoNotStore;

parameter 'rose_class' => ( isa => 'Str', required => 1 );
# This is a hash of string => Role object where string
# is an attribute name
parameter 'attribute_roles' => ( isa => 'HashRef', default => sub { return {}; });


role {
    my $p = shift;
    # Use consumer class name as default rose_class
    my $rose_class = $p->rose_class;
    {
        my $rose_class_path = $rose_class;
        $rose_class_path =~ s/::/\//g;
        eval {
            require "$rose_class_path.pm"
        };
        if($@) {
            die($@);
        }
    }
    # Create attribute _rdbo that contains rose object 
    has '_rdbo' => (
        is => 'rw', isa => $rose_class, lazy => 1, builder => '_buildRDBO',
        handles => [ qw( db dbh delete DESTROY error init_db _init_db
            insert load not_found save update) ],
        traits => [ 'DoNotStore' ],
    );
    # Construct Rose::DB::Object if not provided
    my $_buildRDBO = sub {
        my $self = shift;
        return $rose_class->new();
    };
    method '_buildRDBO' => $_buildRDBO;
    # Allow builder to accept rose_class object
    around BUILDARGS => sub {
        my $orig = shift;
        my $class = shift;
        if(@_ == 1 && ref($_[0]) eq $rose_class) { 
            return $class->$orig({_rdbo => $_[0]});
        } else {
            return $class->$orig(@_);
        }
    };
    # Before insert, save, load, copy data from class to _rdbo
    my $pushAttributesDown = sub {
        my $self = shift;
        my $obj = [];
        foreach my $attr ($self->meta->get_all_attributes) {
            unless($attr->does('DoNotStore')) {
                my $name = $attr->name;
                $self->_rdbo->$name($self->$name);
            }
        }
    };
    before insert => $pushAttributesDown;
    before load   => $pushAttributesDown;
    before save   => $pushAttributesDown;
    # After load, copy data over from _rdbo
    my $popAttributesUp = sub {
        my $self = shift;
        my $obj = [];
        foreach my $attr ($self->meta->get_all_attributes) {
            unless($attr->does('DoNotStore')) {
                my $name = $attr->name;
                $self->$name($self->_rdbo->$name);
            }
        }
    };
    after load => $popAttributesUp;
    # Add roles for each relationship
    # ( We heard you liked roles so we added roles to your roles! )
    my $roles = []; 
    foreach my $rel (@{$rose_class->meta->relationships}) {
        push(@$roles, 'ModelSEED::Role::Relationship' => {
           relationship => $rel }); 
    }
    # Add attributes that didn't get hit with roles
    foreach my $col ($rose_class->meta->columns) {
        my $name = $col->name;
        if(defined($p->attribute_roles->{$name})) {
            push(@$roles, $p->attribute_roles->{$name}); 
        } else {
            my $required = ($col->not_null) ? 1 : 0;
            my $type = _getType($col, $rose_class);
            has $name => ( is => 'rw', isa => $type );
        }
    }
    # Apply roles now
    with @$roles;
};

sub _getType {
    my ($col, $class) = @_;
    my ($type, $length);
    if($col->type eq 'scalar') {
        $type = 'Num';
    } elsif ($col->type eq 'varchar') {
        $length = $col->length;
        $type = "Str$length";
        subtype $type, as "Str", where { length($_) <= $length };
    } elsif ($col->type eq 'character') {
        $length = $col->length;
        $type = "Str$length";
        subtype $type, as "Str", where { length($_) == $length };
    } elsif ($col->type eq 'datetime') {
        $type = 'DateTime';
    } elsif ($col->type eq 'integer') {
        $type = "Num";
    } else {
        die("Unknown type: " . $col->type .
            " for column " . $col->name . " in class " . $class->meta->class);
    }
    unless($col->not_null) {
        $type = "Maybe[$type]";
    }
    return $type;
}

1;
