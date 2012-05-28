########################################################################
# ModelSEED::MS::DB::Feature - This is the moose object corresponding to the Feature object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package ModelSEED::MS::DB::Feature;
use Moose;
use Moose::Util::TypeConstraints;
use ModelSEED::MS::LazyHolder::FeatureRole;
extends 'ModelSEED::MS::BaseObject';
use namespace::autoclean;


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Annotation', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid', printOrder => '0' );
has modDate => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_buildmodDate', printOrder => '-1' );
has locked => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', default => '0', printOrder => '-1' );
has id => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '1' );
has cksum => ( is => 'rw', isa => 'ModelSEED::varchar', type => 'attribute', metaclass => 'Typed', default => '', printOrder => '-1' );
has genome_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', required => 1, printOrder => '-1' );
has start => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', printOrder => '3' );
has stop => ( is => 'rw', isa => 'Int', type => 'attribute', metaclass => 'Typed', printOrder => '4' );
has contig => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '5' );
has direction => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '6' );
has sequence => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '-1' );
has type => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed', printOrder => '7' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has featureroles => (is => 'bare', coerce => 1, handles => { featureroles => 'value' }, default => sub{return []}, isa => 'ModelSEED::MS::FeatureRole::Lazy', type => 'encompassed(FeatureRole)', metaclass => 'Typed');


# LINKS:
has genome => (is => 'rw',lazy => 1,builder => '_buildgenome',isa => 'ModelSEED::MS::Genome', type => 'link(Annotation,Genome,uuid,genome_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildmodDate { return DateTime->now()->datetime(); }
sub _buildgenome {
	my ($self) = @_;
	return $self->getLinkedObject('Annotation','Genome','uuid',$self->genome_uuid());
}


# CONSTANTS:
sub _type { return 'Feature'; }
sub _typeToFunction {
	return {
		FeatureRole => 'featureroles',
	};
}


__PACKAGE__->meta->make_immutable;
1;
