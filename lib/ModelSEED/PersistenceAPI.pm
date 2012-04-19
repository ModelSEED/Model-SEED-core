package ModelSEED::PersistenceAPI;

use Moose;

use Try::Tiny;

use ModelSEED::Database;

has db          => ( is => 'rw', isa => 'ModelSEED::Database' );
has db_type     => ( is => 'rw', isa => 'Str' );
has db_config   => ( is => 'rw', isa => 'Str' );

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

    my $env = $self->environment();
    $self->set_environment($env);
}

sub set_environment {
    my ($self, $env) = @_;

    $self->environment($env);

    # check required environment params
    my $required = ['db_type', 'db_config'];
    foreach my $req (@$required) {
	unless (exists($env->{$req})) {
	    die "Required environment parameter not found: '$req'";
	}
    }

    # get database connection
    my $db_mod = "ModelSEED::" . $env->{db_type};
    my $db_req = $db_mod . ".pm";
    $db_req =~ s/::/\//g;

    my $db;
    try {
	require $db_req;

	$self->db($db_mod->new($env->{db_config}));
    } catch {
	die "Could not import database package: $db_mod";
    }
}

=head
    get_object(user, type, alias);
=cut
sub get_object {}

=head
    get_data(user, type, alias);
=cut
sub get_data {}

=head
    save_object(user, type, alias, object);
=cut
sub save_object {}

=head
    delete_object(user, type, alias);
=cut
sub delete_object {}

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
