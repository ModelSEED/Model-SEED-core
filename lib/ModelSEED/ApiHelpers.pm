package ModelSEED::ApiHelpers;

sub serializeAttributes {
    my ($object, $attributes, $hash) = @_;
    $hash = {} unless(defined($hash));
    foreach my $column (@$attributes) {
        my $name = $column->name;
        if($column->type eq 'datetime') {
            my $time = (defined($object->$name)) ?
                $object->$name->iso8601 : undef; 
            $hash->{$name} = $time;
        } else {
            $hash->{$name} = $object->$name;
        }
    }
    return $hash;
}
    
sub serializeRelationships {
    my ($object, $rels, $hash, $args, $ctx) = @_;
    $hash = {} unless(defined($hash));
    foreach my $rel (@$rels) {
        if(defined($args->{with}->{$rel})) {
            my $subargs = (ref($args->{with}->{$rel}) eq 'HASH') ?
                $args->{$rel} : {};
            $hash->{$rel} = [ map { $_->serialize($subargs) } $object->$rel ];
        } else {
            die $rel unless defined $ctx;
            $hash->{$rel} = $ctx->reference($rel);
        }
    }
    return $hash;
}

sub inlineRelationships {
    my ($object, $rels, $hash, $args, $ctx) = @_;
    $hash = {} unless(defined($hash));
    foreach my $rel (keys %$rels) {
        my $sub = $rels->{$rel};
        if(ref($sub) eq 'CODE') {
            $hash->{$rel} = [ map { $sub->($_, $args, $ctx) }
                $object->$rel ];
        } else {
            foreach my $oo ($object->$rel) {
                die "$rel" unless defined($oo);
            }
            $hash->{$rel} = [ map { $_->serialize($args, $ctx) }
                $object->$rel ];
        }
    }
    return $hash;
}

1;
    
