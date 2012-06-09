package ModelSEED::App::mseed::Command::get;
use Try::Tiny;
use List::Util;
use Class::Autouse qw(
    ModelSEED::App::Helpers
    ModelSEED::Reference
    ModelSEED::Auth::Factory
    ModelSEED::Store
    JSON
);
use base 'App::Cmd::Command';

sub abstract { return "Get an object from workspace or datastore."; }

sub usage_desc { return "ms get [ref] [< references] [options]"; }

sub opt_spec {
    return (
        ["verbose|v", "Print detailed infomation"],
        ["raw|r", "Print raw JSON output"],
        ["table|t", "Print as a tab-delimited table"],
        ["header|h", "Print as a tab-delimited table with a header row"],
        ["file|f:s", "Print output to a file"],
        ["eof|0", "Separate objects with EOF"],
    );
}
sub execute {
    my ($self, $opts, $args) = @_;
    my $auth = ModelSEED::Auth::Factory->new->from_config;
    my $store = ModelSEED::Store->new(auth => $auth);
    my $refs = [];
    if (@$args) {
        $refs = $args;
    } else {
        $self->usage_error("Must provide at least one reference");
    }
    # Check if any of the refs are the string "-"
    # which means read refs from STDIN, -0 if \0 terminated
    for(my $i=0; $i<@$refs; $i++) {
        if($refs->[$i] eq "-") {
            my $otherRefs = [];
            while(<STDIN>) {
                chomp $_;
                push(@$otherRefs, $_);
            }
            splice(@$refs, $i, 1, @$otherRefs);
            last;
        }
    }
    my $cache = {};
    my $output = [];
    my $JSON = JSON->new->utf8(1);
    foreach my $ref (@$refs) {
        my $o = $self->get_object_deep($cache, $store, $ref);
        if($opts->{raw}) {
            push(@$output, $o);
        }
    }
    if($opts->{raw}) {
        my $fh = *STDOUT;
        if($opts->{file}) {
            open($fh, "<", $opts->{file}) or
                die "Could not open file: " .$opts->{file} . ", $@\n";
        }
        my $delimiter;
        $delimiter = "\0" if($opts->{0});
        $delimiter = "\n" if($opts->{newline});
        if (defined $delimiter) {
            print $fh join($delimiter, map { $JSON->encode($_) } @$output);
        } else {
            print $fh $JSON->encode($output);
        }
        close($fh);
    }
    return;
}

sub get_object_deep {
    my ($self, $cache, $store, $refstr) = @_;
    my ($ref, $found, $refstring);
    try {
        $ref = ModelSEED::Reference->new(ref => $refstr);
    };
    return undef unless(defined($ref));
    if($ref->type eq 'object' && @{$ref->parent_objects} == 0) {
        $refstring = $ref->base . $ref->delimiter . $ref->id;
        if(defined($cache->{$refstring})) {
            $found = $cache->{$refstring};
        } else {
            $found = $store->get_data($refstring);
        }
    } elsif($ref->type eq 'object' && @{$ref->parent_collections}) {
        $refstring = $ref->base . $ref->delimiter . $ref->id;
        my $parent_ref = $ref->parent_objects->[0];
        my $parent = $self->get_object_deep($cache, $store, $parent_ref);
        my @sections = split($ref->delimiter, $ref->base);
        my $subtype = pop @sections;
        my $uuid = $ref->id;
        my $selection = [ grep { $_->{uuid} eq $uuid } @{$parent->{$subtype}}];
        $found = $selection->[0] || undef;
    # Reference to a collection of subobjects
    } elsif($ref->type eq 'collection' && @{$ref->parent_objects} > 0) {
        $refstring = $ref->base;
        my $last_i = @{$ref->{parent_objects}};
        my $parent_ref = $ref->parent_objects->[$last_i-1];
        my $parent = $self->get_object_deep($cache, $store, $parent_ref);
        my @sections = split($ref->delimiter, $ref->base);
        my $subtype = pop @sections;
        $found = $parent->{$subtype};
    }
    # otherwise it's a collection, not sure what the deal is here
    return $cache->{$refstring} = $found;
}

1;
