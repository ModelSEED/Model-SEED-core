########################################################################
# ModelSEED::Database::Composite - Composite implementation of Database
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-01
########################################################################
=pod

=head1 ModelSEED::Database::Composite

A composite implementation of the L<ModelSEED::Database> interface.

=head1 Methods

=head2 new

    my $db = ModelSEED::Database::Composite->new(\%);

This initializes a Storage interface object. This accepts a hash
reference to configuration details. Currently this only accepts
two parameters:

=over

=item C<databases>

An array reference (C<\@>) where each element in the array is either
a L<ModelSEED::Database> implementation or a hash reference (C<\%>)
like the following:

    {
        class => "ModelSEED::Database::*"
        ...
    }

C<class> must be a valid class that implements the L<ModelSEED::Database>
role. All other attributes are used as arguments to the constructor
for that class.

=item C<use_config>

A boolean flag. If this is set, use the configuration details in
L<ModelSEED::Configuration> under the "stores" key as arguments
like in C<databases>.

=back

=head2 Concepts

Since this acts as a composite over a number of database instances,
it behaves a little differently from a standard L<ModelSEED::Database>
implementation. For most "read" functions, this class simply calls
those functions on each database in it's composite. However, some
functions will stop searching after they find a result.  For "write"
functions, e.g.  C<save_object>, it will call this on all databases
in the composite.

List of "read" functions:

    has_object *
    get_object *
    get_metadata *
    find_objects

Note that any function with a (*) stops searching after it finds
results.  So, for example C<has_object> may not query all databases.

List of "write" functions:

    save_object
    delete_object
    set_metadata
    remove_metadata

=head2 Methods

See L<ModelSEED::Database> for methods.

=cut
package ModelSEED::Database::Composite;
use Moose;
use Moose::Util::TypeConstraints;
use Class::Autouse qw(
    ModelSEED::Configuration
    ModelSEED::Database::FileDB
);
with 'ModelSEED::Database';

role_type 'DB', { role => 'ModelSEED::Database' };
has databases => ( is => 'ro', isa => 'ArrayRef[DB]', required => 1 );

around BUILDARGS => sub {
    my $orig  = shift @_;
    my $class = shift @_;
    my $args  = shift @_;
    if(defined($args->{use_config}) && $args->{use_config}) {
        my $Config = ModelSEED::Configuration->new();
        $args->{databases} = [ @{$Config->config->{stores}} ];
    }
    foreach my $db (@{ $args->{databases} || [] }) {
        if(ref($db) eq 'HASH') {
            my $class = $db->{class};
            $db = $class->new($db);
        } elsif(ref($db) && $db->does("ModelSEED::Database")) {
            next; 
        } else {
            die "Unknown argument to constructor: $db!";
        }
    }
    return $class->$orig($args);
};

sub has_object {
    my $self = shift @_;
    my $val = 0;
    foreach my $db (@{$self->databases}) {
        $val = $db->has_object(@_); 
        last if $val;
    }
    return $val;
}

sub get_object {
    my $self = shift @_;
    my $obj = undef;
    foreach my $db (@{$self->databases}) {
        $obj = $db->get_object(@_);
        last if $obj;
    }
    return $obj;
}

sub save_object {
    my $self = shift @_;
    my $rtv;
    foreach my $db (@{$self->databases}) {
        $rtv = $db->save_object(@_);
    }
    return $rtv;
}

sub delete_object {
    my $self = shift @_;
    my $deleteCount = 0;
    foreach my $db (@{$self->databases}) {
        $deleteCount += $db->delete_object(@_);
    }
    return $deleteCount;
}

sub get_metadata {
    my $self = shift @_;
    my $meta = undef;
    foreach my $db (@{$self->databases}) {
        $meta = $db->get_metadata(@_);
        last if $meta;
    }
    return $meta;
}

sub set_metadata {
    my $self = shift @_;
    return $self->databases->[0]->set_metadata(@_);
}

sub remove_metadata {
    my $self = shift @_;
    my $removeCount = 0;
    foreach my $db (@{$self->databases}) {
        $removeCount += $db->remove_metadata(@_);
    }
    return $removeCount;
}

sub find_objects {
    my $self = shift @_;
    my $found = [];
    foreach my $db (@{$self->databases}) {
        my @args = @_;
        push(@$found, @{$db->find_objects(@args)});
    }
    return $found;
}

1;
