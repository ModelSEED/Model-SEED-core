package ModelSEED::CoreApi;

use strict;
use warnings;
use DBI;
use Try::Tiny;


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

my $reaction_rule_cols = ['uuid', 'modDate', 'locked', 'reaction_uuid',
			  'compartment_uuid', 'direction', 'transprotonNature'];

my $complex_role_cols = ['role_uuid', 'optional', 'type'];

my $role_cols = ['uuid', 'modDate', 'locked', 'id', 'name', 'searchname', 'feature_uuid'];

my $roleset_cols = ['uuid', 'modDate', 'locked', 'public', 'id', 'name',
                     'searchname', 'class', 'subclass', 'type'];

my $annotation_cols = ['uuid', 'modDate', 'locked', 'name', 'genome_uuid'];

my $genome_cols = ['uuid', 'modDate', 'locked', 'public', 'id', 'name',
		   'source', 'type', 'taxonomy', 'cksum', 'size', 'genes',
		   'gc', 'gramPositive', 'aerobic'];

my $feature_cols = ['uuid', 'modDate', 'locked', 'id', 'cksum', 'genome_uuid',
		    'start', 'stop', 'role_uuid', 'complete_string'];

my $model_cols = ['uuid', 'modDate', 'locked', 'public', 'id', 'name', 'version', 'type',
		  'status', 'reactions', 'compounds', 'annotations', 'growth',
		  'current', 'mapping_uuid', 'biochemistry_uuid', 'annotation_uuid'];

my $model_compartment_cols = ['uuid', 'modDate', 'locked', 'model_uuid', 'compartment_uuid',
			      'compartmentIndex', 'label', 'pH', 'potential'];

my $model_reaction_cols = ['model_uuid', 'reaction_uuid', 'reaction_rule_uuid', 'direction',
			   'transproton', 'protons', 'model_compartment_uuid'];

my $modelfba_cols = ['uuid', 'modDate', 'locked', 'model_uuid', 'media_uuid',
		     'options', 'geneko', 'reactionko'];

my $modeless_feature_cols = ['feature_uuid', 'modDate', 'growthFraction', 'essential'];

my $modelfba_reaction_cols = ['reaction_uuid', 'min', 'max', 'class'];

my $modelfba_compound_cols = ['compound_uuid', 'min', 'max', 'class'];

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
	reactions    => ['getReactions',    {biochemistry_uuid => $args->{uuid}}],
	compounds    => ['getCompounds',    {biochemistry_uuid => $args->{uuid}}],
	media        => ['getMedia',        {biochemistry_uuid => $args->{uuid}}],
	reactionsets => ['getReactionSets', {biochemistry_uuid => $args->{uuid}}],
	compoundsets => ['getCompoundSets', {biochemistry_uuid => $args->{uuid}}],
	compartments => ['getCompartments', {biochemistry_uuid => $args->{uuid}}]
    };

    $biochem->{relationships} = _getRelationships($self, $args, $with);

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
    $sql = "SELECT reactions.uuid, reactionset_reactions.reactionset_uuid FROM reactions"
	. " JOIN reactionset_reactions ON reactions.uuid = reactionset_reactions.reaction_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $reactionsets = _processJoinedRows($rows, ['reactionset_uuid'], "ReactionSetReaction");

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
    $sql = "SELECT compounds.uuid, compoundset_compounds.compoundset_uuid FROM compounds"
	. " JOIN compoundset_compounds ON compounds.uuid = compoundset_compounds.compound_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $compoundsets = _processJoinedRows($rows, ['compoundset_uuid'], "CompoundSetCompound");

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

    # get the reactionset data
    my $sql = "SELECT * FROM reactionsets"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});

    # return empty set if no reactions
    if (scalar @$rows == 0) {
	return [];
    }

    my $reactionsets = _processRows($rows, $set_cols, "ReactionSet");

    # get the reactions
    $sql = "SELECT reactionset_reactions.* FROM reactionsets"
	. " JOIN reactionset_reactions ON reactionsets.uuid = reactionset_reactions.reactionset_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $reactions = _processJoinedRows($rows, ['reaction_uuid'], "ReactionSetReaction");

    foreach my $set (@$reactionsets) {
	my $uuid = $set->{attributes}->{uuid};

	if (defined($reactions->{$uuid})) {
	    $set->{relationships}->{reactions} = $reactions->{$uuid};
	}
    }

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

    # get the compounds
    $sql = "SELECT compoundset_compounds.* FROM compoundsets"
	. " JOIN compoundset_compounds ON compoundsets.uuid = compoundset_compounds.compoundset_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{biochemistry_uuid});
    my $compounds = _processJoinedRows($rows, ['compound_uuid'], "CompoundSetCompound");

    foreach my $set (@$compoundsets) {
	my $uuid = $set->{attributes}->{uuid};

	if (defined($compounds->{$uuid})) {
	    $set->{relationships}->{compounds} = $compounds->{$uuid};
	}
    }

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
	uuid           => {required => 1},
	user           => {required => 1},
	with_all       => {required => 0},
	with_complexes => {required => 0},
	with_roles     => {required => 0},
	with_rolesets  => {required => 0}
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
	complexes => ['getComplexes', {mapping_uuid => $args->{uuid}}],
	roles     => ['getRoles',     {mapping_uuid => $args->{uuid}}],
	rolesets  => ['getRoleSets',  {mapping_uuid => $args->{uuid}}]
    };

    $mapping->{relationships} = _getRelationships($self, $args, $with);

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

    # get the complex data
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

    # get the complex roles
    $sql = "SELECT complex_roles.* FROM complexes"
	. " JOIN complex_roles ON complexes.uuid = complex_roles.complex_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});
    my $roles = _processJoinedRows($rows, $complex_role_cols, "ComplexRole");

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

sub getRoles {
    my ($self, $args) = @_;

    _processArgs($args, 'getRoles', {
	mapping_uuid => {required => 1},
	query        => {required => 0},
	limit        => {required => 0},
	offset       => {required => 0}
    });

    my $sub_sql = "SELECT role_uuid"
	. " FROM mapping_roles"
	. " WHERE mapping_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE roles.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the role data
    my $sql = "SELECT * FROM roles"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});

    # return empty set if no roles
    if (scalar @$rows == 0) {
	return [];
    }

    my $roles = _processRows($rows, $role_cols, "Role");

    # get the rolesets
    $sql = "SELECT roles.uuid, roleset_roles.roleset_uuid, roleset_roles.modDate FROM roles"
	. " JOIN roleset_roles ON roles.uuid = roleset_roles.role_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});
    my $rolesets = _processJoinedRows($rows, ['uuid', 'modDate'], "RoleSetRole");

    foreach my $role (@$roles) {
	my $uuid = $role->{attributes}->{uuid};

	if (defined($rolesets->{$uuid})) {
	    $role->{relationships}->{rolesets} = $rolesets->{$uuid};
	}
    }

    return $roles;
}

sub getRoleSets {
    my ($self, $args) = @_;

    _processArgs($args, 'getRoleSets', {
	mapping_uuid => {required => 1},
	query        => {required => 0},
	limit        => {required => 0},
	offset       => {required => 0}
    });

    my $sub_sql = "SELECT roleset_uuid"
	. " FROM mapping_rolesets"
	. " WHERE mapping_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE rolesets.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the roleset data
    my $sql = "SELECT * FROM rolesets"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});

    # return empty set if no roles
    if (scalar @$rows == 0) {
	return [];
    }

    my $rolesets = _processRows($rows, $roleset_cols, "RoleSet");

    # get the roles
    $sql = "SELECT roleset_roles.* FROM rolesets"
	. " JOIN roleset_roles ON rolesets.uuid = roleset_roles.roleset_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{mapping_uuid});
    my $roles = _processJoinedRows($rows, ['uuid', 'modDate'], "RoleSetRole");

    foreach my $roleset (@$rolesets) {
	my $uuid = $roleset->{attributes}->{uuid};

	if (defined($roles->{$uuid})) {
	    $roleset->{relationships}->{roles} = $roles->{$uuid};
	}
    }

    return $rolesets;
}

sub getAnnotation {
    my ($self, $args) = @_;

    _processArgs($args, 'getAnnotation', {
	uuid           => {required => 1},
	user           => {required => 1},
	with_all       => {required => 0},
	with_features  => {required => 0},
	with_genome    => {required => 0}
    });

    # get the annotation object
    my $sql = "SELECT * FROM annotations"
	. " WHERE uuid = ?";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{uuid});

    unless (scalar @$rows == 1) {
	die "Unable to find annotation with uuid: " . $args->{uuid};
    }

    my $annotation = _processRows($rows, $annotation_cols, "Annotation")->[0];

    my $with = {
	features => ['getFeatures', {annotation_uuid => $args->{uuid}}],
	genome   => ['getGenome',   {uuid => $annotation->{attributes}->{genome_uuid}}]
    };

    $annotation->{relationships} = _getRelationships($self, $args, $with);

    return $annotation;
}

sub getGenome {
    my ($self, $args) = @_;

    _processArgs($args, 'getGenome', {
	uuid => {required => 1}
    });

    my $sql = "SELECT * FROM genomes WHERE uuid = ?";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{uuid});

    # return undef if no genome
    if (scalar @$rows == 0) {
	return undef;
    }

    my $genome = _processRows($rows, $genome_cols, "Genome")->[0];

    return $genome;
}

sub getFeatures {
    my ($self, $args) = @_;

    _processArgs($args, 'getFeatures', {
	annotation_uuid => {required => 1},
	query           => {required => 0},
	limit           => {required => 0},
	offset          => {required => 0}
    });

    my $sql = "SELECT features.*, annotation_features.role_uuid, annotation_features.complete_string"
	. " FROM features, annotation_features"
	. " WHERE features.uuid = annotation_features.feature_uuid"
	. " AND annotation_features.annotation_uuid = ?";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$sql .= " AND " . _parseQuery($args->{query});
    }

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{annotation_uuid});

    # return empty set if no features
    if (scalar @$rows == 0) {
	return [];
    }

    my $features = _processRows($rows, $feature_cols, "Feature");

    return $features;
}

sub getModel {
    my ($self, $args) = @_;

    _processArgs($args, 'getModel', {
    id                => {required => 0},
	uuid              => {required => 0},
	user              => {required => 1},
	with_all          => {required => 0},
	with_biochemistry => {required => 0},
	with_mapping      => {required => 0},
	with_annotation   => {required => 0},
	with_compartments => {required => 0},
	with_reactions    => {required => 0},
	with_modelfbas    => {required => 0}
    });

    # get the model object
  	my $query = "uuid";
  	if (defined($args->{id})) {
  		$query = "id";	
  	}
    my $sql = "SELECT * FROM models"
	. " WHERE ".$query." = ?";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{$query});

    unless (scalar @$rows == 1) {
	die "Unable to find model with ".$query.": " . $args->{$query};
    }
	
    my $model = _processRows($rows, $model_cols, "Model")->[0];
	$args->{uuid} = $model->{attributes}->{uuid};
    my $with = {
	biochemistry => ['getBiochemistry', {
	    uuid => $model->{attributes}->{biochemistry_uuid},
	    user => $args->{user},
	    with_all => 1}],
	mapping      => ['getMapping', {
	    uuid => $model->{attributes}->{mapping_uuid},
	    user => $args->{user},
	    with_all => 1}],
	annotation   => ['getAnnotation', {
	    uuid => $model->{attributes}->{annotation_uuid},
	    user => $args->{user},
	    with_all => 1}],
	compartments => ['getModelCompartments', {model_uuid => $args->{uuid}}],
	reactions    => ['getModelReactions',    {model_uuid => $args->{uuid}}],
	modelfbas    => ['getModelFBAs',         {model_uuid => $args->{uuid}}]
    };

    $model->{relationships} = _getRelationships($self, $args, $with);

    return $model;
}

sub getModelCompartments {
    my ($self, $args) = @_;

    _processArgs($args, 'getModelCompartments', {
	model_uuid => {required => 1},
	query      => {required => 0},
	limit      => {required => 0},
	offset     => {required => 0}
    });

    my $sql = "SELECT * FROM model_compartments"
	. " WHERE model_compartments.model_uuid = ?";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$sql .= " AND " . _parseQuery($args->{query});
    }

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{model_uuid});

    # return empty set if no model compartments
    if (scalar @$rows == 0) {
	return [];
    }

    my $model_compartments = _processRows($rows, $model_compartment_cols, "ModelCompartment");

    return $model_compartments;
}

sub getModelReactions {
    my ($self, $args) = @_;

    _processArgs($args, 'getModelReactions', {
	model_uuid => {required => 1},
	query      => {required => 0},
	limit      => {required => 0},
	offset     => {required => 0}
    });

    my $sql = "SELECT * FROM model_reactions"
	. " WHERE model_reactions.model_uuid = ?";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$sql .= " AND " . _parseQuery($args->{query});
    }

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{model_uuid});

    # return empty set if no model reactions
    if (scalar @$rows == 0) {
	return [];
    }

    my $model_reactions = _processRows($rows, $model_reaction_cols, "ModelReaction");

    return $model_reactions;
}

sub getModelFBAs {
    my ($self, $args) = @_;

    _processArgs($args, 'getModelFBAs', {
	model_uuid => {required => 1},
	query      => {required => 0},
	limit      => {required => 0},
	offset     => {required => 0}
    });

    my $sub_sql = "SELECT uuid"
	. " FROM modelfbas"
	. " WHERE model_uuid = ?";

    if (defined($args->{offset}) && defined($args->{limit})) {
	$sub_sql .= " LIMIT " . $args->{limit} . " OFFSET " . $args->{offset};
    }

    my $where = "WHERE modelfbas.uuid IN ($sub_sql)";

    # parse the query, if it exists
    if (defined($args->{query}) && scalar @{$args->{query}} > 0) {
	$where .= " AND " . _parseQuery($args->{query});
    }

    # get the modelfba data
    my $sql = "SELECT * FROM modelfbas"
	. " $where";

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{model_uuid});

    # return empty set if no modelfbas
    if (scalar @$rows == 0) {
	return [];
    }

    my $modelfbas = _processRows($rows, $modelfba_cols, "ModelFBA");

    # get the modeless features
    $sql = "SELECT modeless_features.* FROM modelfbas"
	. " JOIN modeless_features ON modelfbas.uuid = modeless_features.modelfba_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{model_uuid});
    my $modeless_features = _processJoinedRows($rows, $modeless_feature_cols, "ModelessFeature");

    # get the reactions
    $sql = "SELECT modelfba_reactions.* FROM modelfbas"
	. " JOIN modelfba_reactions ON modelfbas.uuid = modelfba_reactions.modelfba_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{model_uuid});
    my $reactions = _processJoinedRows($rows, $modelfba_reaction_cols, "ModelFBAReaction");

    # get the compounds
    $sql = "SELECT modelfba_compounds.* FROM modelfbas"
	. " JOIN modelfba_compounds ON modelfbas.uuid = modelfba_compounds.modelfba_uuid"
	. " $where";

    $rows = $self->{dbi}->selectall_arrayref($sql, undef, $args->{model_uuid});
    my $compounds = _processJoinedRows($rows, $modelfba_compound_cols, "ModelFBACompound");

    foreach my $modelfba (@$modelfbas) {
	my $uuid = $modelfba->{attributes}->{uuid};

	if (defined($modeless_features->{$uuid})) {
	    $modelfba->{relationships}->{modeless_features} = $modeless_features->{$uuid};
	}

	if (defined($reactions->{$uuid})) {
	    $modelfba->{relationships}->{reactions} = $reactions->{$uuid};
	}

	if (defined($compounds->{$uuid})) {
	    $modelfba->{relationships}->{compounds} = $compounds->{$uuid};
	}
    }

    return $modelfbas;
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

sub _getRelationships {
    my ($self, $args, $with) = @_;

    my $relationships = {};
    if ($args->{with_all}) {
	foreach my $rel (keys %$with) {
	    my $sub = $with->{$rel}->[0];
	    $relationships->{$rel} = $self->$sub($with->{$rel}->[1]);
	}
    } else {
	foreach my $rel (keys %$with) {
	    if ($args->{"with_".$rel}) {
		my $sub = $with->{$rel}->[0];
		$relationships->{$rel} = $self->$sub($with->{$rel}->[1]);
	    }
	}
    }

    return $relationships;
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
    my ($self, $type, $object, $user) = @_;
    $self->{om}->db->begin_work;
    my $success = 1;
    try {
        $self->_innerSave($type, $object, $user);
    } catch { $success = 0; };
    if($success) {
        $self->{om}->db->commit;
    } else {
        $self->{om}->db->rollback;
    }
    return $success;
}

sub _innerSave {
    my ($self, $type, $object, $user) = @_;
    if(!defined($self->{om})) {
        # until we get moose lazy loaders in here
        $self->_initOM();
    }
    my $attrs = $object->{attributes};
    my $rels  = $object->{relationships};
    #$type = $object->{type};
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
                push(@$many, $self->_innerSave($subObj->{type}, $subObj, $user));
            }
            $rObj->$rel($many);
        } else {
            # is a 'to one' relationship
            my $rSubObj = $self->_innerSave($rel->{type}, $rels->{$rel}, $user);
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
