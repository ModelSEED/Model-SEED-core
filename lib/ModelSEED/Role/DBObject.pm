package ModelSEED::Role::DBObject;

use MooseX::Role::Parameterized;
use Moose::Util::TypeConstraints;
use Rose::DB::Object;
use Scalar::Util;
use Data::Dumper;

use ModelSEED::Role::DoNotStore;

parameter 'rose_class' => ( isa => 'Str', required => 1 );

role {
    my $p = shift;
    my %args = @_;
    
    my $rose_class = $p->rose_class;
    {
        my $rose_class_path = $rose_class;
        $rose_class_path =~ s/::/\//g;
        eval {
            require $rose_class_path
        };
        if($@) {
            die($@);
        }
    }

    sub _wrapMethod {
        my ($type, $method_name) = @_;
        before $method_name => sub {
            my $self = shift @_;
            my $objs;
            if (@_ == 1 && ref($_[0]) eq 'ARRAY') {
                $objs = $_[0];
            } else {
                $objs = [@_];
            }
            foreach my $obj (@$objs) {
                $args{consumer}->meta->class
            }

        };

        after $method_name => sub {
        

        };

    my $methods = [];
    # Get all relationship methods and wrap them with class transformations
    foreach my $rel (@{$rose_class->meta->relationships}) {
        foreach my $type (@{$rel->method_types}) {
            my $method_name = $rel->method_name($type);
            _warpMethod($type, $method_name);
            push(@$methods, $method_name);
        }
    }
    
    
    has '_rdbo' => (
        is => 'rw', isa => $rose_class, lazy => 1, builder => '_buildRDBO',
        handles => [ $rose_class->meta->column_names, qw( db dbh delete
            DESTROY error init_db _init_db insert load not_found save update) ],
        traits => [ 'DoNotStore' ],
    );

    
    around BUILDARGS => sub {
        my $orig = shift;
        my $class = shift;
        if(@_ == 1 && ref($_[0]) eq $rose_class) { 
            return $class->$orig({_rdbo => $_[0]});
        } else {
            return $class->$orig(@_);
        }
    }
    # Construct Rose::DB::Object if not provided
    sub _buildRDBO {
        my $self = shift;
        return $rose_class->new();
    }
}

1;
