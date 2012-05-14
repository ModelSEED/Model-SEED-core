########################################################################
# ModelSEED::MS::DB::Biomass - This is the moose object corresponding to the Biomass object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Biomass;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::BiomassCompound;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Model', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0' );
has name => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '' );
has dna => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.05' );
has rna => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.1' );
has protein => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.5' );
has cellwall => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.15' );
has lipid => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.05' );
has cofactor => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0.15' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomasscompounds => (is => 'bare', coerce => 1, handles => { biomasscompounds => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::BiomassCompound::Lazy', type => 'encompassed(BiomassCompound)', metaclass => 'Typed');


# LINKS:
has id => (is => 'rw',lazy => 1,builder => '_buildid',isa => 'Str', type => 'id', metaclass => 'Typed');


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'Biomass'; }
sub _typeToFunction {
	return {
		BiomassCompound => 'biomasscompounds',
	};
}
sub _aliasowner { return 'Model'; }


__PACKAGE__->meta->make_immutable;
1;
