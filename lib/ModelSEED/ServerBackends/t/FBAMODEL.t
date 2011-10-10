use strict;
use warnings;
use ModelSEED::TestingHelpers;
use Test::More qw(no_plan);
use Data::Dumper;
use ModelSEED::ServerBackends::FBAMODEL;
my $fbamodel = ModelSEED::ServerBackends::FBAMODEL->new();

#Testing each server function
{
    my $output = $fbamodel->get_reaction_id_list({id => ["Seed441768.4.16242"]});
	print STDERR Data::Dumper->Dump([$output]);
	ok defined($output->{"Seed441768.4.16242"}->[10]), "get_reaction_id_list not functioning!\n";
	$output = $fbamodel->get_reaction_id_list({id => ["Seed441768.4.16242"],user => "reviewer",password => "natbtech"});
	ok !defined($output) || !defined($output->{"Seed441768.4.16242"}->[10]), "get_reaction_id_list:private model access test failed!\n";
	$output = $fbamodel->get_reaction_id_list({id => ["ALL","Seed83333.1"]});
	ok !defined($output) || !defined($output->{"ALL"}->[10]) || !defined($output->{"Seed83333.1"}->[10]), "get_reaction_id_list:test failed!\n";
	$output = $fbamodel->get_reaction_data({id => $output->{"Seed83333.1"},model => ["Seed83333.1"]});
	ok !defined($output) || !defined($output->{"rxn00781"}) || !defined($output->{"rxn00781"}->{EQUATION}->[0]) || !defined($output->{"rxn00781"}->{"Seed83333.1"}->{"ASSOCIATED PEG"}->[0]), "FBAMODEL:get_reaction_data:test failed!\n";
	$output = $fbamodel->get_biomass_reaction_data({model => ["Seed83333.1"]});
	ok !defined($output) || !defined($output->{"Seed83333.1"}) || !defined($output->{"Seed83333.1"}->{EQUATION}->[0]), "FBAMODEL:get_biomass_reaction_data:test failed!\n";
	$output = $fbamodel->get_compound_id_list({id => ["ALL","Seed83333.1"]});
	ok !defined($output) || !defined($output->{"ALL"}->[10]) || !defined($output->{"Seed83333.1"}->[10]), "FBAMODEL:get_compound_id_list:test failed!\n";
	$output = $fbamodel->get_compound_data({id => $output->{"Seed83333.1"},model => ["Seed83333.1"]});
	ok !defined($output) || !defined($output->{"cpd00002"}) || !defined($output->{"cpd00002"}->{FORMULA}->[0]), "FBAMODEL:get_compound_data:test failed!\n";
	$output = $fbamodel->get_media_id_list();
	ok !defined($output) || !defined($output->[10]), "FBAMODEL:get_media_id_list:test failed!\n";
	$output = $fbamodel->get_media_data({id => $output});
	ok !defined($output) || !defined($output->{"Carbon-D-Glucose"}->{COMPOUNDS}->[0]), "FBAMODEL:get_media_data:test failed!\n";
	$output = $fbamodel->get_model_id_list();
	ok !defined($output) || !defined($output->[10]), "FBAMODEL:get_model_id_list:test failed!\n";
	$output = $fbamodel->get_model_data({"id"   => ["Seed83333.1"]});
	ok !defined($output) || !defined($output->{"Seed83333.1"}->{Name}), "FBAMODEL:get_model_data:test failed!\n";
	$output = $fbamodel->get_model_reaction_data({"id"   => "Seed83333.1"});
	ok !defined($output) || !defined($output->{"data"}->[10]->{DATABASE}->[0]), "FBAMODEL:get_model_reaction_data:test failed!\n";
	$output = $fbamodel->classify_model_entities({parameters => [{"id" => "Seed83333.1",media => "Complete",archiveResults => 0}]});
	ok !defined($output) || !defined($output->[0]->{classes}->[0]), "FBAMODEL:classify_model_entities:test failed!\n";
	$output = $fbamodel->simulate_all_single_gene_knockout({parameters => [{"id" => "Seed83333.1",media => "Complete"}]});
	ok !defined($output) || !defined($output->[0]->{"essential genes"}->[0]), "FBAMODEL:simulate_all_single_gene_knockout:test failed!\n";
	$output = $fbamodel->simulate_model_growth({parameters => [{"id" => "Seed83333.1",media => "Complete"}]});
	ok !defined($output) || !defined($output->[0]->{"fluxes"}->[0]), "FBAMODEL:simulate_model_growth:test failed!\n";
	$output = $fbamodel->get_model_reaction_classification_table({"model" => ["Seed83333.1"]});
	ok !defined($output) || !defined($output->{"Seed83333.1"}->[0]->{class}->[0]), "FBAMODEL:get_model_reaction_classification_table:test failed!\n";
	$output = $fbamodel->get_role_to_complex();
	ok !defined($output) || !defined($output->[0]->{"Functional Role"}), "FBAMODEL:get_role_to_complex:test failed!\n";
	$output = $fbamodel->get_complex_to_reaction();
	ok !defined($output) || !defined($output->[0]->{"Reaction Id"}), "FBAMODEL:get_complex_to_reaction:test failed!\n";
	$output = $fbamodel->get_model_essentiality_data({model => ["Seed83333.1"]});
	ok !defined($output) || !defined($output->{"Seed83333.1"}->{Complete}->{essential}->[0]), "FBAMODEL:get_model_essentiality_data:test failed!\n";
	$output = $fbamodel->get_experimental_essentiality_data({model => ["83333.1"]});
	ok !defined($output) || !defined($output->{"83333.1"}->{ArgonneLBMedia}->{essential}->[0]), "FBAMODEL:get_experimental_essentiality_data:test failed!\n";
	$output = $fbamodel->fba_calculate_minimal_media({model => "Seed83333.1",numFormulations => 2});
	ok !defined($output) || !defined($output->{essential}->[0]), "FBAMODEL:fba_calculate_minimal_media:test failed!\n";
	$output = $fbamodel->subsystems_of_reaction({reactions => ["rxn00781"]});
	ok !defined($output) || !defined($output->{"rxn00781"}->[0]), "FBAMODEL:subsystems_of_reaction:test failed!\n";
	$output = $fbamodel->get_metabolically_neighboring_roles({role => ["NAD-dependent glyceraldehyde-3-phosphate dehydrogenase (EC 1.2.1.12)"]});
	ok !defined($output) || !defined($output->{"cpd00102"}->[0]), "FBAMODEL:get_metabolically_neighboring_roles:test failed!\n";
	my $geneCalls;
	my $fileData = $fbamodel->figmodel()->database()->load_single_column_file($fbamodel->figmodel()->config("test function data")->[0]."GeneActivityAnalysis.dat");
	for (my $i=1; $i < @{$fileData}; $i++) {
		my @array = split(/\t/,$fileData->[$i]);
		if (@array >= 2) {
			$geneCalls->{$array[0]} = $array[1];
		}
	}
	$output = $fbamodel->fba_submit_gene_activity_analysis({model => "Seed158878.1",media => "Complete",queue => "test",geneCalls => $geneCalls});
	ok !defined($output) || !defined($output->{jobid}), "FBAMODEL:fba_submit_gene_activity_analysis:test failed!\n";
	$fbamodel->figmodel()->runTestJob($output->{jobid});
	$output = $fbamodel->fba_retreive_gene_activity_analysis({jobid => $output->{jobid}});
	ok !defined($output) || !defined($output->{On_On}->[10]), "FBAMODEL:fba_retreive_gene_activity_analysis:test failed!\n";
}
