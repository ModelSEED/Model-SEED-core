#===============================================================================
#
#         FILE:  data-import.t
#
#  DESCRIPTION:  Test helper routines in continuous data import
#
#===============================================================================
use Test::More;
use strict;
use warnings;
use Data::Dumper;
use ModelSEED::Import qw(parseReactionEquationBase);
use POSIX;
use File::Temp;
use List::Util qw(min);

my $testCount = 0;
my ($importer, $om);
{
    my ($tmpdir) = File::Temp::tempdir();
    $importer = ModelSEED::Import->new({
        database => $ENV{HOME}."/test.db",
        driver => 'sqlite',
        berkeleydb => $tmpdir,
        cacheSize => '2G',
    });
    $om = $importer->om;
}

{
    # Test hash functions -
    # we create a rose-db object and run the hash function
    # - confirm that two identical objects will have the same hash
    # - confirm that two different objects will have different hashes
    # - same thing for arrays of objects
    my $pairs = {
        compound => [
            { name => 'H2O', id => 'cpd00001', formula => 'H2O' },
            { name => 'ATP', id => 'cpd00002', formula => 'C10H13N5O13P3'},
            ], 
    };
    foreach my $type (keys %{$importer->hash}) {
        my $objects = $importer->om->get_objects($type);
        my $seen = {};
        my $limit = 100;
        my $min = min(scalar(@$objects), $limit); 
        foreach my $object (@$objects) {
            my $h1 = $importer->hash->{$type}->($object);
            my $h2 = $importer->hash->{$type}->($object);
            ok $h1 eq $h2, "same object of type: $type should be the same!";
            ok !defined($seen->{$h1}), "shouldn't see duplicate hash for $type!";
            $seen->{$h1} = 1;
            $limit -= 1;
            last if $limit == 0;
        }
        $testCount += $min*2;
    }
}
    

{
    # Test equation parsing (for reagents)
    # here we have reaction equations and the expected results
    my $equations = {};
    my $parsedeq  = {};
    $equations->{"rxn05785"} = "cpd11463 <=> cpd12036";
    $parsedeq->{"rxn05785"} = [
        { "reaction" => ["rxn05785"],
          "compound" => ["cpd11463"],
          "coefficient" => [-1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05785"],
          "compound" => ["cpd12036"],
          "coefficient" => [1],
          "compartment" => ["c"]
        },
    ]; 
    $equations->{rxn05782} = "cpd00001 + cpd11698 <=> cpd00009 + cpd11463";
    $parsedeq->{rxn05782} = [
        { "reaction" => ["rxn05782"],
          "compound" => ["cpd00001"],
          "coefficient" => [-1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05782"],
          "compound" => ["cpd11698"],
          "coefficient" => [-1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05782"],
          "compound" => ["cpd00009"],
          "coefficient" => [1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05782"],
          "compound" => ["cpd11463"],
          "coefficient" => [1],
          "compartment" => ["c"]
        },
    ];
    $equations->{rxn05780} = "(2) cpd00067 + cpd03177 + (2) cpd12713 <=> cpd00013";
    $parsedeq->{rxn05780} = [
        { "reaction" => ["rxn05780"],
          "compound" => ["cpd00067"],
          "coefficient" => [-2],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05780"],
          "compound" => ["cpd03177"],
          "coefficient" => [-1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05780"],
          "compound" => ["cpd12713"],
          "coefficient" => [-2],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn05780"],
          "compound" => ["cpd00013"],
          "coefficient" => [1],
          "compartment" => ["c"]
        },
    ];
    $equations->{rxn05667} = "cpd00073[e] <=> cpd00073";
    $parsedeq->{rxn05667} = [
        { "reaction" => ["rxn05667"],
          "compound" => ["cpd00073"],
          "coefficient" => [-1],
          "compartment" => ["e"]
        },
        { "reaction" => ["rxn05667"],
          "compound" => ["cpd00073"],
          "coefficient" => [1],
          "compartment" => ["c"]
        },
    ];
    $equations->{rxn13830} = "cpd00047 + (3) cpd00067 <=> cpd00011 + (2) cpd00067[e]";
    $parsedeq->{rxn13830} = [
        { "reaction" => ["rxn13830"],
          "compound" => ["cpd00047"],
          "coefficient" => [-1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn13830"],
          "compound" => ["cpd00067"],
          "coefficient" => [-3],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn13830"],
          "compound" => ["cpd00011"],
          "coefficient" => [1],
          "compartment" => ["c"]
        },
        { "reaction" => ["rxn13830"],
          "compound" => ["cpd00067"],
          "coefficient" => [2],
          "compartment" => ["e"]
        },
    ];
    foreach my $reaction (keys %$equations) {
        my $eq = $equations->{$reaction};
        my $result = parseReactionEquationBase($eq, $reaction);
        my $expected = $parsedeq->{$reaction};
        is_deeply($result, $expected, "Failed on reaction $reaction");
    }
    $testCount += scalar(keys %$equations);    
}

{
    # Testing determinePrimaryComaprtment
    my $eqs = <<EQS;
cpd11463 <=> cpd12036
cpd11463 <=> cpd12003
cpd11463 <=> cpd11770
cpd00001 + cpd11698 <=> cpd00009 + cpd11463
cpd00002 + cpd11463 <=> cpd00008 + cpd11698
(2) cpd00067 + cpd03177 + (2) cpd12713 <=> cpd00013
cpd00001 + cpd00006 + cpd03077 <=> cpd00005 + cpd00013 + cpd11625
cpd00001 + cpd00003 + cpd03077 <=> cpd00004 + cpd00013 + cpd11625
cpd00002 + cpd00013 <=> cpd00008 + cpd12010
cpd00001 <=> cpd00129
cpd00005 + cpd00067 + (2) cpd12158 <=> cpd00006 + (2) cpd12160
cpd00005 + cpd00067 + (2) cpd11796 <=> cpd00006 + (2) cpd11798
cpd00004 + cpd00067 + (2) cpd12158 <=> cpd00003 + (2) cpd12160
cpd00004 + cpd00067 + (2) cpd11795 <=> cpd00003 + (2) cpd11797
cpd00007 + (4) cpd11798 <=> (2) cpd00001 + (4) cpd11796
(4) cpd00001 + cpd12067 <=> (4) cpd00009 + (2) cpd12068
(2) cpd00002 + cpd12068 <=> (2) cpd00008 + cpd12067
(2) cpd12781 <=> cpd00007 + (2) cpd12780
(2) cpd00067 + (2) cpd12713 <=> cpd11640
EQS
    $eqs = [ split(/\n/, $eqs) ];
}

{
    # testing makeQuery functions - need to return same object as we said they would
    my $limit = 100;
    foreach my $type (keys %{$importer->cache}) {
        my $objects = $om->get_objects($type);
        for(my $i=0; $i<min(scalar(@$objects), $limit); $i++) {
            my $object = $objects->[$i];
            my $query = $importer->makeQuery($type, $object);
            my $result = $om->get_object($type, $query);
            my $expected = $importer->hash->{$type}->($object);
            my $got = $importer->hash->{$type}->($result); 
            is($got, $expected, "makeQuery on $type should get same objects");
        }
        $testCount += min(scalar(@$objects), $limit);
    } 
}
        
{
    # Test import and hash - if we import twice, should only get one biochem even for small biochem
    my $one = $importer->importBiochemistryFromDir($ENV{HOME}."/Desktop/Core/small-mapping/", "devoid", "one");
    my $two = $importer->importBiochemistryFromDir($ENV{HOME}."/Desktop/Core/small-mapping/", "devoid", "two");
    ok defined($one), "should import biochemistry first time";
    ok defined($two), "should get back biochemistry second time";
    ok $one->uuid eq $two->uuid, "two identical biochemistries should be the same";
    $testCount += 3;
}
done_testing($testCount);
