use strict;
package ModelSEED::MS::Utilities::GlobalFunctions;

=head3 convertRoleToSearchRole
Definition:
	string searchName = convertRoleToSearchRole->(string roleName);
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

1;
