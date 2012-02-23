package ModelSEED::CoreApi;

use strict;
use warnings;
use DBI;


# TODO: list these columns in separate module and import
my $biochem_cols = ['uuid', 'modDate', 'locked', 'public', 'name'];

my $reaction_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'abbreviation',
		     'cksum', 'equation', 'deltaG', 'deltaGErr', 'reversibility',
		     'thermoReversibility', 'defaultProtons', 'compartment_uuid',
		     'defaultTransproton'];

my $reagent_cols = ['reaction_uuid', 'compound_uuid', 'compartmentIndex',
		    'coefficient', 'cofactor'];

my $compound_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'abbreviation',
		     'cksum', 'unchargedFormula', 'formula', 'mass',
		     'defaultCharge', 'deltaG', 'deltaGErr'];

my $aliases_cols = ['alias', 'modDate', 'type'];

my $set_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'searchname', 'class', 'type'];

my $media_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'type'];

my $media_compound_cols = ['compound_uuid', 'concentraion', 'minflux', 'maxflux'];

my $compartment_cols = ['uuid', 'modDate', 'locked', 'id', 'name'];

my $mapping_cols = ['uuid', 'modDate', 'locked', 'public', 'name', 'biochemistry_uuid'];

my $complex_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'searchname'];

my $reaction_rule_cols = ['uuid', 'reaction_uuid', 'compartment_uuid', 'direction', 'transprotonNature'];

my $role_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'searchname', 'feature_uuid', 'optional', 'type'];

sub new {
    my ($class, $args) = @_;

    my $self = {
        om => undef,
        database => $args->{database},
        driver => $args->{driver},
    };

    # create the dbi connection
    my $dsn;
    if (lc($args->{driver}) eq "sqlite") {
	$dsn = "dbi:SQLite:" . $args->{database};
    } else {
	# TODO: create dsn for mysql
    }

    my $dbi = DBI->connect($dsn);

    unless ($dbi) {
	die "Could not create DBI: " . $DBI::errstr;
    }

    $self->{dbi} = $dbi;

    bless($self, $class);
    return $self;
}

=head3 getBiochemistry
Definition:
    {} = coreApi->getBiochemistry(string:biochemistry uuid);
Description:
    Return the biochemistry data structure with the reactions (including reagents),
      compounds, and media. Currently uses Rose::DB, but is pretty slow. Might use
      DBI and raw SQL to speed up eventually
Returns:
    
=cut
sub getBiochemistry {
    my ($self, $args) = @_;

    _processArgs($args, 'getBiochemistry', {
	uuid              => {required => 1},
	user              => {required => 1},
	with_all          => {required => 0},
	with_reactions    => {required => 0},
	with_compounds    => {required => 0},
	with_media        => {required => 0},
	with_reactionsets => {required => 0},
	with_compoundsets => {required => 0},
	with_compartments => {required => 0}
    });

    # get the biochemistry object
    my $bio_sql = "SELECT * FROM biochemistries"
	. " WHERE uuid = ?";

    my $rows = $self->{dbi}->selectall_arrayref($bio_sql, undef, $args->{uuid});

    unless (scalar @$rows == 1) {
	die "Unable to find biochemistry with uuid: " . $args->{uuid};
    }

    my $biochem = _processRows($rows, $biochem_cols, "Biochemistry")->[0];

    my $with = {
	reactions => 'getReactions',
	compounds => 'getCompounds',
	media => 'getMedia',
	reactionsets => 'getReactionSets',
	compoundsets => 'getCompoundSets',
	compartments => 'getCompartments'
    };

    if ($args->{with_all}) {
	foreach my $rel (keys %$with) {
	    my $sub = $with->{$rel};
	    $biochem->{relationships}->{$rel} = $self->$sub({biochemistry_uuid => $args->{uuid}});
	}
    } else {
	foreach my $rel (keys %$with) {
	    if ($args->{"with_$rel"}) {
		my $sub = $with->{$rel};
		$biochem->{relationships}->{$rel} = $self->$sub({biochemistry_uuid => $args->{uuid}});
	    }
	}
    }

    return $biochem;
}

sub getReactions {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getReactions', {
	biochemistry_uuid => {required => 1},
	query             => {required => 0},
	limit             => {required => 0},
	offset            => {required => 0}
    });

    my $sub_sql = "SELECT reaction_uuid"
	. " FROM biochemistry_reactions"
	. " WHERE biochemistry_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE reactions.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the reaction data
    my $sql = "SELECT * FROM reactions"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no reactions
    if (scalar @$rows == 0) {
	return [];
    }

    my $reactions = _processRows($rows, $reaction_cols, "Reaction");

    # get the aliases
    $sql = "SELECT reaction_aliases.* FROM reactions"
	. " JOIN reaction_aliases on reactions.uuid = reaction_aliases.reaction_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $aliases = _processJoinedRows($rows, $aliases_cols, "ReactionAlias");

    # get the reagents
    $sql = "SELECT reactions.uuid, reagents.* FROM reactions"
	. " JOIN reagents ON reactions.uuid = reagents.reaction_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $reagents = _processJoinedRows($rows, $reagent_cols, "Reagent");

    # get the reactionsets
    $sql = "SELECT reactions.uuid, reactionsets.* FROM reactions"
	. " JOIN reactionset_reactions ON reactions.uuid = reactionset_reactions.reaction_uuid"
	. " JOIN reactionsets ON reactionset_reactions.reactionset_uuid = reactionsets.uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $reactionsets = _processJoinedRows($rows, $set_cols, "ReactionSet");

    foreach my $reaction (@$reactions) {
	my $uuid = $reaction->{attributes}->{uuid};

	if (defined($reagents->{$uuid})) {
	    $reaction->{relationships}->{reagents} = $reagents->{$uuid};
	}

	if (defined($aliases->{$uuid})) {
	    $reaction->{relationships}->{aliases} = $aliases->{$uuid};
	}

	if (defined($reactionsets->{$uuid})) {
	    $reaction->{relationships}->{reactionsets} = $reactionsets->{$uuid};
	}
    }

    return $reactions;
}

sub getReaction {
#    my ($self, $rxn_uuid, $bio_uuid) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getReaction', {
	uuid              => {required => 1},
	biochemistry_uuid => {required => 1}
    });

    # call getReactions with uuid query
    my $rxns = $self->getReactions({
	biochemistry_uuid => $args->{biochemistry_uuid},
	query => [['reactions.uuid', $args->{uuid}]]
    });

    if (scalar @$rxns == 1) {
	return $rxns->[0];
    } else {
	return undef;
    }
}

sub getCompounds {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getCompounds', {
	biochemistry_uuid => {required => 1},
	query             => {required => 0},
	limit             => {required => 0},
	offset            => {required => 0}
    });

    my $sub_sql = "SELECT compound_uuid"
	. " FROM biochemistry_compounds"
	. " WHERE biochemistry_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE compounds.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the compound data
    my $sql = "SELECT * FROM compounds"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no compounds
    if (scalar @$rows == 0) {
	return [];
    }

    my $compounds = _processRows($rows, $compound_cols, "Compound");

    # get the aliases
    $sql = "SELECT compound_aliases.* FROM compounds"
	. " JOIN compound_aliases on compounds.uuid = compound_aliases.compound_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $aliases = _processJoinedRows($rows, $aliases_cols, "CompoundAlias");

    # get the compoundsets
    $sql = "SELECT compounds.uuid, compoundsets.* FROM compounds"
	. " JOIN compoundset_compounds ON compounds.uuid = compoundset_compounds.compound_uuid"
	. " JOIN compoundsets ON compoundset_compounds.compoundset_uuid = compoundsets.uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $compoundsets = _processJoinedRows($rows, $set_cols, "CompoundSet");

    foreach my $compound (@$compounds) {
	my $uuid = $compound->{attributes}->{uuid};

	if (defined($aliases->{$uuid})) {
	    $compound->{relationships}->{aliases} = $aliases->{$uuid};
	}

	if (defined($compoundsets->{$uuid})) {
	    $compound->{relationships}->{compoundsets} = $compoundsets->{$uuid};
	}
    }

    return $compounds;
}

sub getCompound {
#    my ($self, $cpd_uuid, $bio_uuid) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getCompound', {
	uuid              => {required => 1},
	biochemistry_uuid => {required => 1}
    });

    # call getCompounds with uuid query
    my $cpds = $self->getCompounds({
	biochemistry_uuid => $args->{biochemistry_uuid},
	query => [['compounds.uuid', $args->{uuid}]]
    });

    if (scalar @$cpds == 1) {
	return $cpds->[0];
    } else {
	return undef;
    }
}

sub getMedia {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getMedia', {
	biochemistry_uuid => {required => 1},
	query             => {required => 0},
	limit             => {required => 0},
	offset            => {required => 0}
    });

    my $sub_sql = "SELECT media_uuid"
	. " FROM biochemistry_media"
	. " WHERE biochemistry_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE media.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the media data
    my $sql = "SELECT * FROM media"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no media
    if (scalar @$rows == 0) {
	return [];
    }

    my $media = _processRows($rows, $media_cols, "Media");

    # get the media_compounds
    $sql = "SELECT media_compounds.* FROM media"
	. " JOIN media_compounds on media.uuid = media_compounds.media_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $media_compounds = _processJoinedRows($rows, $media_compound_cols, "MediaCompound");

    foreach my $med (@$media) {
	my $uuid = $med->{attributes}->{uuid};

	if (defined($media_compounds->{$uuid})) {
	    $med->{relationships}->{media_compounds} = $media_compounds->{$uuid};
	}
    }

    return $media;
}

sub getReactionSets {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getReactionSets', {
	biochemistry_uuid => {required => 1},
	query             => {required => 0},
	limit             => {required => 0},
	offset            => {required => 0}
    });

    my $sub_sql = "SELECT reactionset_uuid"
	. " FROM biochemistry_reactionsets"
	. " WHERE biochemistry_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE reactionsets.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the reaction data
    my $sql = "SELECT * FROM reactionsets"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no reactions
    if (scalar @$rows == 0) {
	return [];
    }

    my $reactionsets = _processRows($rows, $set_cols, "ReactionSet");

    return $reactionsets;
}

sub getCompoundSets {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getCompoundSets', {
	biochemistry_uuid => {required => 1},
	query             => {required => 0},
	limit             => {required => 0},
	offset            => {required => 0}
    });

    my $sub_sql = "SELECT compoundset_uuid"
	. " FROM biochemistry_compoundsets"
	. " WHERE biochemistry_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE compoundsets.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the compound data
    my $sql = "SELECT * FROM compoundsets"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no compounds
    if (scalar @$rows == 0) {
	return [];
    }

    my $compoundsets = _processRows($rows, $set_cols, "CompoundSet");

    return $compoundsets;
}

sub getCompartments {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getCompartments', {
	biochemistry_uuid => {required => 1},
	query             => {required => 0},
	limit             => {required => 0},
	offset            => {required => 0}
    });

    my $sub_sql = "SELECT compartment_uuid"
	. " FROM biochemistry_compartments"
	. " WHERE biochemistry_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE compartments.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the compound data
    my $sql = "SELECT * FROM compartments"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no compounds
    if (scalar @$rows == 0) {
	return [];
    }

    my $compartments = _processRows($rows, $compartment_cols, "Compartment");

    return $compartments;
}

sub getMapping {
#    my ($self, $uuid, $user) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getMapping', {
	uuid              => {required => 1},
	user              => {required => 1},
	with_all          => {required => 0},
	with_complexes => {required => 0}
    });

    # get the mapping object
    my $sql = "SELECT * FROM mappings"
	. " WHERE uuid = ?";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{uuid});

    unless (scalar @$rows == 1) {
	die "Unable to find mapping with uuid: " . $args->{uuid};
    }

    my $mapping = _processRows($rows, $mapping_cols, "Mapping")->[0];

    my $with = {
	complexes => 'getComplexes'
    };

    if ($args->{with_all}) {
	foreach my $rel (keys %$with) {
	    my $sub = $with->{$rel};
	    $mapping->{relationships}->{$rel} = $self->$sub({mapping_uuid => $args->{uuid}});
	}
    } else {
	foreach my $rel (keys %$with) {
	    if ($args->{"with_$rel"}) {
		my $sub = $with->{$rel};
		$mapping->{relationships}->{$rel} = $self->$sub({mapping_uuid => $args->{uuid}});
	    }
	}
    }

    return $mapping;
}

sub getComplexes {
#    my ($self, $bio_uuid, $query, $limit, $offset) = @_;
    my ($self, $args) = @_;

    _processArgs($args, 'getComplexes', {
	mapping_uuid => {required => 1},
	query        => {required => 0},
	limit        => {required => 0},
	offset       => {required => 0}
    });

    my $sub_sql = "SELECT complex_uuid"
	. " FROM mapping_complexes"
	. " WHERE mapping_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE complexes.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the reaction data
    my $sql = "SELECT * FROM complexes"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});

    # return empty set if no complexes
    if (scalar @$rows == 0) {
	return [];
    }

    my $complexes = _processRows($rows, $complex_cols, "Complex");

    # get the reaction rules
    $sql = "SELECT complexes.uuid, reaction_rules.* FROM complexes"
	. " JOIN complex_reaction_rules ON complexes.uuid = complex_reaction_rules.complex_uuid"
	. " JOIN reaction_rules on complex_reaction_rules.reaction_rule_uuid = reaction_rules.uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});
    my $reaction_rules = _processJoinedRows($rows, $reaction_rule_cols, "ReactionRule");

    # get the roles
    $sql = "SELECT complexes.uuid, roles.*, complex_roles.optional, complex_roles.type FROM complexes"
	. " JOIN complex_roles ON complexes.uuid = complex_roles.complex_uuid"
	. " JOIN roles ON complex_roles.role_uuid = roles.uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});
    my $roles = _processJoinedRows($rows, $role_cols, "Role");

    foreach my $complex (@$complexes) {
	my $uuid = $complex->{attributes}->{uuid};

	if (defined($reaction_rules->{$uuid})) {
	    $complex->{relationships}->{reaction_rules} = $reaction_rules->{$uuid};
	}

	if (defined($roles->{$uuid})) {
	    $complex->{relationships}->{roles} = $roles->{$uuid};
	}
    }

    return $complexes;
}

sub _processArgs {
    my ($args, $function, $defaults) = @_;

    if (ref($args) ne 'HASH') {
	die "Unknown argument type in call to: $function";
    }

    foreach my $key (keys %$defaults) {
	if ($defaults->{$key}->{required} && !defined($args->{$key})) {
	    if (defined($defaults->{$key}->{default})) {
		$args->{$key} = $defaults->{$key}->{default};
	    } else {
		die "Argument '$key' not found in call to: $function";
	    }
	}
    }
}

sub _processRows {
    my ($rows, $cols, $type) = @_;

    my $objs = [];

    foreach my $row (@$rows) {
	my $obj = {
	    type => $type,
	    attributes => {},
	    relationships => {}
	};

	my $ind = 0;
	foreach my $attr (@$cols) {
	    $obj->{attributes}->{$attr} = $row->[$ind++];
	}

	push(@$objs, $obj);
    }

    return $objs;
}

sub _processJoinedRows {
    my ($rows, $cols, $type) = @_;

    unless (scalar @$rows) {
	return {};
    }

    my $num_cols = scalar @$cols;
    my $id = $rows->[0]->[0];
    my $hash = {$id => []};

    foreach my $row (@$rows) {
	if ($id ne $row->[0]) {
	    $id = $row->[0];
	    $hash->{$id} = [];
	}

	my $data = {
	    type => $type,
	    attributes => {}
	};

	for (my $i=0; $i<$num_cols; $i++) {
	    $data->{attributes}->{$cols->[$i]} = $row->[$i+1];
	}

	push(@{$hash->{$id}}, $data);
    }

    return $hash;
}

=head3
  Query looks like:
    [
        ['name', 'like', '%atp%'],
        ['locked', '0']
    ]

  You can specify the comparison operator (=, >, <=, like, etc...),
    or it will use '=' by default.

  Returns string of SQL like:
    "name like '%atp% AND locked = '0'"

  Note: does NOT add the WHERE clause
=cut
sub _parseQuery {
    my ($query) = @_;

    my $sql = [];
    foreach my $q (@$query) {
	if (scalar @$q == 3) {
	    push(@$sql, $q->[0] . " " . $q->[1] .  " '" . $q->[2] . "'");
	} elsif (scalar @$q == 2) {
	    push(@$sql, $q->[0] . " = '" . $q->[1] . "'");
	}
    }

    return join(' AND ', @$sql);
}

sub save {
    my ($self, $object, $user) = @_;
    $self->{om}->db->begin_work;
    my $success = 1;
    try {
        $self->_innerSave($object, $user);
    } catch { $success = 0; };
    if($success) {
        $self->{om}->db->commit;
    } else {
        $self->{om}->db->rollback;
    }
    return $success;
}

sub _innerSave {
    my ($self, $object, $user) = @_;
    if(!defined($self->{om})) {
        # until we get moose lazy loaders in here
        $self->_initOM();
    }
    my $attrs = $object->{attributes};
    my $rels  = $object->{relationships};
    my $type  = $object->{type};
    my $primaryKeyLookup = $self->{om}->getPrimaryKeys($type, $attrs);      
    my $rObj = $self->{om}->new_object($type, $primaryKeyLookup);
    my $res = $rObj->load(speculative => 1);
    # apply attributes, apply relationships, save
    foreach my $attr (keys %$attrs) {
        $rObj->$attr($attrs->{$attr});
    }
    foreach my $rel (keys %$rels) {
        if(ref($rels->{$rel}) eq 'ARRAY') {
            # is a 'to many' relationship
            my $many = [];
            foreach my $subObj (@{$rels->{$rel}}) {
                push(@$many, $self->_innerSave($subObj, $user));
            }
            $rObj->$rel($many);
        } else {
            # is a 'to one' relationship
            my $rSubObj = $self->_innerSave($rels->{$rel}, $user);
            $rObj->$rel($rSubObj);
        }
    }
    $rObj->save();
    return $rObj; 
}

sub _initOM {
    my ($self) = @_;
    require ModelSEED::ObjectManager;
    $self->{om} = ModelSEED::ObjectManager->new({
        driver => $self->{driver},
        database => $self->{database},
    });
}
     

1;
