package ModelSEED::Role::Owned;

use Moose::Role;

requires 'public';

sub admins {
    # people with admin for object
}

sub editors {
    # people with edit for object
}

sub viewers {
    # people with view for object
}

sub get_permissions_for {
    my ($self, $person) = @_;
    # return permission object for person
    my $p = { admin => 0, edit => 0, view => 0 };
    # get perm object for person if it exists 
    $p->{view} = 1 if($self->public);
    return $p;
}

1;
