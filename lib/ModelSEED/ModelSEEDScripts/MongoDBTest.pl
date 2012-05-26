use JSON::RPC::Client;
use strict;
use Data::Dumper;
use URI;
use ModelSEED::Database::MongoDBSimple;
use ModelSEED::Auth::Basic;
use ModelSEED::Store;
use Data::UUID;

sub _uuid {
	return Data::UUID->new()->create_str();
}

my $db = ModelSEED::Database::MongoDBSimple->new({db_name => "modelObjectStore",host => "birch.mcs.anl.gov"});
my $auth = ModelSEED::Auth::Basic->new({username => "kbase",password => "kbase"});
my $store = ModelSEED::Store->new({auth => $auth,database => $db});
$store->save_data("biochemistry/kbase/test", { uuid => _uuid() });
print "test5\n";
my $biochem = $store->get_object("biochemistry/kbase/test");
print "test6\n";
print Dumper($biochem);
#my $mapping = $store->get_object("mapping/kbase/default");
#my $db = ModelSEED::Database::MongoDBSimple->new({db_name => "modelObjectStore",host => "mongodb.kbase.us"});
#$biochem->save("kbase/default",$store);
#$store->set_public("biochemistry/kbase/default",1);