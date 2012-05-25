# Unit tests for composite database interface
use ModelSEED::Database::Composite;
use ModelSEED::Database::MongoDBSimple;
use Test::More;

my $test_count = 0;

# Basic object initialization
{
    my $file_db_1 = ModelSEED::Database::MongoDBSimple->new(db_name => 'test_1');
    my $file_db_2 = ModelSEED::Database::MongoDBSimple->new(db_name => 'test_1');

    my $composite = ModelSEED::Database::Composite->new(
        databases => [ $file_db_1, $file_db_2 ], 
    );
    ok defined($composite), "Should create a class instance";
    ok defined($composite->primary), "Should have primary database";
    ok defined($composite->databases), "Should have databases";
    $test_count += 3;
}

# TODO - actual unit tests

done_testing($test_count);
