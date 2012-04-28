########################################################################
# ModelSEED::MS::DB::FBAFormulation - This is the moose object corresponding to the FBAFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:33
########################################################################
use strict;
use ModelSEED::MS::FBAObjectiveTerm;
use ModelSEED::MS::FBACompoundConstraint;
use ModelSEED::MS::FBAReactionConstraint;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::FBAFormulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::model_uuid', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );
has model_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has regulatorymodel_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1 );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '' );
has expressionData_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has growthConstraint => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => 'none' );
has thermodynamicConstraints => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => 'none' );
has allReversible => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has uptakeLimits => ( is => 'rw', isa => 'HashRef', type => 'attribute', metaclass => 'Typed', default => 'sub{return {};}' );
has numberOfSolutions => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', required => 1, default => '1' );
has geneKO => ( is => 'rw', isa => 'ArrayRef', type => 'attribute', metaclass => 'Typed', required => 1, default => 'sub{return [];}' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBAObjectiveTerm]', type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed');
has fbaCompoundConstraints => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBACompoundConstraint]', type => 'encompassed(FBACompoundConstraint)', metaclass => 'Typed');
has fbaReactionConstraints => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBAReactionConstraint]', type => 'encompassed(FBAReactionConstraint)', metaclass => 'Typed');


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
sub _type { return 'FBAFormulation'; }
sub _typeToFunction {
	return {
		FBAObjectiveTerm => 'fbaObjectiveTerms',
		FBAReactionConstraint => 'fbaReactionConstraints',
		FBACompoundConstraint => 'fbaCompoundConstraints',
	};
}


__PACKAGE__->meta->make_immutable;
1;
