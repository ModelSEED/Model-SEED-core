package ModelSEED::Api;
use Moose;
use namespace::autoclean;
use Data::Dumper;

has 'base' => (is => 'rw', isa => 'Str', default => '');
has 'om' => (is => 'rw', isa => 'ModelSEED::ObjectManager', required => 1);
has 'url_root' => (is => 'rw', isa => 'Str', required => 1);
# compile UUID regex once for class, this won't be altered by instances
has 'uuid_regex' => ( is => 'ro', isa => 'Regexp', init_arg => undef, default =>
sub { return
qr/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/});

sub serialize {
    my ($self, $ref, $args, $req) = @_;
    my ($t1, $one) = $self->parseReference($ref);
    my $base = (defined($one->[0])) ? $t1."/".$one->[0] :
        $t1."/".$one->[1]."/".$one->[2];
    $self->base($base);
    my $obj = $self->dereference($ref, $args);
    my $data;
    if(ref($obj) eq 'ARRAY') { # array is [ [results] , # total ]
        $data = $self->paginate($ref, $args, $obj->[0], $obj->[1]);
    } else {
        $data = $obj->serialize($args, $self, $ref);
    }
    $self->base('');
    return $data;
}

sub deserialize {
    my ($self, $ref, $json_object, $args, $req) = @_;
    my $rdb_object = $self->dereference($ref, $args);
    return $rdb_object->deserialize($json_object, $args, $self, $req);
}

sub paginate {
    my ($self, $ref, $args, $objs, $resultSetSize) = @_;
    my $offset = (defined($args->{offset})) ? $args->{offset} : 0;
    my $limit = (defined($args->{limit})) ? $args->{limit} : 30;
    my $nextOffset = $offset + $limit;
    my $hash = {
        limit => $limit,
        offset => $offset,
        resultSetSize => $resultSetSize,
        results => [],
        next => $self->url_root.$ref."?offset=$nextOffset&limit=$limit",
    };
    $hash->{results} = [ map { $_->serialize($args, $self) } @$objs ];
    return $hash;
}
    
sub parseReference {
    my ($self, $reference) = @_;
    my $root = $self->url_root;
    $reference =~ s/$root//;
    $reference =~ s/^\///;
    my @parts = split(/\//, $reference);
    # tx - type, ox - object, ( ux - user, nx - name ) pairs
    my ($t1, $o1, $u1, $n1, $t2, $o2, $u2, $n2);
    $t1 = $parts[0]; 
    my $i = 1;
    if(defined($parts[$i]) && $parts[$i] !~ $self->uuid_regex) {
        $u1 = $parts[$i];
        $n1 = $parts[$i+1];
        $i += 1;
    } elsif(defined($parts[$i])) {
        $o1 = $parts[$i];
    }
    $i += 1;
    if(defined($parts[$i])) {
        $t2 = $parts[$i];
    }
    $i += 1;
    if(defined($parts[$i]) && $parts[$i] =~ $self->uuid_regex) {
        $o2 = $parts[$i];
    }
    return ($t1, [$o1, $u1, $n1], $t2, $o2);
}
        
# dereference - take a reference like "http://model-api.theseed.org/biochem/:uuid"
# and convert to the actual object. dereference will accept any standard URL
# reverence (no GET parameters allowed) 
sub dereference {
    my ($self, $ref, $args) = @_;
    my ($t1, $one, $t2, $o2) = $self->parseReference($ref);
    my ($o1, $u1, $n1) = @$one if(defined($one));
    my ($obj, $isCollection);
    # handle /biochem/:username/:id alias
    if(defined($u1) && defined($n1)) {
        my $tmp = $self->om->get_object($t1, query =>
            [ $t1."_aliases.id" => $n1, $t1."_aliases.username" => $u1 ],
            require_objects => [ $t1."_aliases" ]); 
        unless(defined($tmp)) {
            die "Unknown reference: $ref";
        }
        $o1 = $tmp->uuid;
    } 
    # want a collection ( array ref ) if we don't have o1 or o2
    my ($limit, $offset);
    if((defined($t2) && !defined($o2)) || !defined($o1)) {
        $isCollection = 1;
        $limit  = $args->{limit} || 30;
        $offset = $args->{offset} || 0;
    }
    # try to get the object or objects
    if($isCollection && defined($t2)) {
        my $t1p = $self->om->plural($t1);
        $obj = $self->om->get_objects($t2, query => [ "$t1p.uuid" => $o1 ],
            require_objects => [ $t1p ], limit => $limit, offset => $offset);
        my $count = $self->om->get_count($t2, query => [ "$t1p.uuid" => $o1 ],
            require_objects => [ $t1p ]);
        $obj = [$obj, $count];
    } elsif($isCollection) {
        $obj = $self->om->get_objects($t1, limit => $limit, offset => $offset );
        my $count = $self->om->get_count($t1);
        $obj = [$obj, $count];
    } elsif(defined($o2)) {
        $obj = $self->om->get_object($t2, query => [ uuid => $o2 ] );
    } elsif(defined($o1)) {
        $obj = $self->om->get_object($t1, query => [ uuid => $o1 ] );     
    }
    # if we needed one object and didn't get it, create an empty object
    # collections already return empty array ref so do nothing for those 
    if(!defined($obj) && !$isCollection) {     
        if(defined($t2) && defined($o2)) {
            $obj = $self->om->create_object($t2, {uuid => $o2});
        } elsif(defined($t2)) {
            $obj = $self->om->create_object($t2);
        } elsif(defined($t1) && defined($o1)) {
            $obj = $self->om->create_object($t1, {uuid => $o1});
        } elsif(defined($t1)) {
            $obj = $self->om->create_object($t1);
        }
    }
    # if we don't have anything die now
    if(!defined($obj)) {
        die "Unknown Reference: $ref";
    }
    return $obj;
}

# reference - return a reference
# arguments:
#   context - string like "biochemistry/:uuid"
#   obj     - string for class "reaction" or Rose::DB::Object  
#
# like:  http://model-api.theseed.org/biochem/:uuid/reaction/:uuid
# or  :  http://model-api.theseed.org/biochem/:uuid/reaction
sub reference {
    my ($self, $obj) = @_;
    my $context = $self->base;
    $context =~ s/\/$//;
    $context =~ s/^\///;
    if($obj->isa('Rose::DB::Object')) {
        my $table = $obj->meta->table;
        my $type = $self->om->singular($table);
        return $self->url_root."$context/$type/".$obj->uuid;
    } elsif($obj) {
        my $type = $obj;
        return $self->url_root."$context/$type"; 
    } else {
        die "No object or type supplied";
    }
}

__PACKAGE__->meta->make_immutable;

1;
