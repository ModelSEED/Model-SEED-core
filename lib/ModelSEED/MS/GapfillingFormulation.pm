########################################################################
# ModelSEED::MS::GapfillingFormulation - This is the moose object corresponding to the GapfillingFormulation object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-05-21T20:27:15
########################################################################
use strict;
use ModelSEED::MS::DB::GapfillingFormulation;
package ModelSEED::MS::GapfillingFormulation;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::GapfillingFormulation';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 runGapfilling
Definition:
	ModelSEED::MS::GapfillingSolution = ModelSEED::MS::GapfillingFormulation->runGapfilling({});
Description:
	Runs specified gapfilling analysis on specified model
=cut
sub runGapfilling {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["coefficient","modelcompound_uuid"],{});
	for (my $i=0; $i < @{$self->modelReactionReagents()}; $i++) {
		if ($self->modelReactionReagents()->[$i]->modelcompound_uuid() eq $args->{modelcompound_uuid}) {
			return $self->modelReactionReagents()->[$i];
		}
	}
	my $mdlrxnrgt = $self->create("ModelReactionReagent",{
		coefficient => $args->{coefficient},
		modelcompound_uuid => $args->{modelcompound_uuid}
	});
	return $mdlrxnrgt;
}


__PACKAGE__->meta->make_immutable;
1;
