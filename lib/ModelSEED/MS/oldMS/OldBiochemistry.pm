package ModelSEED::MS::Biochemistry;

use strict;
use warnings;

use ModelSEED::CoreApi;

sub new {
    my ($class, $uuid, $user, $api) = @_;

    unless (defined($api)) {
	# create new api with defaults
    }

    my $biochem = $api->getBiochemistrySimple($uuid, $user);

    my $self = {};
    $self->{api} = $api;
    $self->{rxn_cache} = {};
    $self->{rxn_cache_size} = 100;
    $self->{rxn_cache_last} = [];
    $self->{data} = $biochem;

    bless($self, $class);
    return $self;
}

sub getReactionIds {
    my ($self) = @_;

    return $self->{data}->{relationships}->{reactions};
}

sub getReaction {
    my ($self, $uuid) = @_;

    if (defined($self->{rxn_cache}->{$uuid})) {
#	print "Found $uuid in cache\n";
	return $self->{rxn_cache}->{$uuid};
    } else {
#	print "Did not find $uuid in cache, grabbing from database\n";
	my $rxn = $self->{api}->getReaction($uuid, $self->{data}->{attributes}->{uuid});
	$self->{rxn_cache}->{$uuid} = $rxn;

	unshift(@{$self->{rxn_cache_last}}, $uuid);
	if (scalar @{$self->{rxn_cache_last}} > $self->{rxn_cache_size}) {
	    my $old_uuid = pop(@{$self->{rxn_cache_last}});
#	    print "Cache is full, deleting $old_uuid from cache\n";
	    delete $self->{rxn_cache}->{$old_uuid};
	}
    }
}

sub getReactionIterator {
    my ($parent) = @_;

    my $it = do {
	package ModelSEED::MS::Biochemistry::ReactionIterator;

	sub new {
	    my ($class, $parent) = @_;
	    my $self = {};
	    $self->{parent} = $parent;
	    $self->{index} = 0;

	    bless($self, $class);
	    return $self;
	}

	sub hasNext {
	    my ($self) = @_;

	    return @{$self->{parent}->{data}->{relationships}->{reactions}} > $self->{index};
	}

	sub next {
	    my ($self) = @_;

	    # check if we need to load next chunk
	    if ($self->{index} % $self->{parent}->{rxn_cache_size} == 0) {
		my $rxns = $self->{parent}->{api}->getReactions($self->{parent}->{data}->{attributes}->{uuid}, undef, $self->{parent}->{rxn_cache_size}, $self->{index});

		$self->{parent}->{rxn_cache} = {};
		$self->{parent}->{rxn_cache_last} = [];

		foreach my $rxn (@$rxns) {
		    $self->{parent}->{rxn_cache}->{$rxn->{attributes}->{uuid}} = $rxn;
		    push(@{$self->{parent}->{rxn_cache_last}}, $rxn->{attributes}->{uuid});

#		    print "Loading " . $rxn->{attributes}->{uuid} . " into cache\n";
		}
	    }

	    return $self->{parent}->getReaction($self->{parent}->{data}->{relationships}->{reactions}->[$self->{index}++]);
	}

	__PACKAGE__
    }->new($parent);
}

1;
