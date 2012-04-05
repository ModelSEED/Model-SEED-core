########################################################################
# ModelSEED::MS::Biochemistry - This moose object stores data on user environment
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-18
########################################################################
use strict;
package ModelSEED::MS::Environment;
use Moose;
use namespace::autoclean;

# ATTRIBUTES:
has username => ( is => 'rw', isa => 'Str');
has password => ( is => 'rw', isa => 'Str');
has registeredseed => ( is => 'rw', isa => 'HashRef',default => sub{return {};});
has seed => ( is => 'rw', isa => 'Str',default => 'local' );
has lasterror => ( is => 'rw', isa => 'ModelSEED::varchar',default => "NONE");
has filename => ( is => 'rw', isa => 'ModelSEED::varchar',default => "NONE");


# CONSTANTS:
sub _type { return 'Environment'; }


# FUNCTIONS:
sub logout {
	my ($self) = @_;
	$self->username("public");
	$self->password("public");
	$self->save();
}
sub save {
	my ($self) = @_;
	if (!defined($self->filename())) {
		ModelSEED::utilities::ERROR("Cannot save environment without environment filename!");
	}
	my $variables = ["username","password","seed","lasterror"];
	my $output = ["SETTING\tVALUE"];
	for (my $i=0; $i < @{$variables}; $i++) {
		my $function = $variables->[$i];
		push(@{$output},$function."\t".$self->$function());
	}
	my $seeddata = "NONE";
	if (keys(%{$self->registeredseed()}) > 0) {
		foreach my $seedid (keys(%{$self->registeredseed()})) {
			if ($seeddata eq "NONE") {
				$seeddata = $seedid.":".$self->registeredseed()->{$seedid};
			} else {
				$seeddata .= ";".$seedid.":".$self->registeredseed()->{$seedid};
			}
		}
	}
	push(@{$output},"REGISTEREDSEED\t".$seeddata);
	ModelSEED::utilities::PRINTFILE($self->filename(),$output);
}


__PACKAGE__->meta->make_immutable;
1;
