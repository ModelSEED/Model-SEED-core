# Unit tests for ModelSEED::Database::MongoDBSimple
use strict;
use warnings;
use Test::More;
use ModelSEED::Database::MongoDBSimple;
use ModelSEED::Auth::Basic;
use ModelSEED::Auth::Public;
use ModelSEED::Reference;
use Data::UUID;
use Data::Dumper;
my $test_count = 0;

sub _uuid {
    return Data::UUID->new->create_str();
}

# Basic object initialization
{
    my $mongo = ModelSEED::Database::MongoDBSimple->new({ db_name => 'test' });
    ok defined($mongo), "Should create a class instance";
    ok defined($mongo->conn), "Should have connection to database";
    ok defined($mongo->db), "Should have database object";
    $test_count += 3;
}

{
    my $db = ModelSEED::Database::MongoDBSimple->new( db_name => 'test',);
    my $type = "biochemistry";
    # Delete the database to get it clean and fresh
    $db->db->drop();
    my $ref1 = ModelSEED::Reference->new({
        ref => "biochemistry/alice/one"
    });
    my $ref2 = ModelSEED::Reference->new({
        ref => "biochemistry/alice/two"
    });
    my $auth = ModelSEED::Auth::Basic->new({
            username => "alice",
            password => "password",
    });
    my $pub = ModelSEED::Auth::Public->new();
    my $obj1 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj2 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    # Tests on non-existant objects
    ok !$db->has_data($ref1), "Database is empty";
    is undef, $db->get_data($ref1, $auth), "Cannot get non-existant object";
    ok !$db->delete_data($ref1, $auth), "Cannot delete non-existant object";
    $test_count += 3;

    # Tests on existing objects
    ok $db->save_data($ref1, $obj1, $auth), "Save object returns success";
    ok $db->has_data($ref1, $auth), "Has object after save";
    is_deeply $db->get_data($ref1, $auth), $obj1, "Get object returns same object";
    $test_count += 3;

    # Test permissions, not authorized
    ok !$db->has_data($ref1, $pub), "Test has_data, unauthorized";
    is undef, $db->get_data($ref1, $pub), "Test get_data, unauthorized";
    ok !$db->save_data($ref1, $obj2, $pub), "Shouldn't be able to save with another person's alias";
    is_deeply $db->get_data($ref1, $auth), $obj1, "Unauthorized save did not go through";
    $test_count += 4;

    # Test permissons, set to public (unauthorized)
    ok !$db->set_public($ref1, 1, $pub), "set_public unauthorized should fail";
    ok !$db->add_viewer($ref1, 'bob', $pub), "remove_viewer unauthorized should fail";
    ok !$db->remove_viewer($ref1, 'bob', $pub), "add_viewer unauthorized should fail";
    ok !$db->alias_owner($ref1, $pub), "getting alias owner, unauthorized should fail";
    ok !$db->alias_viewers($ref1, $pub), "getting alias viewers, unauthorized should fail";
    ok !$db->alias_public($ref1, $pub), "getting alias public, unauthorized should fail";
    ok !$db->alias_uuid($ref1, $pub), "getting alias uuid, unauthorized should fail";
    $test_count += 7;

    # Set permissions to public, authorized
    ok $db->set_public($ref1, 1, $auth), "set_public sould return success, auth";
    ok $db->alias_public($ref1, $auth), "alias_public sould return success, auth";
    is_deeply $db->alias_viewers($ref1, $auth), [], "no viewers on new alias";
    ok $db->add_viewer($ref1, "bob", $auth), "add_vewier should return success, auth"; 
    is_deeply $db->alias_viewers($ref1, $auth), ["bob"], "no viewers on new alias";
    is $db->alias_owner($ref1, $auth), "alice", "owner should be right on alias";
    $test_count += 6;

    # Test getting, for perm: public
    ok $db->has_data($ref1, $pub), "Test has_data, unauthorized, now public";
    is_deeply $db->get_data($ref1, $pub), $obj1, "Test get_data, unauthorized, now public";
    ok !$db->save_data($ref1, $obj2, $pub), "Shouldn't be able to save with another person's alias";
    is_deeply $db->get_data($ref1, $pub), $obj1, "Unauthorized save did not go through";
    $test_count += 4;

    # Test alter permissiosn, public, unauthorized
    ok !$db->set_public($ref1, 1, $pub), "set_public public, unauthorized should fail";
    ok !$db->add_viewer($ref1, 'bob', $pub), "remove_viewer public, unauthorized should fail";
    ok !$db->remove_viewer($ref1, 'bob', $pub), "add_viewer public, unauthorized should fail";
    is $db->alias_owner($ref1, $pub), "alice", "getting alias owner, public, unauthorized should work";
    is_deeply $db->alias_viewers($ref1, $pub), ["bob"], "getting alias viewers, public, unauthorized should work";
    is $db->alias_public($ref1, $pub), 1, "getting alias public, public, unauthorized should work";
    ok $db->alias_uuid($ref1, $pub), "getting alias uuid, public, unauthorized should work";
    $test_count += 7;

    # Test permissions for bob
    my $bob = ModelSEED::Auth::Basic->new({ username => "bob", password => "password" });
    $db->set_public($ref1, 0, $auth);
    is $db->alias_public($ref1, $auth), 0, "Should set correctly";
    ok $db->has_data($ref1, $bob), "Test has_data, bob";
    is_deeply $db->get_data($ref1, $bob), $obj1, "Test get_data, bob";
    ok !$db->save_data($ref1, $obj2, $bob), "Shouldn't be able to save with another person's alias";
    is_deeply $db->get_data($ref1, $bob), $obj1, "Unauthorized save did not go through";

    $test_count += 5;
}

## Testing alias listing
{
    my $db = ModelSEED::Database::MongoDBSimple->new( db_name => 'test',);
    my $type = "biochemistry";
    # Delete the database to get it clean and fresh
    $db->db->drop();
    my $alice = ModelSEED::Auth::Basic->new(
        username => "alice",
        password => "password",
    );
    my $pub = ModelSEED::Auth::Public->new();
    my $bob = ModelSEED::Auth::Basic->new(
        username => "bob",
        password => "password"
    );
    my $charlie = ModelSEED::Auth::Basic->new(
        username => "charlie",
        password => "password"
    );
    # Set up permissions:
    # alias  type          owner  viewers  public
    # one    biochemistry  alice           1
    # two    biochemistry  alice  bob      1
    # three  biochemistry  alice
    # four   model         bob    alice    
    # five   model         alice  bob      1
    # six    biochemistry  bob    alice     
    # c      model         charlie
    # c      biochemistry  charlie
    my $ref1 = ModelSEED::Reference->new(ref => "biochemistry/alice/one");
    my $ref2 = ModelSEED::Reference->new(ref => "biochemistry/alice/two");
    my $ref3 = ModelSEED::Reference->new(ref => "biochemistry/alice/three");
    my $ref4 = ModelSEED::Reference->new(ref => "model/bob/four");
    my $ref5 = ModelSEED::Reference->new(ref => "model/alice/five");
    my $ref6 = ModelSEED::Reference->new(ref => "biochemistry/bob/six");
    my $ref7 = ModelSEED::Reference->new(ref => "biochemistry/charlie/c");
    my $ref8 = ModelSEED::Reference->new(ref => "model/charlie/c");
    my $obj1 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj2 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj3 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj4 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj5 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj6 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj7 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj8 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };

    $db->save_data($ref1, $obj1, $alice);
    $db->save_data($ref2, $obj2, $alice);
    $db->save_data($ref3, $obj3, $alice);
    {
        $db->add_viewer($ref2, "bob", $alice);
        $db->set_public($ref1, 1, $alice);
        $db->set_public($ref2, 1, $alice);
    }
    $db->save_data($ref4, $obj4, $bob);
    $db->save_data($ref5, $obj5, $alice);
    $db->save_data($ref6, $obj6, $bob);
    {
        $db->add_viewer($ref4, "alice", $bob);
        $db->add_viewer($ref5, "bob", $alice);
        $db->set_public($ref5, 1, $alice);
        $db->add_viewer($ref6, "alice", $bob);
    }
    $db->save_data($ref7, $obj7, $charlie);
    $db->save_data($ref8, $obj8, $charlie);
   
    # Now test get_aliases for alice
    {
        my $all = $db->get_aliases(undef, $alice);
        my $bio = $db->get_aliases("biochemistry", $alice);
        my $hers = $db->get_aliases("biochemistry/alice", $alice);
        is scalar(@$all), 6, "Should get 6 aliases for alice, undef";
        is scalar(@$bio), 4, "Should get 4 aliases for alice, 'biochemistry'";
        is scalar(@$hers), 3, "Should get 3 aliases for alice, 'biochemistry/alice'";
    }
    # And for bob
    {
        my $all  = $db->get_aliases(undef, $bob);
        my $bio  = $db->get_aliases("biochemistry", $bob);
        my $hers = $db->get_aliases("biochemistry/alice", $bob);
        my $his  = $db->get_aliases("model/bob", $bob);
        is scalar(@$all), 5, "Should get 5 aliases for bob, undef";
        is scalar(@$bio), 3, "Should get 3 aliases for bob, 'biochemistry'";
        is scalar(@$hers), 2, "Should get 2 aliases for bob, 'biochemistry/alice'";
        is scalar(@$his), 1, "Should get 1 aliases for bob, 'model/bob'";
    }
    # And for public
    {
        my $all  = $db->get_aliases(undef, $pub);
        my $bio  = $db->get_aliases("biochemistry", $pub);
        my $model  = $db->get_aliases("model", $pub);
        my $b_hers = $db->get_aliases("biochemistry/alice", $pub);
        my $b_his = $db->get_aliases("biochemistry/bob", $pub);
        my $m_hers = $db->get_aliases("model/alice", $pub);
        my $m_his = $db->get_aliases("model/bob", $pub);

        is scalar(@$all), 3, "Should get 3 aliases for pub, undef";
        is scalar(@$bio), 2, "Should get 2 aliases for pub, 'biochemistry'";
        is scalar(@$model), 1, "Should get 1 aliases for pub, 'model'";
        is scalar(@$b_hers), 2, "Should get 2 aliases for pub, 'biochemistry/alice'";
        is scalar(@$b_his), 0, "Should get 0 aliases for pub, 'biochemistry/bob'";
        is scalar(@$m_hers), 1, "Should get 1 aliases for pub, 'model/alice'";
        is scalar(@$m_his), 0, "Should get 0 aliases for pub, 'model/bob'";
    }
    $test_count += 14;

    # Now test that get_aliases for charlie returns correct ammount for different refs
    {
        my $bio    = $db->get_aliases("biochemistry", $charlie);
        my $model  = $db->get_aliases("model", $charlie);
        my $all    = $db->get_aliases(undef, $charlie);
        is scalar(@$bio), 3, "Should get 3 for charlie 2 public + 1 private";
        is scalar(@$model), 2, "Should get 2 for charlie 1 public + 1 private";
        is scalar(@$all), 5, "Should get 5 for charlie, the total of last two tests";

        $test_count += 3;
    }
}
done_testing($test_count);
