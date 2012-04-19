package ModelSEED::PersistenceAPI;

use Moose;

use Try::Tiny;

use ModelSEED::Database;

has db        => ( is => 'rw', isa => 'ModelSEED::Database' );
has db_type   => ( is => 'rw', isa => 'Str', required => 1 );
has db_config => ( is => 'rw', isa => 'HashRef', required => 1 );

=head

params

{
    db_type   => 'FileDB',
    db_config => {
	directory => '',
	filename => ''
    },
}

=cut

sub BUILD {
    my ($self) = @_;

    # get database connection
    my $db_mod = "ModelSEED::" . $self->db_type;
    my $db_req = $db_mod . ".pm";
    $db_req =~ s/::/\//g;

    try {
	require $db_req;
	$self->db($db_mod->new($self->db_config));
    } catch {
	die "Could not import database package: $db_mod";
    }
}



sub _get_id_from_alias {
    my ($self, $
}


sub has_object {
    my ($user, $type, $alias) = @_;

}

=head
    get_object(user, type, alias);
=cut
sub get_object {
    my ($user, $type, $alias) = @_;

    my $data = $self->get_data($user, $type, $alias);
}

=head
    get_data(user, type, alias);
=cut
sub get_data {
    my ($user, $type, $alias) = @_;

    
}

=head
    save_object(user, type, alias, object);
=cut
sub save_object {
    my ($user, $type, $alias, $object) = @_;

    if ($self->has_object($user, $type, $alias)) {
	
    }
}

=head
    delete_object(user, type, alias);
=cut
sub delete_object {
    my ($user, $type, $alias) = @_;

}

=head
    find_aliases(user, type);
=cut
sub find_aliases {}

=head
    get/set permissions
=cut
sub permissions {}

no Moose;
__PACKAGE__->meta->make_immutable;
