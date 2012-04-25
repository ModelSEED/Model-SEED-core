########################################################################
# ModelSEED::MS::DB::Modelfba - This is the moose object corresponding to the Modelfba object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::FBAObjectiveTerm;
use ModelSEED::MS::GeneKO;
use ModelSEED::MS::DrainConstraint;
use ModelSEED::MS::ReactionConstraint;
use ModelSEED::MS::UptakeLimit;
use ModelSEED::MS::FBASolution;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Modelfba;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Model', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has expressionData_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has model_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has regulatorymodel_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has growthConstraint => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has thermodynamicConstraints => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has allReversible => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has numberOfSolutions => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1' );
has resultNotes => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has objectiveValue => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has variableTypes => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => 'CODE(0x12c06bc)' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBAObjectiveTerm]', type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed');
has geneKO => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::GeneKO]', type => 'encompassed(GeneKO)', metaclass => 'Typed');
has drainConstraints => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::DrainConstraint]', type => 'encompassed(DrainConstraint)', metaclass => 'Typed');
has reactionConstraints => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ReactionConstraint]', type => 'encompassed(ReactionConstraint)', metaclass => 'Typed');
has uptakeLimits => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::UptakeLimit]', type => 'encompassed(UptakeLimit)', metaclass => 'Typed');
has fbaSolutions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBASolution]', type => 'encompassed(FBASolution)', metaclass => 'Typed');


# LINKS:
has media => (is => 'rw',lazy => 1,builder => '_buildmedia',isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,Media,uuid,media_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildmedia {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Media','uuid',$self->media_uuid());
}


# CONSTANTS:
sub _type { return 'Modelfba'; }
sub _typeToFunction {
	return {
		FBAObjectiveTerm => 'fbaObjectiveTerms',
		FBASolution => 'fbaSolutions',
		ReactionConstraint => 'reactionConstraints',
		GeneKO => 'geneKO',
		DrainConstraint => 'drainConstraints',
		UptakeLimit => 'uptakeLimits',
	};
}


__PACKAGE__->meta->make_immutable;
1;
