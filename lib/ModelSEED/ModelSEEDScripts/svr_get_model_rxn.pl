
use strict;
use FBAMODELserver;
use ClientThing;

my $ServerObject = FBAMODELserver->new();

#1.) Getting the complete set of reaction IDs from the database.
my $modelList = ["Seed83333.1", "iJR904"];
my $modelReactions = $ServerObject->get_reaction_id_list({"id" => $modelList});

#2.) Finding the unique set of reaction IDs represented in the input models
my @models = keys(%{$modelReactions});
my $rxnHash;
for (my $i=0; $i < @models; $i++) {
	for (my $j=0; $j < @{$modelReactions->{$models[$i]}}; $j++) {
		$rxnHash->{$modelReactions->{$models[$i]}->[$j]} = 1;
	}
}
my $rxnList;
push(@{$rxnList},keys(%{$rxnHash}));

#3.) Getting the data for all model reactions from database
my $reactionData = $ServerObject->get_reaction_data({"id" => $rxnList,"model" => $modelList});

#4.) Printing rection data to file
open (OUTPUT, ">ReactionData.txt");
print OUTPUT "Reaction ID\tEquation";
for (my $i=0; $i < @models; $i++) {
	print OUTPUT "\t".$models[$i];
}
print OUTPUT "\n";
for (my $i=0; $i < @{$rxnList}; $i++) {
	print OUTPUT $rxnList->[$i]."\t".$reactionData->{$rxnList->[$i]}->{EQUATION}->[0];
	for (my $j=0; $j < @models; $j++) {
		if (defined($reactionData->{$rxnList->[$i]}->{$models[$j]})) {
			print OUTPUT "\t".$reactionData->{$rxnList->[$i]}->{$models[$j]}->{DIRECTIONALITY}->[0].":".join("|",@{$reactionData->{$rxnList->[$i]}->{$models[$j]}->{"ASSOCIATED PEG"}});
		} else {
			print OUTPUT "\tNot in model";
		}
		
	}
	print OUTPUT "\n";
}
close(OUTPUT);
