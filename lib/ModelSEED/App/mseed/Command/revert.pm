package ModelSEED::App::mseed::Command::revert;
use base 'App::Cmd::Command';
use Try::Tiny;
use Class::Autouse qw(
    ModelSEED::Auth::Factory
    ModelSEED::Store
    ModelSEED::App::Helpers
    ModelSEED::Reference
    Data::UUID
);

sub abstract { return "Revert an object to the previous version" }
sub usage_desc { return "ms revert reference [version]" }
sub description { return <<END;
Revert an object to the previous version. If an object has multiple
previous versions (e.g. two objects were 'merged') this command
will prompt you to choose which version to use.
END
}

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth  = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new;
    my ($data, $ref)  = $helpers->get_data("*", $args, $store);
    $self->usage_error("Must supply a reference") unless defined($ref);
    my $refStr = $ref->ref;
    $self->usage_error("Could not find $refStr") unless defined $data;
    my $ancestors = $data->{ancestor_uuids};
    if(@$ancestors == 0) {
        # Error if we have no ancestors
        $self->usage_error("No previous version for $refStr");
    } elsif(@$ancestors > 1) {
        # If we have more than one ancestor
        my $uuid;
        if(@$args > 0) {
            # If revert was called with a specific ancestor
            # ref to revert to, try to use that argument 
            try {
                my $ref = ModelSEED::Reference->new(ref => $args->[0]);
                die unless($ref->id_type eq 'uuid');
                $uuid = $ref->id;
            };
        }
        if(defined($uuid) && $uuid ~~ @$ancestors) {
            # Do the revert if the uuid is in the
            # referece object's ancestor list
            $self->_revert($store, $ref, $uuid);           
        } elsif(defined($uuid)) {
            # Fail if it isn't in the ancestor list
            my $str = $args->[0];
            $self->usage_error("$str does not appear to be an ancestor of $refStr");
        } else {
            # If we didn't get a uuid (or it's invalid)
            # supply the list of potential uuids to revert to
            my $refs = $self->_getAncestorRefs($ref, $ancestors);
            $refs = join("\n", @$refs);
            print $self->_multipleRefError($refStr, $refs); 
        }
    } else {
        # Otherwise just revert to the only ancestor
        $self->_revert($store, $ref, $ancestors->[0]);
    }
}

sub _revert {
    my ($self, $store, $ref, $uuid) = @_;
    my $str = $ref->ref;
    my $rtv = $store->update_alias($ref, $uuid);
    $self->usage_error("Unable to revert $str") unless($rtv);
}

sub _multipleRefError {
    my ($self, $refStr, $refs) = @_;
    return <<END;
Multiple ancestors for $refStr!
$refs
Choose one and run the command:
\$ ms revert $refStr <otherReference>
END
}

sub _getAncestorRefs {
    my ($self, $ref, $ancestors) = @_;
    return [ map { 
        ModelSEED::Reference->new(
            type => $ref->base_type->[0],
            uuid => $_,
        )->ref } @$ancestors
    ];
}

1;
