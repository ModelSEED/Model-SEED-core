#!/usr/bin/env perl
use DateTime;
use Data::Dumper;
use Try::Tiny;

use ModelSEED::FIGMODEL;
use ModelSEED::Biochemistry;
use ModelSEED::Compound;
use ModelSEED::DB;

my $fm = ModelSEED::FIGMODEL->new();
my $db = $fm->database();
my $rdb = ModelSEED::DB->new();

$rdb->begin_work;

sub hashRename {
    my ($hash, $old, $new) = @_;
    $hash->{$new} = $hash->{$old};
    delete $hash->{$old};
}
# do one biochemistry
my $bio = ModelSEED::Biochemistry->new(db => $rdb);

# do compounds
{
    my $compounds = $db->get_objects("compound");
    foreach my $compound (@$compounds) {
        my $hash = {};
        foreach my $attr (keys %{$compound->attributes()}) {
            $hash->{$attr} = $compound->$attr();
        }
        hashRename($hash, 'modificationDate', 'modDate');
        hashRename($hash, 'abbrev', 'abbreviation');
        hashRename($hash, 'charge', 'defaultCharge');
        delete $hash->{structuralCues};
        delete $hash->{stringcode};
        delete $hash->{pKa};
        delete $hash->{pKb};
        delete $hash->{owner};
        delete $hash->{scope};
        delete $hash->{public};
        delete $hash->{abstractCompound};
        delete $hash->{creationDate};
        # abbreviation can be too long sometimes
        $hash->{abbreviation} = substr($hash->{abbreviation}, 0, 32);
        # convert unix time to DateTime object
        $hash->{modDate} = DateTime->from_epoch(epoch => $hash->{modDate});
        $hash->{db} = $rdb;
        try {
            my $cpd = ModelSEED::Compound->new($hash);
            $cpd->save();
        } catch {
            warn "Couldn't copy over ". $hash->{id} . "\n";
        };
        push(@{$bio->compounds}, $cpd);
    }
}
# do reactions
$bio->save();
$rdb->commit;
            
