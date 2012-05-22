########################################################################
# ModelSEED::MS::ReactionInstance - This is the moose object corresponding to the ReactionInstance object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-26T23:22:35
########################################################################
use strict;
use ModelSEED::MS::DB::ReactionInstance;
package ModelSEED::MS::ReactionInstance;
use Moose;
use namespace::autoclean;
extends 'ModelSEED::MS::DB::ReactionInstance';
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has definition => ( is => 'rw', isa => 'Str',printOrder => '2', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_builddefinition' );
has equation => ( is => 'rw', isa => 'Str',printOrder => '3', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequation' );
has equationCode => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequationcode' );
has compartmentName => ( is => 'rw', isa => 'Str',printOrder => '5', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcompartmentName' );
has balanced => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildbalanced' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _builddefinition {
	my ($self) = @_;
	return $self->createEquation({format=>"name",hashed=>0});
}
sub _buildequation {
	my ($self) = @_;
	return $self->createEquation({format=>"id",hashed=>0});
}
sub _buildequationcode {
	my ($self,$args) = @_;
	return $self->createEquation({format=>"uuid",hashed=>1});
}
sub _buildcompartmentName {
	my ($self,$args) = @_;
	return $self->compartment()->name();
}
sub _buildbalanced {
	my ($self,$args) = @_;
	return $self->reaction()->balanced();
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
=head3 createEquation
Definition:
	string = ModelSEED::MS::ReactionInstance->createEquation({
		format => string(uuid),
		hashed => 0/1(0)
	});
Description:
	Creates an equation for the reaction instance with compounds specified according to the input format
=cut
sub createEquation {
	my ($self,$args) = @_;
	$args = ModelSEED::utilities::ARGS($args,[],{
		format => "uuid",
		hashed => 0
	});
	my $trans = $self->transports();
	my $rgt = $self->reaction->reagents();
	my $transHash;
	my $compHash;
	for (my $i=0; $i < @{$rgt}; $i++) {
		my $id = $rgt->[$i]->compound_uuid();
		if ($args->{format} eq "name" || $args->{format} eq "id") {
			my $function = $args->{format};
			$id = $rgt->[$i]->compound()->$function();
		} elsif ($args->{format} ne "uuid") {
			$id = $rgt->[$i]->compound()->getAlias($args->{format});
		}
		if ($rgt->[$i]->compartmentIndex() == 0) {
			if (!defined($transHash->{$id}->{$rgt->[$i]->compartmentIndex()})) {
				$transHash->{$id}->{$rgt->[$i]->compartmentIndex()}->{coefficient} = 0;
			}
			$transHash->{$id}->{$rgt->[$i]->compartmentIndex()}->{coefficient} += $rgt->[$i]->coefficient();
		}
	}
	for (my $i=0; $i < @{$trans}; $i++) {
		my $id = $trans->[$i]->compound_uuid();
		if ($args->{format} eq "name" || $args->{format} eq "id") {
			my $function = $args->{format};
			$id = $trans->[$i]->compound()->$function();
		} elsif ($args->{format} ne "uuid") {
			$id = $trans->[$i]->compound()->getAlias($args->{format});
		}
		if (!defined($transHash->{$id}->{$trans->[$i]->compartmentIndex()})) {
			$transHash->{$id}->{$trans->[$i]->compartmentIndex()}->{coefficient} = 0;
			$compHash->{$trans->[$i]->compartmentIndex()} = $trans->[$i]->compartment();
		}
		$transHash->{$id}->{$trans->[$i]->compartmentIndex()}->{coefficient} += $trans->[$i]->coefficient();
		$transHash->{$id}->{0}->{coefficient} += -1*$trans->[$i]->coefficient();
	}
	$compHash->{0} = $self->compartment();
	my $reactcode = "";
	my $productcode = "";
	my $sign = "<=>";
	my $sortedCpd = [sort(keys(%{$transHash}))];
	for (my $i=0; $i < @{$sortedCpd}; $i++) {
		my $indecies = [sort(keys(%{$transHash->{$sortedCpd->[$i]}}))];
		for (my $j=0; $j < @{$indecies}; $j++) {
			my $compartment = "";
			if ($compHash->{$indecies->[$j]}->id() ne "c") {
				$compartment = "[".$compHash->{$indecies->[$j]}->id()."]";
			}
			if ($transHash->{$sortedCpd->[$i]}->{$indecies->[$j]}->{coefficient} < 0) {
				my $coef = -1*$transHash->{$sortedCpd->[$i]}->{$indecies->[$j]}->{coefficient};
				if (length($reactcode) > 0) {
					$reactcode .= "+";	
				}
				$reactcode .= "(".$coef.")".$sortedCpd->[$i].$compartment;
			} elsif ($transHash->{$sortedCpd->[$i]}->{$indecies->[$j]}->{coefficient} > 0) {
				if (length($productcode) > 0) {
					$productcode .= "+";	
				}
				$productcode .= "(".$transHash->{$sortedCpd->[$i]}->{$indecies->[$j]}->{coefficient}.")".$sortedCpd->[$i].$compartment;
			} 
		}
	}
	if ($args->{hashed} == 1) {
		return Digest::MD5::md5_hex($reactcode.$sign.$productcode);
	}
	return $reactcode.$sign.$productcode;
}

# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
