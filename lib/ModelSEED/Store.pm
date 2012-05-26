########################################################################
# ModelSEED::Store - Authenticated storage interface layer
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-01
########################################################################
=pod

=head1 ModelSEED::Store 

Authenticated storage interface layer

=head1 METHODS

=head2 new

    my $Store = ModelSEED::Store->new(\%);

This initializes a Storage interface object. This accepts a hash
reference to configuration details. In addition to authentication,
which is required and will be covered in a moment, this currently
accepts one parameter:

=over

=item database

A reference to a L<ModelSEED::Database> object. This is the
base storage interface that the Store will use. If this is not
provided, it will be initialized based on the contents of the
L<ModelSEED::Configuration> package.

=back

=head3 Authentication

The C<new> method requires authentication information. Without this,
or if authentication fails, the class will raise an exception
C<"Unauthorized">. Currently the class accepts one type of
authentication:

=over

=item Basic

Basic Authentication - Requires "username" and "password" fields.
This will attempt to authenticate against the data in the Store::Private
dataset under the type "user". If no user is found, it will attempt
to use the L<ModelSEED::ModelSEEDClients::MSSeedSupportClient>
package to retrieve authentication information from the central
servers.

=item Public


=back

=head2 Other Functions

This package has the same set of functions as C<ModelSEED::Store::Private>
but these functions do not accept a "user" as the first argument.
All other arguments are "shifted up by one". For example, in the
private interface, we have this function:

    my $data = $StorePrivate->get_data("alice", "model", "alice/myModel");

This is equivalent to the following function in the L<ModelSEED::Store>
interface, provided that the user C<alice> authenticated during
initialization:

    my $data = $Store->get_data("model", "alice/myModel");

Therefore, you should consult the L<ModelSEED::Store::Private>
documentation for further method details.

=head2 Helper Functions

Finally this class has a few helper functions that assist in
object creation. Currently there is only one function:

=head3 create

    my $object = $Store->create("Biochemistry, { name => "Foo" });

This creates a L<ModelSEED::MS::Biochemistry> object and returns
it.  It does not save the object, however, it does initialize the
object with the "parent" pointing back at the C<$Store> instance.
This instance will be used if C<$object->save()> is called without
another store object. It will also be used if the L<ModelSEED::MS>
object needs additional data.

=cut
package ModelSEED::Store;
use Moose;
use ModelSEED::Auth;
use ModelSEED::Database;
use Class::Autouse qw(
    ModelSEED::Database::Composite
    ModelSEED::Reference
);
use Try::Tiny;
use Module::Load;
use Carp qw(confess);

has auth => ( is => 'ro', isa => 'ModelSEED::Auth', required => 1);
has database => ( is => 'ro', isa => 'ModelSEED::Database', lazy => 1, builder => '_build_database');

sub create {
    my ($self, $type, $base_hash) = @_;
    $base_hash = {} unless(defined($base_hash));
    my $className = uc(substr($type,0,1)).substr($type,1);
    $className = "ModelSEED::MS::".$className;
    $self->_load_class($className);
    $base_hash->{parent} = $self unless(defined($base_hash->{parent}));
    return $className->new($base_hash);
}

sub has_object {
    my ($self, $ref) = @_;
    return $self->has_data($ref);
}

sub get_object {
    my ($self, $ref) = @_;
    $ref = $self->_coerce_ref($ref);
    my $o = $self->get_data($ref);
    my $class = $self->_get_class($ref);
    $self->_load_class($class);
    return $class->new($o);
}

sub save_object {
    my ($self, $ref, $object) = @_;
    my $data = $object->serializeToDB(); 
    return $self->save_data($ref, $data);
}

sub find_objects {
    my ($self, $query) = @_;

}

# Helpers and Builders

sub _get_class {
    my ($self, $ref) = @_;
    return $ref->{class};
}

sub _coerce_ref {
    my ($self, $ref) = @_;
    if(ref($ref) && $ref->isa('ModelSEED::Reference')) {
        return $ref;
    }
    return ModelSEED::Reference->new(ref => $ref);
}

sub _load_class {
    my ($self, $class) = @_;
    try {
        load $class;
    } catch {
        die "Unable to load $class : $_";
    };
}

sub _build_database {
    return ModelSEED::Database::Composite->new({use_config => 0});
};

sub AUTOLOAD {
    my $self = shift @_;
    my $call = our $AUTOLOAD;
    return if $AUTOLOAD =~ /::DESTROY$/;
    $call =~ s/.*://;
    my $rtv;
    push(@_, $self->auth);
    my @args = @_;
    try {
        $rtv = $self->database->$call(@args);
    } catch {
        confess $_;
    };
    return $rtv;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
