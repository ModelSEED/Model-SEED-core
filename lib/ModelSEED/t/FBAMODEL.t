use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use ModelSEED::FBAMODEL;

my $fba = ModelSEED::FBAMODEL->new();
# test get_reaction_list 
#{ 
    #delete $fba->figmodel()->{_user_account};
    #my $rxns = $fba->get_reaction_id_list({id => ["Seed441768.4.16242"]});
    #ok(not defined($rxns), "get no reactions from private model that we don't own");
	#$rxns = $fba->get_reaction_id_list({id => ["Seed441768.4.16242"],
    #    user => "reviewer", password => "reviewer"});
    #ok @$rxns gt 0, "get reactions for private model that we authenticated";
    #$rxns = $fba->get_reaction_id_list({id => ["Seed83333.1"]});
    #ok @$rxns gt 0, "get reactions for public model";
    #$rxns = $fba->get_reaction_id_list({id => ["ALL"]});
    #ok @$rxns gt 0, "get reactions for keyword 'ALL'";
        
#}

# test fba_submit_gene_activity_analysis
#{
#    my $job = $fba->fba_submit_gene_activity_analysis(
#        { 'model' => "Seed158878.1",
#          'media' => 'Complete', 'queue' => "test",
#        }); 
#    ok defined $job, "making sure job exists";
#    ok defined $job->{jobid}, "job has jobid";
#    $fba->figmodel()->runTestJob($job->{jobid});
#    my $results = $fba->fba_retrive_gene_activity_analysis({jobid => $job->{jobid}});
#    ok defined $results, "got results from job";
#    ok defined $results->{On_On}, "Got on_on calls";
#
#} 

# test media functions

{
    my $all_ids = $fba->get_media_id_list();
    ok ref($all_ids) eq "ARRAY", "get_media_id_list did not return an array of ids!";
    my $all_media_info = $fba->get_media_data({"id" => "ALL"});
    #ok scalar(@$all_ids) == scalar(keys %$all_media_info), "get_media_data on ALL did not return entries for every media in get_media_id_list!";
    my $number_one = $all_media_info->{(keys %$all_media_info)[0]};
    ok defined($number_one->{"Compounds"}) && defined($number_one->{"Min"}) && defined($number_one->{"Max"}) && defined($number_one->{"Compartments"}),
        "get_media_data is not returning the correct media object for each entry!";
    ok ref($number_one->{"Compounds"}) eq 'ARRAY', "get_media_data is not returning array refs for the attributes of the media object!";
    ok ref($number_one->{"Max"}) eq 'ARRAY', "get_media_data is not returning array refs for the attributes of the media object!";
    ok ref($number_one->{"Min"}) eq 'ARRAY', "get_media_data is not returning array refs for the attributes of the media object!";
    ok ref($number_one->{"Compartments"}) eq 'ARRAY', "get_media_data is not returning array refs for the attributes of the media object!";
    ok scalar(@{$number_one->{"Compounds"}}) == scalar(@{$number_one->{"Max"}}), 
        "get_media_data is returning a different number of entries for each attribute in the media object!";
    ok scalar(@{$number_one->{"Min"}}) == scalar(@{$number_one->{"Max"}}), 
        "get_media_data is returning a different number of entries for each attribute in the media object!";
    ok scalar(@{$number_one->{"Compartments"}}) == scalar(@{$number_one->{"Max"}}), 
        "get_media_data is returning a different number of entries for each attribute in the media object!";
}

# test abstract reaction functions
{ 
    # save group that we'll test on
    my $savedGrp = $fba->get_abstract_reaction_group({'grouping' => 'rxn06803'});
    my $tmpGrp = {'grouping' => 'rxn06803',
                  'reactions' => ['rxn07949', 'rxn07951', 'rxn07961',
                                  'rxn07964', 'rxn07966', 'rxn07950',
                                  'rxn07946', 'rxn07960', 'rxn07952',
                                  'rxn07962', 'rxn07948', 'rxn07963',
                                  'rxn07947', 'rxn07965',
                 ]};
    # set it to something different
    my $newGrp = $fba->set_abstract_reaction_group({ group => $tmpGrp });
    # test return value, test group-list
    ok(scalar(@{$tmpGrp->{'reactions'}}) == scalar(@{$newGrp->{'reactions'}}), "group has correct number of reactions");
    ok(defined $newGrp->{'grouping'}, "group has grouping defined");
    my $grpList = $fba->get_abstract_reaction_groups();
    ok(defined($grpList)&& ref($grpList) eq 'ARRAY', "get_abstract_reaction_groups returns array type");
    my %grpListHash = map { $_->{'grouping'} => $_ } @$grpList;
    ok(defined($grpListHash{$tmpGrp->{'grouping'}}), "setting new group appears in whole groups list");
    
    {
        # set group to empty
        my $newGrp2 = $fba->set_abstract_reaction_group({ group => { grouping => $tmpGrp->{grouping}}});
        my $getGrp2 = $fba->get_abstract_reaction_group({'grouping' => $tmpGrp->{grouping}});
        ok @{$newGrp2->{reactions}} == 0, "reaction count > zero after deletion happens.";
        ok(@{$newGrp2->{reactions}} == @{$getGrp2->{reactions}}, "not the same number of reactions when deleting group");
        my $grpList2 = $fba->get_abstract_reaction_groups();
        my %grpListHash2 = map { $_->{'grouping'} => $_ } @$grpList2;
        ok(!defined($grpListHash2{$tmpGrp->{grouping}}), "deleted group isn't removed from list");
        
    }
    # set group to old value
    my $savedGrp2 = $fba->set_abstract_reaction_group({group => $savedGrp});
    ok(@{$savedGrp2->{reactions}} == @{$savedGrp->{reactions}}, "not same number of reactions as before test");
    ok($savedGrp2->{grouping} eq $savedGrp->{grouping}, "not same grouping as before test");
}
    
