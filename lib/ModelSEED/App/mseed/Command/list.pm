package ModelSEED::App::mseed::Command::list;
use Try::Tiny;
use List::Util qw(max);
use Class::Autouse qw(
    ModelSEED::Reference
    ModelSEED::Auth::Factory
    ModelSEED::Store
    ModelSEED::App::Helpers
);
use base 'App::Cmd::Command';
use Data::Dumper;

sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config();
    my $store  = ModelSEED::Store->new(auth => $auth);
    my $helpers = ModelSEED::App::Helpers->new;

    my $arg = shift @$args;
    my $ref;
    try {
        $ref = ModelSEED::Reference->new(ref => $arg);
    };
    if(defined($ref)) {
        # Base level collection ( want a list of aliases )
        if($ref->type eq 'collection' && 0 == @{$ref->parent_collections}) {
            my $aliases = $store->get_aliases({ type => $ref->base });
            foreach my $a (@$aliases) {
                print $a->{type} . "/" . $a->{owner} . "/" . $a->{alias} . "\n";
            }
        # Subobject listing. want a list of ids under subobject
        } elsif($ref->type eq 'collection' && @{$ref->parent_collections}) {
            my $data = $store->get_data($ref->parent_objects->[0]);
            my @sections = split($ref->delimiter, $ref->base);
            my $subtype = pop @sections;
            # Ancestor_uuids is just a list of uuids, special case
            if($subtype eq 'ancestor_uuids') {
                my $grandparent_ref = ModelSEED::Reference->new(ref => $ref->parent_objects->[0]);
                foreach my $o (@{$data->{$subtype}}) {
                    print $grandparent_ref->base . "/" . $o . "\n";
                }
            } else {
                foreach my $o ( @{$data->{$subtype}} ) {
                    print $ref->base . "/" . $o->{uuid} . "\n";
                }
            }
        # Want a breakdown of the subobjects
        } elsif($ref->type eq 'object') {
            my $data = $store->get_data($ref->base . $ref->delimiter . $ref->id);
            my $max =  max map { length $_ } keys %$data;
            $max += 5;
            foreach my $k ( keys %$data ) {
                my $v = $data->{$k};
                if(ref($v) eq 'ARRAY') {
                    printf("%-${max}s(%d)\n", ($k, scalar(@$v)));
                }
            }
            # how the fuck
        }
    } else {
        # ref was an empty string or completely invalid 
        my $aliases = $store->get_aliases({});
        exit unless(@$aliases);
        my $types = {};
        # Print counts for aliased objects
        foreach my $alias (@$aliases) {
            $types->{$alias->{type}} = 0 unless(defined($types->{$alias->{type}}));
            $types->{$alias->{type}} += 1;
        }
        printf("%-15s\t%-15s\n", ("Type", "Count"));
        foreach my $type (keys %$types) {
            printf("%-15s\t%d\n", ($type."/", $types->{$type}));
        }
    }
}

sub abstract {
    return "List and retrive objects from workspace or datastore.";
}

sub _processRef {
    my ($ref) = @_;
    return split(/\//, $ref);
}

1;
