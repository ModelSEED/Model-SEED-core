package ModelSEED::CLI::stores::Command::prioritize;
use ModelSEED::Config;
use Data::Dumper;
use base 'App::Cmd::Command';
my $MS = ModelSEED::Config->new;
sub abstract { "Set the storage priority" }
sub usage_desc { "%c COMMAND [store] [store] ..." }
sub validate_args {
    my ($self, $opt, $args) = @_;
    my $stores = $MS->config->{stores} || [];
    my %map = map { $_->{name} => $_ } @$stores; 
    foreach my $name (@$args) {
        unless (defined($map{$name})) {
            $self->usage_error("No Storage interface named $name!");
        }
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $stores = $MS->config->{stores} || [];
    my $newStore = [];
    my %map = map { $_->{name} => $_ } @$stores; 
    foreach my $name (@$args) {
        push(@$newStore, $map{$name});
        delete $map{$name};
    }
    push(@$newStore, values %map);
    $MS->config->{stores} = $newStore;
    $MS->save();
}
