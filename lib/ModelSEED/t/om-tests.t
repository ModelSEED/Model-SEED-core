# Tests for ModelSEED::ObjectManager
use ModelSEED::TestingHelpers;
use ModelSEED::ObjectManager;
use Test::More;
my $testCount= 0;

my $helper = ModelSEED::TestingHelpers->new();
my $api    = $helper->getDebugCoreApi();
   $api->_initOM();
my $om     = $api->{om};
my $testDatabase = $om->database;

# Test namingConventions, objectClasses, objectManagerClasses
{
    my $conventions = {
       Foo => [ qw(foo Foo) ],
       Bar => [ qw(bar Bar) ],
    };
    my $om = ModelSEED::ObjectManager->new({
        database => $testDatabase,
        driver   => "SQLite",
        namingConventions => $conventions,
    });
    ok defined($om->namingConventions), "Should have naming conventions object";
    ok defined($om->objectClasses), "Should have objectClass attribute";
    ok defined($om->objectManagerClasses), "Should have objectManager attribute";
    $testCount += 3;

    foreach my $conv (keys %$conventions) {
        ok defined($om->namingConventions->{$conv}),
            "Convention should have $conv entry!";
        $testCount += 1;
    }

    foreach my $package (keys %$conventions) {
        foreach my $alias (@{$conventions->{$package}}) {
            ok ($om->objectClasses->{$alias} =~ $package),
                "ObjectClasses alias $alias should map to $package";
            $testCount += 1;
        }
    }
    is $om->objectClass("foo"), "ModelSEED::DB::Foo",
        "Package name should be correct.";
    is $om->objectClasses->{"foo"}, "ModelSEED::DB::Foo",
        "Package name should be correct.";
    is $om->objectManagerClass("foo"), "ModelSEED::DB::Foo::Manager",
        "Package name should be correct.";
    is $om->objectManagerClasses->{"foo"}, "ModelSEED::DB::Foo::Manager",
        "Package name should be correct.";
    $testCount += 4;
}

# Test that the REAL default naming conventiosn are as we expect
{ 
    my $conv = $om->namingConventions;
    ok defined($conv->{Biochemistry}), "Should have biochemistry object";
    $testCount += 1;
}
    
done_testing($testCount);
