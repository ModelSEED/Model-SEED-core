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
# ADDITIONAL ATTRIBUTES:
has equation => ( is => 'rw', isa => 'Str', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildequation' );

# BUILDERS:
sub _buildequation {
	my ($self) = @_;
	my $reactants = "";
	my $products = "";
	my $cpdhash;
	my $trans;
	my $reagents = $self->reagents();
	for (my $i=0; $i < @{$reagents}; $i++) {
		if (!defined($cpdhash->{$reagents->[$i]->compound_uuid()})) {
			$cpdhash->{$reagents->[$i]->compound_uuid()} = 0;
		}
		if ($reagents->[$i]->compartmentIndex() == 0) {
			$cpdhash->{$reagents->[$i]->compound_uuid()} += $reagents->[$i]->coefficient();
		} else {
			$cpdhash->{$reagents->[$i]->compound_uuid()} += -1*$reagents->[$i]->coefficient();
			$trans->{$reagents->[$i]->compound_uuid()}->[$reagents->[$i]->compartmentIndex()] += $reagents->[$i]->coefficient();
		}
	}
	my $sortedcpd = [sort(keys(%{$cpdhash}))];
	for (my $i=0; $i < @{$sortedcpd}; $i++) {
		if ($cpdhash->{$sortedcpd->[$i]} < 0) {
			if (length($reactants) > 0) {
				$reactants .= " + ";
			}
			$reactants .= "(".-1*$cpdhash->{$sortedcpd->[$i]}.") ".$sortedcpd->[$i];
		} elsif ($cpdhash->{$sortedcpd->[$i]} > 0) {
			if (length($products) > 0) {
				$products .= " + ";
			}
			$products .= "(".$cpdhash->{$sortedcpd->[$i]}.") ".$sortedcpd->[$i];
		}
		if (defined($trans->{$sortedcpd->[$i]})) {
			for (my $j=0; $j < @{$trans->{$sortedcpd->[$i]}}; $j++) {
				if (defined($trans->{$sortedcpd->[$i]}->[$j]) && $trans->{$sortedcpd->[$i]}->[$j] < 0) {
					if (length($reactants) > 0) {
						$reactants .= " + ";
					}
					$reactants .= "(".-1*$trans->{$sortedcpd->[$i]}->[$j].") ".$sortedcpd->[$i]."[".$j."]";
				} elsif (defined($trans->{$sortedcpd->[$i]}->[$j]) && $trans->{$sortedcpd->[$i]}->[$j] > 0) {
					if (length($products) > 0) {
						$products .= " + ";
					}
					$products .= "(".$trans->{$sortedcpd->[$i]}->[$j].") ".$sortedcpd->[$i]."[".$j."]";
				}	
			}
		}
	}
	return $reactants." <=> ".$products
}

# CONSTANTS:
#TODO
# FUNCTIONS:
#TODO


__PACKAGE__->meta->make_immutable;
1;
