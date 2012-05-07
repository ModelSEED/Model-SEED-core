########################################################################
# ModelSEED::MS::DB::Media - This is the moose object corresponding to the Media object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-05T02:39:57
########################################################################
use strict;
use ModelSEED::MS::MediaCompound;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::Media;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has isDefined => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0' );
has isMinimal => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1 );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'unknown' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has mediacompounds => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::MediaCompound]', type => 'encompassed(MediaCompound)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Media'; }
sub _typeToFunction {
	return {
		MediaCompound => 'mediacompounds',
	};
}


__PACKAGE__->meta->make_immutable;
1;
