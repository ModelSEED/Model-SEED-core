########################################################################
# ModelSEED::Auth - Abstract role / interface for authentication
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-16
########################################################################
package ModelSEED::RefParse;
=pod

=head1 ModelSEED::RefParse

Get information about references.

=head2 Methods

=head3 parse

    $rp->parse("biochemistry/chenry/main/reactions/:uuid");
    {
        type => "collection" || "object",
        base => "biochemistry/chenry/main/reactions"
        id   => ":uuid"
        id_type => "uuid" || "alias"
        class => "ModelSEED::MS::Reaction",
        parent_objects => [ "biochemistry/chenry/main" ],
        parent_collections => [ "biochemistry", "biochemistry/chenry/main/reactions" ],
    }

Where type is either a collection or an object, base is a reference
that will return the parent object or collection, id is the identifier
for the object, class is the class pointed to by the reference and
id_validator is a subroutine that will validate the id.
=cut
use Moose;
use URI::Split qw(uri_split uri_join);
use ModelSEED::MS::Metadata::Definitions;
use Data::Dumper;
use common::sense;

has delimiter => (is => 'ro', isa => 'Str', default => '/');
has schema => (
    is => 'ro',
    isa => 'HashRef',
    builder => '_buildSchema',
    lazy => 1
);

sub parse {
    my ($self, $ref) = @_;
    my ($scheme, $auth, $query, $frag) = uri_split($ref);
    my $delimiter = $self->delimiter;
    my $rtv = {};
    my @parts = split(/$delimiter/, $query);
    my $schema = $self->schema;
    my ($id, $base, $base_types, $id_type) = ([], [], [], undef);
    my ($parent_objects, $parent_collections) = ([], []);
    my $type = "collection";
    while (@parts) {
        my $part = shift @parts;
        if($part eq '') {
            # case of stuff before first slash, or final slash
            next;
        } elsif(defined($schema->{children}->{$part})) {
            # Case of a new collection of children in ref
            $schema = $schema->{children}->{$part};
            if(@$id) {
                push(@$base, @$id);
                push(@$parent_objects, join($delimiter, @$base));
                $id = [];
            } 
            $type = "collection";
            push(@$base, $part);
            push(@$base_types, $part);
        } else {
            unshift(@parts, $part);
            # now within a collection, must have a type
            push(@$parent_collections, join($delimiter, @$base));
            return undef unless(defined($schema->{type}));
            # and a validator for ids within that collection
            my $result = $self->_validate($schema, @parts);
            my $idParts = $result->{parts};
            $id_type = $result->{type};
            # and our id must validate
            return undef unless(@$idParts);
            $type = "object";
            $id = $idParts;
            # remove this many entries from the parts 
            splice(@parts,0,scalar(@$idParts));
        }
    }
    if($type eq 'collection') {
        # collection types will still have "base" pointing
        # to that collection
        pop(@$base);
    }
    # remove empty strings from id, base
    $base = [ grep { defined($_) && $_ ne '' } @$base ];
    $id = [ grep { defined($_) && $_ ne '' } @$id ];
    return undef unless(defined $schema->{type});
    $rtv = {
        type => $type,
        id_validator => $schema->{id_validator},
        class => $schema->{class},
        parent_collections => $parent_collections,
        parent_objects => $parent_objects,
    };
    $rtv->{base_types} = $base_types;
    $rtv->{base} = join($delimiter, @$base) if(@$base);
    $rtv->{id} = join($delimiter, @$id) if(@$id);
    $rtv->{id_type} = $id_type if(@$id);
    return $rtv;
}

sub _buildSchema {
    return {
        children => {
            biochemistry => {
                type         => "collection",
                id_types     => [ 'uuid', 'alias' ],
                class        => "ModelSEED::MS::Biochemistry",
                children     => {
                    reactions => {
                        type => "collection",
                        id_types => [ 'uuid' ],
                        class => "ModelSEED::MS::Reaction",
                    },
                    compounds => {
                        type => "collection",
                        id_types => [ 'uuid' ],
                        class => "ModelSEED::MS::Compound",
                    },
                    media => {
                        type => "collection",
                        id_types => [ 'uuid' ],
                        class => "ModelSEED::MS::Media",
                    },
                }
            },
            model   => {},
            mapping => {},
            user    => {},
        }
    };
}

sub _validate {
    my $self = shift @_;
    my $schema = shift @_;
    my @args = @_;
    my $validatorMap = {
        alias => \&_alias,
        uuid  => \&_uuid,
    };
    my ($final_type, $parts);
    return undef unless(defined($schema->{id_types}));
    foreach my $type (@{$schema->{id_types}}) {
        my $fn = $validatorMap->{$type};
        $parts = $fn->(@args);
        $final_type = $type;
        last if @$parts;
    }
    return { type => undef, parts => [] } unless(@$parts);
    return { type => $final_type, parts => $parts };
}

sub _alias {
    my $username = shift @_;
    my $alias = shift @_;
    return [$username, $alias];
}

sub _uuid {
    my ($uuid) = @_;
    return [$uuid] if($uuid =~ m/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/);
    return [];
}
1;
