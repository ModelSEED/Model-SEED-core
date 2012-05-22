########################################################################
# ModelSEED::MS::DB::FBABiomassVariable - This is the moose object corresponding to the FBABiomassVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::FBABiomassVariable;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::FBAResults', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has biomass_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has variableType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has lowerBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has upperBound => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has min => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has max => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has value => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '0' );




# LINKS:
has biomass => (is => 'rw',lazy => 1,builder => '_buildbiomass',isa => 'ModelSEED::MS::Biomass', type => 'link(Model,Biomass,uuid,biomass_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildbiomass {
	my ($self) = @_;
	return $self->getLinkedObject('Model','Biomass','uuid',$self->biomass_uuid());
}


# CONSTANTS:
sub _type { return 'FBABiomassVariable'; }


__PACKAGE__->meta->make_immutable;
1;
