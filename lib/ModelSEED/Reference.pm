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
package ModelSEED::Reference;
=pod

=head1 ModelSEED::Reference

Get information about references.
TODO : update docs

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

has ref => ( is => 'ro', isa => 'Str', required => 1, lazy => 1, builder => '_build_ref' );
has delimiter => (is => 'ro', isa => 'Str', default => '/');
has schema => (
    is => 'ro',
    isa => 'HashRef',
    builder => '_buildSchema',
    lazy => 1
);
has _parsed_ref => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_parsed_ref' );

has is_url => ( is => 'ro', isa => 'Bool', lazy => 1, builder => '_build_is_url' );
has scheme => ( is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_scheme' );
has authority => ( is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_authority');

has type  => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_type');
has base  => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_base');
has id    => (is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_id');
has class => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_class');

has id_type    => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_id_type');
has alias_type => (is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_alias_type');
has alias_username => (is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_alias_username');
has alias_string =>  (is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_alias_string');

has base_types => ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_base_types');
has parent_objects => ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_parent_objects');
has parent_collections => ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_parent_collections');

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
    $rtv->{scheme} = $scheme if(defined($scheme));
    $rtv->{authority} = $auth if(defined($auth));
    $rtv->{base_types} = $base_types;
    $rtv->{base} = join($delimiter, @$base) if(@$base);
    $rtv->{id} = join($delimiter, @$id) if(@$id);
    $rtv->{id_type} = $id_type if(@$id);
    if($id_type eq 'alias') {
        my $alias_type = $rtv->{parent_collections}->[0];
        my ($alias_username, $alias_string) = @$id;
        $rtv->{alias_type} = $alias_type;
        $rtv->{alias_username} = $alias_username;
        $rtv->{alias_string} = $alias_string;
    }
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

sub _build_parsed_ref {
    my ($self) = @_;
    return $self->parse($self->ref);
}

sub _build_ref {
    my ($self) = @_;

    my $query = $self->base;
    $query .= $self->delimiter . $self->id if($self->type eq 'object');
    if ($self->is_url) {
        return uri_join($self->scheme, $self->authority, $query);
    } else {
        return $query;
    }
}

sub _build_is_url {
    my ($self) = @_;
    if (defined($self->scheme) && defined($self->authority)) {
        return 1;
    }
    return 0;
}

sub _build_scheme {
    return $_[0]->_parsed_ref->{scheme};
}
sub _build_authority {
    return $_[0]->_parsed_ref->{authority};
}
sub _build_type {
    return $_[0]->_parsed_ref->{type};
}
sub _build_base {
    return $_[0]->_parsed_ref->{base};
}
sub _build_id {
    return $_[0]->_parsed_ref->{id};
}
sub _build_id_type {
    return $_[0]->_parsed_ref->{id_type};
}
sub _build_class {
    return $_[0]->_parsed_ref->{class};
}
sub _build_base_types {
    return $_[0]->_parsed_ref->{base_types};
}
sub _build_parent_objects {
    return $_[0]->_parsed_ref->{parent_objects};
}
sub _build_parent_collections {
    return $_[0]->_parsed_ref->{parent_collections};
}
sub _build_alias_type {
    return $_[0]->_parsed_ref->{alias_type};
}
sub _build_alias_username {
    return $_[0]->_parsed_ref->{alias_username};
}
sub _build_alias_string {
    return $_[0]->_parsed_ref->{alias_string};
}

1;
