#
#===============================================================================
#
#         FILE:  data-import.t
#
#  DESCRIPTION:  Test helper routines in continuous data import
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Dr. Fritz Mehner (mn), mehner@fh-swf.de
#      COMPANY:  FH Südwestfalen, Iserlohn
#      VERSION:  1.0
#      CREATED:  01/25/12 12:08:16
#     REVISION:  ---
#===============================================================================
use Test::More;
use strict;
use warnings;
use Data::Dumper;
use ModelSEED::ModelSEEDScripts::ContinuousDataImporter;
my $importer = ModelSEED::ModelSEEDScripts::ContinuousDataImporter->new({
    DATABASE => "/home/devoid/test.db",
    DRIVER   => "SQLite",
});
my $testCount = 0;
my $equations = {};
my $parsedeq  = {};
$equations->{"rxn05785"} = "cpd11463 <=> cpd12036";
$parsedeq->{"rxn05785"} = [
    { "reaction" => "rxn05785",
      "compound" => "cpd11463",
      "coefficient" => -1,
      "compartment" => "c"
    },
    { "reaction" => "rxn05785",
      "compound" => "cpd12036",
      "coefficient" => 1,
      "compartment" => "c"
    },
]; 
$equations->{rxn05782} = "cpd00001 + cpd11698 <=> cpd00009 + cpd11463";
$parsedeq->{rxn05782} = [
    { "reaction" => "rxn05782",
      "compound" => "cpd00001",
      "coefficient" => -1,
      "compartment" => "c"
    },
    { "reaction" => "rxn05782",
      "compound" => "cpd11698",
      "coefficient" => -1,
      "compartment" => "c"
    },
    { "reaction" => "rxn05782",
      "compound" => "cpd00009",
      "coefficient" => 1,
      "compartment" => "c"
    },
    { "reaction" => "rxn05782",
      "compound" => "cpd11463",
      "coefficient" => 1,
      "compartment" => "c"
    },
];
$equations->{rxn05780} = "(2) cpd00067 + cpd03177 + (2) cpd12713 <=> cpd00013";
$parsedeq->{rxn05780} = [
    { "reaction" => "rxn05780",
      "compound" => "cpd00067",
      "coefficient" => -2,
      "compartment" => "c"
    },
    { "reaction" => "rxn05780",
      "compound" => "cpd03177",
      "coefficient" => -1,
      "compartment" => "c"
    },
    { "reaction" => "rxn05780",
      "compound" => "cpd12713",
      "coefficient" => -2,
      "compartment" => "c"
    },
    { "reaction" => "rxn05780",
      "compound" => "cpd00013",
      "coefficient" => 1,
      "compartment" => "c"
    },
];
$equations->{rxn05667} = "cpd00073[e] <=> cpd00073";
$parsedeq->{rxn05667} = [
    { "reaction" => "rxn05667",
      "compound" => "cpd00073",
      "coefficient" => -1,
      "compartment" => "e"
    },
    { "reaction" => "rxn05667",
      "compound" => "cpd00073",
      "coefficient" => 1,
      "compartment" => "c"
    },
];
$equations->{rxn13830} = "cpd00047 + (3) cpd00067 <=> cpd00011 + (2) cpd00067[e]";
$parsedeq->{rxn13830} = [
    { "reaction" => "rxn13830",
      "compound" => "cpd00047",
      "coefficient" => -1,
      "compartment" => "c"
    },
    { "reaction" => "rxn13830",
      "compound" => "cpd00067",
      "coefficient" => -3,
      "compartment" => "c"
    },
    { "reaction" => "rxn13830",
      "compound" => "cpd00047",
      "coefficient" => 1,
      "compartment" => "c"
    },
    { "reaction" => "rxn13830",
      "compound" => "cpd00067",
      "coefficient" => 2,
      "compartment" => "e"
    },
];
foreach my $reaction (keys %$equations) {
    my $eq = $equations->{$reaction};
    my $result = $importer->parseReactionEquationBase($eq, $reaction);
    my $expected = $parsedeq->{$reaction};
    is_deeply($result, $expected, "Failed on reaction $reaction");
}
$testCount += scalar(keys %$equations);    
done_testing($testCount);
