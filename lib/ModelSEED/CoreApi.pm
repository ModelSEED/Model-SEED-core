package ModelSEED::CoreApi;

use strict;
use warnings;
use DBI;

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

sub new {
    my ($class, $args) = @_;

    my $self = {};

    # create the dbi connection
    my $dsn;
    if ($args->{driver} eq "sqlite") {
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
    my ($self, $uuid, $user) = @_;

    # get the biochemistry object
    my $bio_sql = "SELECT * FROM biochemistries"
	. " WHERE uuid = ?";

    my $rows = $self->{dbi}->selectall_arrayref($bio_sql, undef, $uuid);

    unless (scalar @$rows == 1) {
	die "Unable to find biochemistry with uuid: $uuid";
    }

    my $biochem = _parseBiochemRow($rows->[0]);

    # get the reactions
    my $rxns = $self->getReactions($uuid);
    $biochem->{relationships}->{reactions} = $rxns;

    my $cpds = $self->getCompounds($uuid);
    $biochem->{relationships}->{compounds} = $cpds;

    return $biochem;
}

sub getBiochemistrySimple {
    my ($self, $uuid, $user) = @_;

    # get the biochemistry object
    my $bio_sql = "SELECT * FROM biochemistries"
	. " WHERE uuid = ?";

    my $rows = $self->{dbi}->selectall_arrayref($bio_sql, undef, $uuid);

    unless (scalar @$rows == 1) {
	die "Unable to find biochemistry with uuid: $uuid";
    }

    my $biochem = _parseBiochemRow($rows->[0]);

    my $rxn_ids = $self->{dbi}->selectall_arrayref("SELECT reaction_uuid FROM biochemistry_reactions WHERE biochemistry_uuid = ?", undef, $uuid);

    $biochem->{relationships}->{reactions} = [];
    foreach my $rxn_row (@$rxn_ids) {
	push(@{$biochem->{relationships}->{reactions}}, $rxn_row->[0]);
    }

    return $biochem;
}

sub _parseBiochemRow {
    my ($row) = @_;

    my $ind = 0;
    my $biochem = {
	type => "Biochemistry",
	attributes => {},
	relationships => {}
    };

    foreach my $col (@$biochem_cols) {
	$biochem->{attributes}->{$col} = $row->[$ind++];
    }

    return $biochem;
}

sub getReactions {
    my ($self, $bio_uuid, $query, $limit, $offset) = @_;

    my $sub_sql = "SELECT reaction_uuid"
	. " FROM biochemistry_reactions"
	. " WHERE biochemistry_uuid = ?";

    if (defined($offset) && defined($limit)) {
	$sub_sql .= " LIMIT $limit OFFSET $offset";
    }

    # get the reactions
    my $sql = "SELECT * FROM reactions"
#	. " JOIN biochemistry_reactions ON reactions.uuid = biochemistry_reactions.reaction_uuid"
	. " JOIN reagents ON reactions.uuid = reagents.reaction_uuid"
#	. " LEFT JOIN reaction_aliases ON reactions.uuid = reaction_aliases.reaction_uuid"
#	. " LEFT JOIN reactionset_reactions ON reactions.uuid = reactionset_reactions.reaction_uuid"
#	. " LEFT JOIN reactionsets ON reactionset_reactions.reactionset_uuid = reactionsets.uuid"
	. " WHERE reactions.uuid IN"
	. " ($sub_sql)";

    # parse the query, if it exists
    if (defined($query) && scalar @$query > 0) {
	$sql .= " AND " . _parseQuery($query);
    }

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $bio_uuid);

    # return empty set if no reactions
    if (scalar @$rows == 0) {
	return [];
    }

    # joining is contingent upon a couple facts:
    #  1. every reaction has >= 1 reagent
    #  2. rows are returned with reagents grouped
    #      for example a reaction with 5 reagents will have all 5 rows
    #      grouped together, so we can loop over these rows instead
    #      of building an unneeded hash
    my $rxns = [];
    my $rxn = _parseReactionRow($rows->[0]);
    my $rgns = [_parseReagentRow($rows->[0])];
    shift(@$rows);

    foreach my $row (@$rows) {
	if ($rxn->{attributes}->{uuid} ne $row->[0]) {
	    $rxn->{relationships}->{reagents} = $rgns;
	    push(@$rxns, $rxn);

	    $rxn = _parseReactionRow($row);
	    $rgns = [];
	}

	push(@$rgns, _parseReagentRow($row));
    }

    # get the last reaction
    $rxn->{relationships}->{reagents} = $rgns;
    push(@$rxns, $rxn);

    return $rxns;
}

sub getReaction {
    my ($self, $rxn_uuid, $bio_uuid) = @_;

    # call getReactions with uuid query
    my $rxns = $self->getReactions($bio_uuid, [['reactions.uuid', $rxn_uuid]]);

    if (scalar @$rxns == 1) {
	return $rxns->[0];
    } else {
	return undef;
    }
}

sub _parseReactionRow {
    my ($row) = @_;

    my $ind = 0;
    my $rxn = {
	type => "Reaction",
	attributes => {},
	relationships => {}
    };

    foreach my $col (@$reaction_cols) {
	$rxn->{attributes}->{$col} = $row->[$ind++];
    }

    return $rxn;
}

sub _parseReagentRow {
    my ($row) = @_;

    my $ind = scalar @$reaction_cols;
    my $rgn = {
	type => "Reagent",
	attributes => {}
    };

    foreach my $col (@$reagent_cols) {
	$rgn->{attributes}->{$col} = $row->[$ind++];
    }

    return $rgn;
}

sub getCompounds {
    my ($self, $bio_uuid, $query) = @_;

    # get the compounds
    my $sql = "SELECT compounds.* FROM compounds"
	. " JOIN biochemistry_compounds ON compounds.uuid = biochemistry_compounds.compound_uuid"
	. " WHERE biochemistry_compounds.biochemistry_uuid = ?";

    # parse the query, if it exists
    if (defined($query) && scalar @$query > 0) {
	$sql .= " AND " . _parseQuery($query);
    }

    my $rows = $self->{dbi}->selectall_arrayref($sql, undef, $bio_uuid);

    # return empty set if no compounds
    if (scalar @$rows == 0) {
	return [];
    }

    my $cpds = [];

    foreach my $row (@$rows) {
	push(@$cpds, _parseCompoundRow($row));
    }

    return $cpds;
}

sub getCompound {
    my ($self, $cpd_uuid, $bio_uuid) = @_;

    # call getCompounds with uuid query
    my $cpds = $self->getCompounds($bio_uuid, [['uuid', $cpd_uuid]]);

    if (scalar @$cpds == 1) {
	return $cpds->[0];
    } else {
	return undef;
    }
}

sub _parseCompoundRow {
    my ($row) = @_;

    my $ind = 0;
    my $cpd = {
	type => "Compound",
	attributes => {}
    };

    foreach my $col (@$compound_cols) {
	$cpd->{attributes}->{$col} = $row->[$ind++];
    }

    return $cpd;
}

sub getMedia {

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

1;
