use strict;
package ModelSEED::MS::Utilities::GlobalFunctions;

=head3 convertRoleToSearchRole
Definition:
	string:searchrole = ModelSEED::MS::Utilities::GlobalFunctions::convertRoleToSearchRole->(string rolename);
Description:
	Converts the input role name into a search name by removing spaces, capitalization, EC numbers, and some punctuation.
=cut
sub convertRoleToSearchRole {
	my ($rolename) = @_;
	$rolename = lc($rolename);
	$rolename =~ s/[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+//g;
	$rolename =~ s/\s//g;
	$rolename =~ s/#.*//;
	return $rolename;
}
=head3 functionToRoles
Definition:
	Output = ModelSEED::MS::Utilities::GlobalFunctions::functionToRoles->(string function);
	Output = {
		roles => [string],
		delimiter => [string],
		compartment => string,
		comment => string
	};
Description:
	Converts a functional annotation from the seed into a set of roles, a delimiter, a comment, and a compartment.
=cut
sub functionToRoles {
	my ($function) = @_;
	my $output = {
		roles => [],
		delimiter => "none",
		compartments => ["u"],
		comment => "none"	
	};
	my $compartmentTranslation = {
		"cytosolic" => "c",
		"plastidial" => "t",
		"mitochondrial" => "m",
		"peroxisomal" => "x",
		"lysosomal" => "l",
		"vacuolar" => "v",
		"nuclear" => "n",
		"plasma\\smembrane" => "p",
		"cell\\swall" => "w",
		"golgi\\sapparatus" => "g",
		"endoplasmic\\sreticulum" => "e"
	};
	if ($function =~ /#(.*)$/) {
		$output->{comment} = $1;
		foreach my $comp (keys(%{$compartmentTranslation})) {
			if ($output->{comment} =~ /$comp/) {
				if ($output->{compartments}->[0] eq "u") {
					$output->{compartments} = [];
				}
				push(@{$output->{compartments}},$compartmentTranslation->{$comp});
			}
		}
	}
	if ($function =~ /\s*;\s/) {
		$output->{delimiter} = ";";
	}
	if ($function =~ /s+\@\s+/) {
		$output->{delimiter} = "\@";
	}
	if ($function =~ /s+\/\s+/) {
		$output->{delimiter} = "/";
	}
	$output->{roles} = [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
	return $output;
}

1;
