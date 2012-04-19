# Performance tests for FileDB.pm 
use strict;
use warnings;

use Data::Dumper;

use ModelSEED::FileDB;

use JSON::Any;
use IO::Compress::Gzip qw(gzip);

use Test::Deep::NoTest;
use Digest::MD5 qw(md5_hex);

use Devel::Size qw(total_size);
use File::Temp qw(tempfile tempdir);
use Time::HiRes qw(time);

my $dir = tempdir();

my $type = 'test';
my $db = ModelSEED::FileDB->new({filename => "$dir/test"});

# test time for small objects
my $object = build_object(1);
save_object($object, 1000);

# test time for medium objects
$object = build_object(10000);
save_object($object, 50);

# test time for large objects
$object = build_object(500000);
save_object($object, 1);

sub build_object {
    my ($size) = @_;

    my $obj = {};
    for (my $i=0; $i<$size; $i++) {
	$obj->{id} = md5_hex(rand);
	$obj->{md5_hex(rand)} = md5_hex(rand) . md5_hex(rand);
    }    

    return $obj;
}

sub save_object {
    my ($obj, $num) = @_;

    my $obj_size = pretty_size(total_size($obj));

    my $json_obj = JSON::Any->encode($obj);
    my $json_size = pretty_size(length($json_obj));

    my $gzip_obj;
    gzip \$json_obj => \$gzip_obj;
    my $gzip_size = pretty_size(length($gzip_obj));

    print "Testing object with sizes: "
	. $obj_size->[0]  . " " . $obj_size->[1]  . " (perl), "
	. $json_size->[0] . " " . $json_size->[1] . " (json), "
	. $gzip_size->[0] . " " . $gzip_size->[1] . " (gzip)\n";

    my ($write, $read, $delete) = (0,0,0);
    for (my $i=0; $i<$num; $i++) {
	my $time = time;
	$db->save_object($type, $obj->{id}, $obj);
	$write += time - $time;
	$time = time;
	my $obj2 = $db->get_object($type, $obj->{id});
	$read += time - $time;
	$time = time;
	$db->delete_object($type, $obj->{id});
	$delete += time - $time;

	unless (eq_deeply($obj, $obj2)) {
	    die "Object read from database differs from object saved";
	}
    }

    print sprintf("%.3f", $write / $num) . "s write, "
	. sprintf("%.3f", $read / $num) . "s read, "
	. sprintf("%.3f", $delete / $num) . "s delete\n";
}

sub pretty_size {
    my ($size) = @_;

    my $suf_ind = 0;
    my $suf = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];

    while ($size >= 1024) {
	$size = $size / 1024;
	$suf_ind++;
    }

#    $size = sprintf("%.2f", $size);
    $size = int $size;

    return [$size, $suf->[$suf_ind]];
}
