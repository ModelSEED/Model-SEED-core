########################################################################
# ModelSEED::Reference - Class for parsing, generating references
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-16
########################################################################
package ModelSEED::Reference;
use Data::Dumper;
=pod

=head1 ModelSEED::Reference

Get information about references.
TODO : update docs

=head2 Construction

The C<new> function accepts different parameters for constructing
a reference. These are divided into sets where each set contains the
complete parameters needed to create a reference:

=over 4

=item Basic string

Pass in a string to the attribute 'ref'.

    my $ref = ModelSEED::Reference->new(ref => "biochemistry/chenry/main");

=item UUID and type

Pass in the attributes 'uuid' and 'type' for a top level object.
Pass in 'uuid', 'type', 'base_ids', and 'base_types' for deep references: 

    my $ref = ModelSEED::Reference->new(uuid => :uuid, type => 'biochemistry');
    my $ref = ModelSEED::Reference->new(uuid => :uuid, type => 'compound',
        base_types => [ 'biochemistry' ], base_ids => [ 'chenry/main' ]
    );

=item Alias and type

Pass in the attributes 'alias' and 'type' for a top level object.
Include the 'base_ids' and 'base_types' for deep refernces.

=head3 parse

    ModelSEED::Reference->new( ref => "biochemistry/chenry/main/reactions/:uuid");
    {
        type => "collection" || "object",
        base => "biochemistry/chenry/main/reactions"
        id   => ":uuid"
        id_type => "uuid" || "alias"
        class => "ModelSEED::MS::Reaction",
        parent_objects => [ "biochemistry/chenry/main" ],
        parent_collections => [ "biochemistry", "biochemistry/chenry/main/reactions" ],
        is_url => boolean,
        scheme  => undef || 'http',
        authority => undef || 'model-api.theseed.org',

        alias_type
        alias_username
        alias_string
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


## Generally fixed instance variables
has delimiter => (is => 'ro', isa => 'Str', default => '/');

### Attributes
####### String representation
has ref    => (is => 'ro', isa => 'Str');

####### URI Info
has is_url => (is => 'ro', isa => 'Bool');
has scheme => (is => 'ro', isa => 'Maybe[Str]');
has authority => (is => 'ro', isa => 'Maybe[Str]');

####### Basic Info 
has type    => (is => 'ro', isa => 'Str');
has base    => (is => 'ro', isa => 'Str');
has id      => (is => 'ro', isa => 'Maybe[Str]');
has class   => (is => 'ro', isa => 'Str');
has id_type => (is => 'ro', isa => 'Str');

####### ID Info
has alias_type     => (is => 'ro', isa => 'Maybe[Str]');
has alias_username => (is => 'ro', isa => 'Maybe[Str]');
has alias_string   =>  (is => 'ro', isa => 'Maybe[Str]');

####### Alias Owner Info
has has_owner => ( is => 'ro', isa => 'Bool');
has owner     => ( is => 'ro', isa => 'Maybe[Str]');
    
####### Parent Object References
has base_types => ( is => 'ro', isa => 'ArrayRef');
has parent_objects => ( is => 'ro', isa => 'ArrayRef');
has parent_collections => ( is => 'ro', isa => 'ArrayRef');

around BUILDARGS => sub {
    my $orig = shift @_;
    my $class = shift @_;
    my $args;
    my $schema = _build_schema();
    if(ref($_[0]) eq 'HASH') {
        $args = shift @_;
    } else {
        my %args = @_;
        $args = \%args;
    }
    my $delimiter = $args->{delimiter};
    $delimiter = "/" unless(defined($delimiter));
    my $ref = $args->{ref};
    unless(defined($ref)) {
        if (defined($args->{base_types}) && defined($args->{base_ids})) {
            my $i = scalar(@{$args->{base_types}});
            my $j = scalar(@{$args->{base_ids}});
            my $max = ($i > $j) ? $i : $j;
            for(my $k = 0; $k<$max; $k++) {
                $ref .= $delimiter if($k > 0);
                $ref .= $args->{base_types}->[$k];
                $ref .= $delimiter;
                if($k < $j) {
                    $ref .= $args->{base_ids}->[$k];
                } else {
                    last;
                }
            }
        }
        if (!defined($ref) ** defined($args->{type})) {
            $ref .= $args->{type} . $delimiter;
            if (defined($args->{uuid})) {
                 $ref .= $args->{uuid};
            } elsif (defined($args->{alias})) {
                $ref .= $args->{alias};
            }
        }
        # Case of an http:// reference
        if(defined($args->{scheme}) && defined($args->{authority})) {
            $ref = uri_join($args->{scheme}, $args->{authority}, $ref);
        }
    }
    my $hash = parse($ref, $delimiter, $schema);
    die "Invalid Reference" unless(defined($hash));
    return $class->$orig($hash);
};

sub parse {
    my ($ref, $delimiter, $schema) = @_;
    my ($scheme, $auth, $query, $frag) = uri_split($ref);
    my $rtv = {};
    my @parts = split(/$delimiter/, $query);
    my ($id, $base, $base_types, $id_type, $owner) = ([], [], [], undef, undef);
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
            my $result = _validate($schema, @parts);
            my $idParts = $result->{parts};
            $id_type = $result->{type};
            if(@$idParts) {
                # if we got a complete id
                $type = "object";
                $id = $idParts;
                # remove this many entries from the parts 
                splice(@parts,0,scalar(@$idParts));
                if($id_type eq 'alias') {
                    my ($alias_username, $alias_string) = @$id;
                    $owner = $alias_username;
                }
            } elsif (@parts == 1) {
                # partial reference, username
                $owner = shift @parts;
                $type = 'collection';
            } else {
               return undef 
            }
        }
    }
    # remove empty strings from id, base
    $base = [ grep { defined($_) && $_ ne '' } @$base ];
    $id = [ grep { defined($_) && $_ ne '' } @$id ];
    return undef unless(defined $schema->{type});
    $rtv = {
        delimiter => $delimiter,
        type => $type,
        class => $schema->{class},
        parent_collections => $parent_collections,
        parent_objects => $parent_objects,
    };
    $rtv->{scheme} = $scheme if(defined($scheme));
    $rtv->{authority} = $auth if(defined($auth));
    $rtv->{is_url} = (defined($scheme) && defined($auth)) ? 1 : 0;
    $rtv->{base_types} = $base_types;
    $rtv->{base} = join($delimiter, @$base) if(@$base);
    $rtv->{id} = join($delimiter, @$id) if(@$id);
    $rtv->{id_type} = $id_type if(@$id);
    $rtv->{owner} = $owner if(defined($owner));
    $rtv->{has_owner} = (defined $owner) ? 1 : 0;
    if($id_type eq 'alias') {
        my $alias_type = $rtv->{parent_collections}->[0];
        my ($alias_username, $alias_string) = @$id;
        $rtv->{alias_type} = $alias_type;
        $rtv->{alias_username} = $alias_username;
        $rtv->{alias_string} = $alias_string;
    }
    return $rtv;
}

sub _build_schema {
    my $defs = ModelSEED::MS::Metadata::Definitions::objectDefinitions();
    my $schema = { children => {} };
    foreach my $name (keys %$defs) {
        my $definition = $defs->{$name};
        if ( defined($definition->{parents}) &&
            'ModelSEED::Store' ~~ $definition->{parents}) {
            my $refName = lc(substr($name, 0,1)).substr($name,1);
            $schema->{children}->{$refName} =
                _build_schema_recursive($name, $defs);
        }
    }
    return $schema;
}

sub _build_schema_recursive {
    my ($name, $definitions) = @_;
    my $class = "ModelSEED::MS::".$name;
    my $id_types = $definitions->{$name}->{reference_id_types};
    unless(@$id_types) {
        $id_types = [ 'uuid' ];
    }
    my $children = {};
    my $subobjects = $definitions->{$name}->{subobjects};
    foreach my $subobject (@$subobjects) {
        my $class = $subobject->{class};
        my $def   = $definitions->{$class};
        die "Could not find $class in MS definitions" unless(defined($def));
        next if($def->{class} eq 'encompassed');
        my $refName = $subobject->{name};
        $children->{$refName} =
            _build_schema_recursive($class, $definitions);
    }
    my $object = {
        type => "collection",
        id_types => $id_types,
        class => $class,
        children => $children
    };
    return $object;
}

sub _validate {
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
    if(defined($alias) && defined($username)) {
        return [$username, $alias];
    } else {
        return [];
    }
}

sub _uuid {
    my ($uuid) = @_;
    return [$uuid] if($uuid =~ m/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/);
    return [];
}

sub _build_is_url {
    my ($self) = @_;
    if (defined($self->scheme) && defined($self->authority)) {
        return 1;
    }
    return 0;
}

1;
