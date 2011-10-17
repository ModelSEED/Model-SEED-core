use strict;
use warnings;
use lib '../../../../config/';
use ModelSEEDbootstrap;
use ModelSEED::TestingHelpers;
use Test::More qw(no_plan);
use Data::Dumper;
use ModelSEED::ServerBackends::FBAMODEL;

#my $helper = ModelSEED::TestingHelpers->new();
#my $fm = $helper->getDebugFIGMODEL();
#my $fbamodel = ModelSEED::ServerBackends::FBAMODEL->new({figmodel => $fm});
my $fbamodel = ModelSEED::ServerBackends::FBAMODEL->new();

#Testing each server function
{
    my $pubmodel = "iJR904";
    my $privatemodel = "iJR904.796";
    my $media = "Carbon-D-Glucose";
    my $genome = "83333.1";
	my $output = $fbamodel->get_reaction_id_list({id => ["ALL",$pubmodel]});
    my $rxn = $output->{$pubmodel}->[0];
	ok defined($rxn), "get_reaction_id_list for public model ".$pubmodel.
        " should return at least 1 reaction, got ". scalar(@{$output->{$pubmodel}});
    $rxn = $output->{"ALL"}->[0];
    ok defined($rxn), "get_reaction_id_list for entire database".
        " should return at least 1 reaction, got ". scalar(@{$output->{"ALL"}});
	$output = $fbamodel->get_reaction_id_list({id => [$privatemodel],user => "chenry",password => "Ko3BA9yMnMj2k"});
	$rxn = $output->{$privatemodel}->[0];
	ok defined($rxn), "get_reaction_id_list for private model ".$privatemodel.
        " should return at least 1 reaction, got ". scalar(@{$output->{$privatemodel}});
	$output = $fbamodel->get_reaction_data({id => $output->{$privatemodel},model => [$privatemodel],user => "chenry",password => "Ko3BA9yMnMj2k"});
	$rxn = $output->{"rxn00781"};
	ok defined($rxn->{$privatemodel}->{"ASSOCIATED PEG"}->[0]), "get_reaction_data for private model ".$privatemodel.
        " should return model data for rxn00781 , got ". $rxn->{$privatemodel}->{"ASSOCIATED PEG"}->[0];
	ok defined($rxn->{EQUATION}->[0]), "get_reaction_data for private model ".$privatemodel.
        " should return equation for rxn00781 , got ". $rxn->{EQUATION}->[0];
	$output = $fbamodel->get_biomass_reaction_data({model => [$pubmodel]});
	$rxn = $output->{$pubmodel};
	ok defined($rxn->{EQUATION}->[0]), "get_biomass_reaction_data for public model ".$pubmodel.
        " should return equation for biomass reaction , got ". $rxn->{EQUATION}->[0];
	$output = $fbamodel->get_compound_id_list({id => ["ALL",$pubmodel]});
	my $cpd = $output->{$pubmodel}->[0];
	ok defined($cpd), "get_compound_id_list for public model ".$pubmodel.
        " should return at least 1 compound, got ". scalar(@{$output->{$pubmodel}});
    $cpd = $output->{"ALL"}->[0];
    ok defined($cpd), "get_compound_id_list for entire database".
        " should return at least 1 compound, got ". scalar(@{$output->{"ALL"}});
	$output = $fbamodel->get_compound_data({id => $output->{$pubmodel}});
	$cpd = $output->{"cpd00002"};
	ok defined($cpd->{FORMULA}->[0]), "get_compound_data for public model ".$pubmodel.
        " should return compound formula, got ". $cpd->{FORMULA}->[0];
	$output = $fbamodel->get_media_id_list();
	ok defined($output->[10]), "get_media_id_list for entire database".
        " should return at least 10 media formulations, got ". scalar(@{$output});
	$output = $fbamodel->get_media_data({id => $output});
	my $mediaObj = $output->{$media};
	ok defined($mediaObj->{Compounds}->[5]), "get_media_data for ".$media.
		 " should return at least 5 compounds, got ". scalar(@{$mediaObj->{Compounds}});
	$output = $fbamodel->get_model_id_list();
	ok defined($output->[0]), "get_model_id_list for database".
        " should return at least 1 model, got ". scalar(@{$output});
	$output = $fbamodel->get_model_data({"id" => [$pubmodel]});
	ok defined($output->{$pubmodel}->{Name}), "get_model_data for ".$pubmodel.
        " should return model name, got ". $output->{$pubmodel}->{Name};
    $output = $fbamodel->get_role_to_complex();
	ok defined($output->[0]->{"Functional Role"}), "get_role_to_complex for database".
        " should return at least one functional role, got ". $output->[0]->{"Functional Role"};
	$output = $fbamodel->get_complex_to_reaction();
	ok defined($output->[0]->{"Reaction Id"}), "get_complex_to_reaction for database".
        " should return at least one reaction, got ". $output->[0]->{"Reaction Id"};
	$output = $fbamodel->subsystems_of_reaction({reactions => ["rxn00781"]});
	ok defined($output->{"rxn00781"}->[0]), "subsystems_of_reaction for database".
        " should return at least one subsystem, got ". scalar(@{$output->{"rxn00781"}});
    $output = $fbamodel->get_subsystem_data({ids => ["ss00001"]});
	ok defined($output->{"ss00001"}->{NAME}->[0]), "get_subsystem_data for ss00001".
        " should return a subsystem name, got ". $output->{"ss00001"}->{NAME}->[0];
    $output = $fbamodel->classify_model_entities({parameters => [{"id" => $pubmodel,media => "Complete",archiveResults => 1}]});
	ok defined($output->[0]->{classes}->[10]), "classify_model_entities for public model ".$pubmodel.
        " should return at least 10 entity classes, got ". scalar(@{$output->[0]->{classes}});
    $output = $fbamodel->get_model_reaction_classification_table({"model" => [$pubmodel]});
	ok defined($output->{$pubmodel}->[0]->{class}->[0]), "get_model_reaction_classification_table for model ".$pubmodel.
        " should return classification data for at least one reaction, got ". $output->{$pubmodel}->[0]->{class}->[0];
	$output = $fbamodel->model_build({id => "83333.1",overwrite => 1,user => "chenry",password => "Ko3BA9yMnMj2k"});
	ok defined($output->{"83333.1"}), "model_build for genome 83333.1".
        " should return a success message, got ". $output->{"83333.1"};
	exit();
	$output = $fbamodel->get_model_essentiality_data({model => [$pubmodel]});
	ok defined($output->{$pubmodel}->{Complete}->{essential}->[0]), "get_model_essentiality_data for model ".$pubmodel.
        " should return essentiality data for at least one gene, got ". scalar(@{$output->{$pubmodel}->{Complete}->{essential}});
	$output = $fbamodel->metabolic_neighborhood_of_roles({ids => ["NAD-dependent glyceraldehyde-3-phosphate dehydrogenase (EC 1.2.1.12)"]});
	ok defined($output->{"cpd00102"}->[0]), "get_metabolically_neighboring_roles for database".
        " should return at least one reaction, got ". scalar(@{$output->{"cpd00102"}});
	$output = $fbamodel->get_model_reaction_data({"id"   => $pubmodel});
	ok defined($output->{data}->[10]->{DATABASE}->[0]), "get_model_reaction_data for ".$pubmodel.
        " should return data for at least 10 reactions, got ". scalar(@{$output->{data}});
	$output = $fbamodel->get_experimental_essentiality_data({genome => [$genome]});
	ok defined($output->{$genome}->{ArgonneLBMedia}->{essential}->[0]), "get_experimental_essentiality_data for genome ".$genome.
        " should return essentiality data for at least one gene, got ". scalar(@{$output->{$genome}->{ArgonneLBMedia}->{essential}});
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
	$output = $fbamodel->simulate_all_single_gene_knockout({parameters => [{"id" => "Seed83333.1",media => "Complete"}]});
	ok !defined($output) || !defined($output->[0]->{"essential genes"}->[0]), "FBAMODEL:simulate_all_single_gene_knockout:test failed!\n";
	$output = $fbamodel->simulate_model_growth({parameters => [{"id" => "Seed83333.1",media => "Complete"}]});
	ok !defined($output) || !defined($output->[0]->{"fluxes"}->[0]), "FBAMODEL:simulate_model_growth:test failed!\n";
	$output = $fbamodel->fba_calculate_minimal_media({model => "Seed83333.1",numFormulations => 2});
	ok !defined($output) || !defined($output->{essential}->[0]), "FBAMODEL:fba_calculate_minimal_media:test failed!\n";
}
=cut
