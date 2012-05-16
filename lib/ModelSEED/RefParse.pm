#
#===============================================================================
#
#         FILE: RefParse.pm
#
#  DESCRIPTION: Parse References
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 05/16/2012 09:59:58
#     REVISION: ---
#===============================================================================
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
        class => "ModelSEED::MS::Reaction",
        id_validator => \sub { ... }

    }

=cut
use Moose;
use URI::Split qw(uri_split uri_join);
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
    warn $query;
    my @parts = split(/$delimiter/, $query);
    my $schema = $self->schema;
    my ($id, $base) = ([], []);
    while (@parts) {
        my $part = shift @parts;
        warn $part;
        if($part eq '') {
            next;
        } elsif(defined($schema->{children}->{$part})) {
            $schema = $schema->{children}->{$part};
            warn Dumper($id);
            if(@$id) {
                push(@$base, @$id);
            } 
            push(@$base, $part);
        } else {
            push(@parts, $part);
            # now within a collection, must have a type
            return undef unless(defined($schema->{type}));
            # and a validator for ids within that collection
            return undef unless(defined($schema->{id_validator}));
            my $validator = $schema->{id_validator};  
            my @partsCpy = @parts;
            warn @parts;
            my @idParts = $validator->(@partsCpy);
            # and our id must validate
            return undef unless(@idParts);
            $id = [@idParts];
            # remove this many entries from the parts 
            warn @idParts;
            splice(@parts,0,scalar(@idParts));
            warn @parts;
        }
    }
    return undef unless(defined $schema->{type});
    $rtv = {
        type => $schema->{type},
        base => $base,
        id_validator => $schema->{id_validator},
        class => $schema->{class}
    };
    $rtv->{id} = join($delimiter, @$id) if(@$id);
    return $rtv;
}

sub _buildSchema {
    return {
        children => {
            biochemistry => {
                type         => "collection",
                id_validator => \&_aliasOrUUID,
                class        => "ModelSEED::MS::Biochemistry",
                children     => {
                    reactions => {
                        type => "collection",
                        id_validator => \&_uuid,
                        class => "ModelSEED::MS::Reaction",
                    },
                    compoudns => {

                    },
                    media => {

                    },
                }
            },
            model   => {},
            mapping => {},
            user    => {},
        }
    };
}

sub _aliasOrUUID {
    my @args1 = @_;
    my @args2 = @_;
    my @try = _alias(@args1);
    return @try if(@try > 0);
    return _uuid(@args2);
}

sub _alias {
    my $username = shift @_;
    my $alias = shift @_;
    return ($username, $alias);
}

sub _uuid {
    my @args = @_;
    my $uuid = shift @args;
    return ($uuid);
}
1;
