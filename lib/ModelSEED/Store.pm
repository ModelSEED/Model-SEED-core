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

=head2 ABSTRACT

=head2 NOTE

For each function in the I<METHODS> section, C<$ref> is
a L<ModelSEED::Reference> object or a string that produces
a valid L<ModelSEED::Reference> object when the constructor
for that class is called thusly:

    my $ref = ModelSEED::Reference->new( ref => $str );

=head2 METHODS

=head3 new

    my $Store = ModelSEED::Store->new(\%);
    my $Store = ModelSEED::Store->new(%);

This initializes a Storage interface object. This accepts a hash
or hash reference to configuration details:

=over

=item auth

The authorization to use when accessing data, i.e. the user requesting
data / objects.  B<This is required> and must be an instance of a
class that implements the L<ModelSEED::Auth> interface.

=item database

A reference to a L<ModelSEED::Database> object. This is the
base storage interface that the Store will use. If this is not
provided, it will be initialized based on the contents of the
L<ModelSEED::Configuration> package.

=back

=head3 Object Methods

These functions operate on L<ModelSEED::MS> objects.

=head4 create

    my $object = $Store->create("Biochemistry, { name => "Foo" });

This creates a L<ModelSEED::MS::Biochemistry> object and returns
it.  It does not save the object, however, it does initialize the
object with the "parent" pointing back at the C<$Store> instance.
This instance will be used if C<$object->save()> is called without
another store object. It will also be used if the L<ModelSEED::MS>
object needs additional data.

=head4 has_object

    my $bool = $Store->has_object($ref);

Returns true if the object matching the reference exists in the database.
Otherwise returns false.

=head4 get_object

    my $obj  = $Store->get_object($ref);

Returns an object for the reference if it exists. Otherwise, returns undef.

=head4 save_object

    my $bool  = $Store->save_object($ref, $obj, $config);

Saves the object C<$obj> using the reference C<$ref>. Returns true
if the save was successful, false otherwise. C<$config> is an
optional hash ref.  This is passed to the C<save_data> function
L<ModelSEED::Database> as C<$config>.  See the documentation of
that function for details.

=head4 find_objects

B<TODO: Not implemented.>

=head3 Data Methods

These functions operate on standard perl hashes. Each of these
functions have the same calling conventions as the I<Object Methods>
functions, but with perl hashes instead of blessed L<ModelSEED::MS>
objects.

=head4 has_data

    my $bool = $Store->has_data($ref);

=head4 get_data

    my $data = $Store->get_data($ref);

=head4 save_data

    my $bool = $Store->save_data($ref, $data, $config);

=head4 find_data

B<TODO: Not implemented.>

=head3 Alias Methods

These functions manipulate aliases and read/write permissions on aliases.
For deatails on usage, see the I<Alias Functions> section of L<ModelSEED::Database>

    my \@aliases   = $Store->get_aliases($query);
    my \@usernames = $Store->alias_viewers($ref);
    my $username   = $Store->alias_owner($ref);
    my $bool       = $Store->alias_public($ref);

    my $success = $Store->add_viewer( $ref, $username );
    my $success = $Store->revmove_viewer( $ref, $username );
    my $success = $Store->set_public( $ref, $bool );

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
    $o->{parent} = $self if defined $o;
    return (defined($o)) ? $class->new($o) : undef;
}

sub save_object {
    my ($self, $ref, $object, $config) = @_;
    my $data = $object->serializeToDB(); 
    return $self->save_data($ref, $data, $config);
}

sub find_objects {
    my ($self, $query) = @_;

}

# Helpers and Builders

sub _get_class {
    my ($self, $ref) = @_;
    return $ref->class();
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
    return ModelSEED::Database::Composite->new({use_config => 1});
};

sub _addAuthToArgs {
    my $self = shift;
    my @args = @_;
    push(@args, $self->auth);
    return @args;
}

# Data Functions
sub has_data { return $_[0]->database->has_data(_addAuthToArgs(@_)); }
sub get_data { return $_[0]->database->get_data(_addAuthToArgs(@_)); }
sub save_data {
    my ($self, $ref, $data, $config) = @_;
    $config = {} unless(defined($config));
    return $self->database->save_data($ref, $data, $config, $self->auth);
}
sub delete_data { return $_[0]->database->delete_data(_addAuthToArgs(@_)); }

# Alias Functions
sub get_aliases { return $_[0]->database->get_aliases(_addAuthToArgs(@_)); }
sub update_alias { return $_[0]->database->update_alias(_addAuthToArgs(@_)); }
sub alias_viewers { return $_[0]->database->alias_viewers(_addAuthToArgs(@_)); }
sub alias_owner { return $_[0]->database->alias_owner(_addAuthToArgs(@_)); }
sub alias_public { return $_[0]->database->alias_public(_addAuthToArgs(@_)); }
sub add_viewer { return $_[0]->database->add_viewer(_addAuthToArgs(@_)); }
sub remove_viewer { return $_[0]->database->remove_viewer(_addAuthToArgs(@_)); }
sub set_public { return $_[0]->database->set_public(_addAuthToArgs(@_)); }

no Moose;
__PACKAGE__->meta->make_immutable;
1;
