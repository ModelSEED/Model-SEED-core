########################################################################
# ModelSEED::MS::DB::GapfillingGeneCandidate - This is the moose object corresponding to the GapfillingGeneCandidate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::GapfillingGeneCandidate;
use Moose;
use Moose::Util::TypeConstraints;
extends 'ModelSEED::MS::IndexedObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw', isa => 'ModelSEED::Store', type => 'parent', metaclass => 'Typed');


# ATTRIBUTES:
has reactionset_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', printOrder => '0' );
has reactionsetType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );
has multiplierType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );
has multiplier => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );




# LINKS:
has reactionset => (is => 'rw',lazy => 1,builder => '_buildreactionset',isa => 'ModelSEED::MS::Reactionset', type => 'link(Biochemistry,Reactionset,uuid,reactionset_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _buildreactionset {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Reactionset','uuid',$self->reactionset_uuid());
}


# CONSTANTS:
sub _type { return 'GapfillingGeneCandidate'; }


__PACKAGE__->meta->make_immutable;
1;
