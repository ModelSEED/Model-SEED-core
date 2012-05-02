# Unit tests for ObjectManager
use strict;
use warnings;
use Test::More;
use Try::Tiny;
use File::Temp qw(tempfile tempdir);
use ModelSEED::PersistenceAPI;
use ModelSEED::MS::ObjectManager;
use ModelSEED::MS::User;

my $testCount = 0;
# test initialization
{
    my $dir = tempdir();

    # get persistence api
    my $api = ModelSEED::PersistenceAPI->new({
	db_type => 'FileDB',
	db_config => {
	    directory => $dir
	}
    });

    my $pass = 'pass';
    my $user_hash = {
	login => 'pfrybarger',
	password => crypt($pass, 'Z8'),
	email => 'pfrybarger@gmail.com',
	firstname => 'Paul',
	lastname => 'Frybarger'
    };

    my $user = ModelSEED::MS::User->new($user_hash);
    $api->create_user($user->login, $user->serializeToDB);

    is_deeply $user_hash, $api->get_user($user->login), "Saved user to database successfully";

    my $om = ModelSEED::MS::ObjectManager->new({
	username => $user->login,
	password => $pass,
	api => $api
    });

    ok defined($om), "Got object manager";

    # test incorrect password, ObjectManager should die
    try {
	ModelSEED::MS::ObjectManager->new({
	    username => $user->login,
	    password => 'none',
	    api => $api
        });
	ok 0, "User authentication failed";
    } catch {
	ok 1, "User authentication success";
    };

    $testCount += 3;
}

done_testing($testCount);
