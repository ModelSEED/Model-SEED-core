########################################################################
# ModelSEED::MS::DB::Strain - This is the moose object corresponding to the Strain object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Strain;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::Deletion;
use ModelSEED::MS::LazyHolder::Insertion;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Genome', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );
has source => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '0' );
has class => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has deletions => (is => 'bare', coerce => 1, handles => { deletions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Deletion::Lazy', type => 'child(Deletion)', metaclass => 'Typed');
has insertions => (is => 'bare', coerce => 1, handles => { insertions => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::Insertion::Lazy', type => 'child(Insertion)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Strain'; }
sub _typeToFunction {
	return {
		Insertion => 'insertions',
		Deletion => 'deletions',
	};
}


__PACKAGE__->meta->make_immutable;
1;
