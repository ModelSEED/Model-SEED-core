########################################################################
# ModelSEED::MS::Factories::FBAMODELFactory
# 
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-06-03
########################################################################
=pod
=head1 ModelSEED::MS::Factories::FBAMDOELFactory

A Factory that uses an FBAMODEL server to pull construct a model.

=head2 Methods

=head3 createModel

=cut
package ModelSEED::MS::Factories::FBAMODELFactory;
use FBAMODELClient;
use ModelSEED::utilities;
use Class::Autouse qw(
    ModelSEED::Auth::Factory
    ModelSEED::Auth
    ModelSEED::MS::Model
    ModelSEED::MS::Biomass
);
use Try::Tiny;
use Moose;
use namespace::autoclean;

has auth => ( is => 'ro', isa => "ModelSEED::Auth", required => 1);
has store => ( is => 'ro', isa => "ModelSEED::Store", required => 1);
has client => ( is => 'ro', isa => "FBAMODELClient", lazy => 1, builder => '_build_client');
has auth_config => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_auth_config');

sub listAvailableModels {
    my ($self) = @_;
    my $ids = $self->client->get_model_id_list($self->auth_config);
    return $ids;
}

sub createModel {
    my ($self, $args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["id", "annotation"],{
        verbose => 0,
	});
    # Get basic model data
    my $data;
    my $config = \%{$self->auth_config};
    $config->{id} = $args->{id};
    print "Getting model metadata...\n" if($args->{verbose});
    try {
        $data = $self->client->get_model_stats($config);
    };
    if(!defined($data) || !defined($data->{data}) || @{$data->{data}} == 0) {
        die "Unable to find model with id ". $args->{id}."\n";
    }
    my $model_data;
    foreach my $entry (@{$data->{data}}) {
        if($entry->{id} eq $args->{id}) {
            $model_data = $entry;
            last;
        }
    }
    print "Loading linked objects...\n" if($args->{verbose});
    my $annotation = $args->{annotation};
    my $mapping      = $annotation->mapping;
    my $biochemistry = $mapping->biochemistry;
    my $model = $self->store->create("Model", {
		locked => 0,
		public => $model_data->{public} || 0,
		id => $model_data->{id},
		name => $model_data->{name},
		type => "Singlegenome",
		mapping_uuid => $mapping->uuid,
		biochemistry_uuid => $biochemistry->uuid,
		annotation_uuid => $annotation->uuid,
    });
    print "Getting model reactions...\n" if($args->{verbose});
    $config = \%{$self->auth_config};
    $config->{id} = $args->{id};
    my $rxn_obj = $self->client->get_model_reaction_data($config);
    unless(defined($rxn_obj) && defined($rxn_obj->{data})) {
        die "Error in getting reaction data for " . $args->{id} . "\n";
    }
    my $rxns = $rxn_obj->{data};
    my $biomassIndex = 0;
    foreach my $rxn (@$rxns) {
        my $id = $rxn->{DATABASE}->[0];
        if ( $id =~ m/bio\d+/ ) {
            # Add as a biomass equation
			my $bioobj = $model->add("biomasses", ModelSEED::MS::Biomass->new({
				name => sprintf("bio%05d", $biomassIndex),
			}));
            $bioobj->loadFromEquation({
                equation => $rxn->{EQUATION}->[0],
                aliasType => "ModelSEED"
            });
			$biomassIndex++;
		} else {
			my $rxn = $biochemistry->getObjectByAlias(
                "reactions", 
                $id,
                "ModelSEED"
            );
            my $direction = $rxn->{DIRECTION}->[0];
            if($direction eq "=>") {
                $direction = ">";
            } elsif ($direction eq "<=") {
                $direction = "<";
            } else {
                $direction = "=";
            }
            if(!defined($rxn)) {
                warn "Could not find rxn_instance for $id!\n";
                next;
            }
			$model->addReactionToModel({
				reaction => $rxn,
				direction => $direction,
				gpr => $rxn->{PEGS}
			});
		}
	}
    return $model;
}

sub _build_client {
    return FBAMODELClient->new();
}
sub _build_auth_config {
    my ($self) = @_;
    if($self->auth->isa("ModelSEED::Auth::Basic")) {
        return { user => $self->auth->username,
                 password => $self->auth->password,
               };
    } else {
        return {};
    }
}

sub _get_uuid_from_alias {
    my ($self, $ref) = @_;
    return undef unless(defined($ref));
    my $alias_objects = $self->store->get_aliases($ref);
    if(defined($alias_objects->[0])) {
        return $alias_objects->[0]->{uuid}
    } else {
        return undef;
    }
}

1;
