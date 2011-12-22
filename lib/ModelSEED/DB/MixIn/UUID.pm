package ModelSEED::DB::MixIn::UUID;
use strict;
use warnings;
use Rose::Object::MixIn();

our @ISA = qw(Rose::Object::MixIn);

__PACKAGE__->meta->column('uuid')->add_trigger(
    deflate => sub {
        my $uuid = $_[0]->uuid;
        if(ref($uuid) && ref($uuid) eq 'Data::UUID') {
            return $uuid->to_string();
        } elsif($uuid) {
            return $uuid;
        } else {
            return Data::UUID->new()->create_str();
        }   
});



1;
