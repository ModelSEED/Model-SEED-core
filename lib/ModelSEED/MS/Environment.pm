########################################################################
# ModelSEED::MS::Biochemistry - This moose object stores data on user environment
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2012-03-18
########################################################################
use strict;
use ModelSEED::utilities;
package ModelSEED::MS::Environment;
use Moose;
use namespace::autoclean;

# ATTRIBUTES:
has username => ( is => 'rw', isa => 'Str',default => "public");
has password => ( is => 'rw', isa => 'Str',default => "public");
has registeredSEED => ( is => 'rw', isa => 'HashRef',default => sub{return {};});
has seed => ( is => 'rw', isa => 'Str',default => 'local' );
has lasterror => ( is => 'rw', isa => 'ModelSEED::varchar',default => "NONE");
has filename => ( is => 'rw', isa => 'ModelSEED::varchar',default => ModelSEED::utilities::MODELSEEDCORE()."/config/newenvironment.dat");
has db_type => ( is => 'rw', isa => 'Str', default => 'FileDB' );
has db_config => ( is => 'rw', isa => 'HashRef', default => sub {
    return {
	directory => ModelSEED::utilities::MODELSEEDCORE()."/data/filedb/"
    }
});
has selectedAliases => ( is => 'rw', isa => 'HashRef',default => sub{
	return {
		ReactionAliasSet => "ModelSEED",
		CompoundAliasSet => "ModelSEED",
		ComplexAliasSet => "ModelSEED",
		RoleAliasSet => "ModelSEED",
		RoleSetAliasSet => "ModelSEED"
	};
});
has biochemistry => ( is => 'rw', isa => 'ModelSEED::uuid');
has mapping => ( is => 'rw', isa => 'ModelSEED::uuid');

# BUILDER:
sub BUILD {
	my ($self) = @_;
	if (defined($self->filename()) && -e $self->filename() && !defined($self->username())) {
		$self->load();
	}
}

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
	my $variables = {
		username => "s",
		password => "s",
		seed => "s",
		lasterror => "s",
		mapping => "s",
		biochemistry => "s",
		registeredSEED => "h",
		selectedAliases => "h"
	};
	my $output = ["SETTING\tVALUE"];
	foreach my $var (keys(%{$variables})) {
		my $function = $var;
		if ($variables->{$var} eq "s") {
			push(@{$output},$var."\t".$self->$function());
		} elsif ($variables->{$var} eq "h") {
			my $seeddata = "{";
			foreach my $seedid (keys(%{$self->$function()})) {
				if (length($seeddata) > 1) {
					$seeddata .= ",";
				}
				$seeddata .= $seedid."=".$self->$function()->{$seedid};
			}
			$seeddata .= "}";
			push(@{$output},$var."\t".$seeddata);
		}
	}
	ModelSEED::utilities::PRINTFILE($self->filename(),$output);
}
sub load {
	my ($self) = @_;
	if (!defined($self->filename()) || !-e $self->filename()) {
		ModelSEED::utilities::ERROR("Cannot load environment filename!");
	}
	my $data = ModelSEED::utilities::LOADFILE($self->filename());
	my $variables = {
		username => "s",
		password => "s",
		seed => "s",
		lasterror => "s",
		mapping => "s",
		biochemistry => "s",
		registeredSEED => "h",
		selectedAliases => "h"
	};
	$self->registeredSEED({});
	for (my $i=1; $i < @{$data}; $i++) {
		my $array = [split(/\t/,$data->[$i])];
		if (defined($array->[1]) && defined($variables->{$array->[0]})) {
			my $function = $array->[0];
			if ($variables->{$array->[0]} eq "s") {
				$self->$function($array->[1]);
			} elsif ($variables->{$array->[0]} eq "h") {
				$array->[1] =~ s/[\{\}]//g;
				my $newarray = [split(/,/,$array->[1])];
				for (my $j=1; $j < @{$newarray}; $j++) {
					my $item = [split(/=/,$newarray->[$j])];
					if (defined($item->[1])) {
						$self->$function()->{$item->[0]} = $item->[1];
					}
				}
			}
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
