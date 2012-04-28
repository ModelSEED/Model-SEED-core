########################################################################
# ModelSEED::MS::DB::BiomassTemplate - This is the moose object corresponding to the BiomassTemplate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-04-28T22:59:34
########################################################################
use strict;
use ModelSEED::MS::BiomassTemplateComponent;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::BiomassTemplate;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Mapping', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, lazy => 1, builder => '_builduuid' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate' );
has class => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', default => '0' );
has dna => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );
has rna => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );
has protein => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );
has lipid => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );
has cellwall => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );
has cofactor => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed', default => '0' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has biomassTemplateComponents => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::BiomassTemplateComponent]', type => 'child(BiomassTemplateComponent)', metaclass => 'Typed');


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
