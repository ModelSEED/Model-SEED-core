package ModelSEED::DB::Schema;
use Moose;

extends 'DBIx::Class::Schema';

#use Fey::DBIManager::Source;
#use Fey::Loader;
#use Fey::ORM::Schema;
#
#my $source = Fey::DBIManager::Source->new(
#      username => 'root',
#      dsn => 'dbi:mysql:ModelDB;host=localhost' );
#
#my $schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();
#
#has_schema $schema;
#
#__PACKAGE__->DBIManager()->add_source($source);
