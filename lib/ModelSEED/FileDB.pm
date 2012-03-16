package ModelSEED::FileDB;

use strict;
use warnings;

use Moose;
use ModelSEED::FileDB::FileIndex;

my $object_types = ['model', 'biochemistry', 'mapping', 'annotation'];

my $indexes = {};
foreach my $type (@$object_types) {
    $indexes->{$type} = ModelSEED::FileDB::FileIndex->new({
	filename => "$type.ind"
    });
}

sub has_object {
    my ($self, $type, $args) = @_;

    return $indexes->{$type}->has_object($args);
}

sub get_object {
    my ($self, $type, $args) = @_;

    return $indexes->{$type}->get_object($args);
}

sub save_object {
    my ($self, $type, $args) = @_;

    return $indexes->{$type}->save_object($args);
}

sub add_alias {
    my ($self, $type, $args) = @_;

    return $indexes->{$type}->add_alias($args);
}

sub remove_alias {
    my ($self, $type, $args) = @_;

    return $indexes->{$type}->remove_alias($args);
}

sub change_permissions {
    my ($self, $type, $args) = @_;

    return $indexes->{$type}->change_permissions($args);
}

sub get_uuids_for_user {
    my ($self, $type, $user) = @_;

    return $indexes->{$type}->get_uuids_for_user($user);
}

sub get_aliases_for_user {
    my ($self, $type, $user) = @_;

    return $indexes->{$type}->get_aliases_for_user($user);
}

sub add_user {
    my ($self, $user) = @_;

    foreach my $type (@$object_types) {
	$indexes->{$type}->add_user($user);
    }
}

sub remove_user {
    my ($self, $user) = @_;

    foreach my $type (@$object_types) {
	$indexes->{$type}->remove_user($user);
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
