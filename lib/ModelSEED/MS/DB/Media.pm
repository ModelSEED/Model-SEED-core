########################################################################
# ModelSEED::MS::DB::Media - This is the moose object corresponding to the Media object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Media;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::MediaCompound;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Biochemistry', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has isDefined => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '4' );
has isMinimal => ( is => 'rw', isa => 'Bool', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '5' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '2' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => 'unknown', printOrder => '6' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has mediacompounds => (is => 'bare', coerce => 1, handles => { mediacompounds => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::MediaCompound::Lazy', type => 'encompassed(MediaCompound)', metaclass => 'Typed');


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
