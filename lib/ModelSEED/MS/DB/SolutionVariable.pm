########################################################################
# ModelSEED::MS::DB::SolutionVariable - This is the moose object corresponding to the SolutionVariable object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::SolutionVariable;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Solution', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has variable_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has value => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# LINKS:
has variable => (is => 'rw',lazy => 1,builder => '_buildvariable',isa => 'ModelSEED::MS::Variable', type => 'link(FBAProblem,Variable,uuid,variable_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildvariable {
	my ($self) = @_;
	return $self->getLinkedObject('FBAProblem','Variable','uuid',$self->variable_uuid());
}


# CONSTANTS:
sub _type { return 'SolutionVariable'; }


__PACKAGE__->meta->make_immutable;
1;
