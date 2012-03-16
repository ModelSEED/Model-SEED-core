use strict;
use warnings;

use ModelSEED::FileDB::FileIndex;

my $uuid = "00000000-0000-0000-0000-000000000000";
my $file = "test.ind";

unlink $uuid;
unlink $file;

my $ind = ModelSEED::FileDB::FileIndex->new({
    filename => $file
});

my $obj = { 
    uuid => $uuid,
    hello => "world!"
};

$ind->save_object({user => 'paul', object => $obj});

$ind->add_alias({user => 'paul', uuid => $obj->{uuid}, alias => 'test'});

$ind->set_permissions({user => 'paul', uuid => $obj->{uuid}, permissions => {
    public => 0,
    users => {
	paul => { read => 1, admin => 1 },
	zedd => { read => 1, admin => 0 }
    }
}});

$ind->save_object({user => 'zedd', object => $obj});

$ind->delete_object({user => 'paul', uuid => $obj->{uuid}});

my $p_aliases = $ind->get_user_aliases('paul');
print "paul's aliases: " . join (", ", @$p_aliases), "\n";

my $p_uuids = $ind->get_user_uuids('paul');
print "paul's uuids: " . join (", ", @$p_uuids), "\n";

my $z_uuids = $ind->get_user_uuids('zedd');
print "zedd's uuids: " . join (", ", @$z_uuids), "\n";

print "Finished!\n";
