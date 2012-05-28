########################################################################
# ModelSEED::MS::DB::BiomassTemplate - This is the moose object corresponding to the BiomassTemplate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::BiomassTemplate;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::BiomassTemplateComponent;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '1' );
has dna => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '2' );
has rna => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '3' );
has protein => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '4' );
has lipid => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '5' );
has cellwall => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '6' );
has cofactor => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '7' );
has energy => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '8' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomassTemplateComponents => (is => 'bare', coerce => 1, handles => { biomassTemplateComponents => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::BiomassTemplateComponent::Lazy', type => 'child(BiomassTemplateComponent)', metaclass => 'Typed');


# LINKS:


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }


# CONSTANTS:
sub _type { return 'BiomassTemplate'; }
sub _typeToFunction {
	return {
		BiomassTemplateComponent => 'biomassTemplateComponents',
	};
}


__PACKAGE__->meta->make_immutable;
1;
