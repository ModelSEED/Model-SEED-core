########################################################################
# ModelSEED::MS::DB::FBASolution - This is the moose object corresponding to the FBASolution object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-24T02:58:25
########################################################################
use strict;
use ModelSEED::MS::FBAObjectiveTerm;
use ModelSEED::MS::ModelfbaCompound;
use ModelSEED::MS::ModelfbaReaction;
use ModelSEED::MS::ModelfbaFeature;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::FBASolution;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Modelfba', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has description => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has objectiveValue => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', required => 1, default => '' );




# SUBOBJECTS:
has fbaObjectiveTerms => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FBAObjectiveTerm]', type => 'encompassed(FBAObjectiveTerm)', metaclass => 'Typed');
has modelfbaCompounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaCompound]', type => 'encompassed(ModelfbaCompound)', metaclass => 'Typed');
has modelfbaReactions => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaReaction]', type => 'encompassed(ModelfbaReaction)', metaclass => 'Typed');
has modelfbaFeatures => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::ModelfbaFeature]', type => 'encompassed(ModelfbaFeature)', metaclass => 'Typed');


# LINKS:


# BUILDERS:


# CONSTANTS:
sub _type { return 'FBASolution'; }
sub _typeToFunction {
	return {
		ModelfbaCompound => 'modelfbaCompounds',
		FBAObjectiveTerm => 'fbaObjectiveTerms',
		ModelfbaReaction => 'modelfbaReactions',
		ModelfbaFeature => 'modelfbaFeatures',
	};
}


__PACKAGE__->meta->make_immutable;
1;
