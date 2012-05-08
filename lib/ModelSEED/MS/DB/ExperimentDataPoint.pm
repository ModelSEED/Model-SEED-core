########################################################################
# ModelSEED::MS::DB::ExperimentDataPoint - This is the moose object corresponding to the ExperimentDataPoint object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use ModelSEED::MS::FluxMeasurement;
use ModelSEED::MS::UptakeMeasurement;
use ModelSEED::MS::MetaboliteMeasurement;
use ModelSEED::MS::GeneMeasurement;
use ModelSEED::MS::BaseObject;
package ModelSEED::MS::DB::ExperimentDataPoint;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::BaseObject';


# PARENT:
has parent => (is => 'rw',isa => 'ModelSEED::MS::Experiment', type => 'parent', metaclass => 'Typed',weak_ref => 1);


# ATTRIBUTES:
has uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed', lazy => 1, builder => '_builduuid' );
has strain_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has media_uuid => ( is => 'rw', isa => 'ModelSEED::uuid', type => 'attribute', metaclass => 'Typed' );
has pH => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has temperature => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has buffers => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has phenotype => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has notes => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );
has growthMeasurement => ( is => 'rw', isa => 'Num', type => 'attribute', metaclass => 'Typed' );
has growthMeasurementType => ( is => 'rw', isa => 'Str', type => 'attribute', metaclass => 'Typed' );


# ANCESTOR:
has ancestor_uuid => (is => 'rw',isa => 'uuid', type => 'acestor', metaclass => 'Typed');


# SUBOBJECTS:
has fluxMeasurements => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::FluxMeasurement]', type => 'child(FluxMeasurement)', metaclass => 'Typed');
has uptakeMeasurements => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::UptakeMeasurement]', type => 'child(UptakeMeasurement)', metaclass => 'Typed');
has metaboliteMeasurements => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::MetaboliteMeasurement]', type => 'child(MetaboliteMeasurement)', metaclass => 'Typed');
has geneMeasurements => (is => 'rw',default => sub{return [];},isa => 'ArrayRef|ArrayRef[ModelSEED::MS::GeneMeasurement]', type => 'child(GeneMeasurement)', metaclass => 'Typed');


# LINKS:
has strain => (is => 'rw',lazy => 1,builder => '_buildstrain',isa => 'ModelSEED::MS::Strain', type => 'link(Genome,Strain,uuid,strain_uuid)', metaclass => 'Typed',weak_ref => 1);
has media => (is => 'rw',lazy => 1,builder => '_buildmedia',isa => 'ModelSEED::MS::Media', type => 'link(Biochemistry,Media,uuid,media_uuid)', metaclass => 'Typed',weak_ref => 1);


# BUILDERS:
sub _builduuid { return Data::UUID->new()->create_str(); }
sub _buildstrain {
	my ($self) = @_;
	return $self->getLinkedObject('Genome','Strain','uuid',$self->strain_uuid());
}
sub _buildmedia {
	my ($self) = @_;
	return $self->getLinkedObject('Biochemistry','Media','uuid',$self->media_uuid());
}


# CONSTANTS:
sub _type { return 'ExperimentDataPoint'; }
sub _typeToFunction {
	return {
		UptakeMeasurement => 'uptakeMeasurements',
		FluxMeasurement => 'fluxMeasurements',
		GeneMeasurement => 'geneMeasurements',
		MetaboliteMeasurement => 'metaboliteMeasurements',
	};
}


__PACKAGE__->meta->make_immutable;
1;
