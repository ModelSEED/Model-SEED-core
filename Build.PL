use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'ModelSeedCore',
    dist_abstract       => "Core libraries for the Model SEED",
    license             => 'perl',
    dist_author         => q{Chris Henry <cshenry@mcs.anl.gov>},
    dist_version_from   => 'lib/ModelSEED/FIGMODEL.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => ">= 5.12.0",
        "App::Cmd" => 0,
        "Archive::Tar" => 0, # core
        "Carp" => 0, # core
        "CGI" => 0, # core
        "Class::Autouse" => 0,
        "Class::ISA" => 0,
        "Cwd" => 0, # core
        "DBI" => 0,
        "DBD::SQLite" => 0,
        "DB_File" => 0,
        "Data::Dumper" => 0, # core
        "Data::UUID" => 0,
        "DateTime" => 0,
        "Devel::Size" => 0,
        "Digest::MD5" => 0, # core
        "Encode" => 0, # core
        "Exporter" => 0, # core
        "Fcntl" => 0, # core
        "File::Basename" => 0, # core
        "File::Copy" => 0, # core
        "File::Copy::Recursive" => 0,
        "File::HomeDir" => 0,
        "File::Path" => ">= 2.08", # core
        "File::Temp" => 0, # core
        "File::stat" => 0, # core
        "FileHandle" => 0, # core
        "Getopt::Long" => 0, # core
        "HTTP::Request" => 0,
        "HTTP::Response" => 0,
        "IO::Compress::Gzip" => 0, # core
        "IO::Prompt::Tiny" => 0,
        "IO::Socket::INET" => 0, # core
        "IO::Uncompress::Gunzip" => 0, # core
        "IPC::Open2" => 0, # core
        "IPC::Open3" => 0, # core
        "IPC::Run" => 0,
        "JSON" => 0,
        "JSON::Any" => 0,
        "LWP::Simple" => 0,
        "LWP::UserAgent" => 0,
        "List::MoreUtils" => 0,
        "List::Util" => 0, # core
        "MIME::Base64" => 0, # core
        "Moose" => 0,
        "Moose::Role" => 0,
        "Moose::Util::TypeConstraints" => 0,
        "MooseX::NonMoose" => 0,
        "MooseX::Role::Parameterized" => 0,
        "MooseX::Singleton" => 0.27,
        "MooseX::Storage" => 0,
        "MooseX::Storage::Format::JSON" => 0,
        "POSIX" => 0,
        "Pod::Usage" => 0, # core
        "SOAP::Lite" => 0,
        "Scalar::Util" => 0, # core
        "Spreadsheet::WriteExcel" => 0,
        "Storable" => 0, # core
        "Symbol" => 0, # core
        "Test::More" => 0,
        "Tie::IxHash" => 0,
        "Time::HiRes" => 0,
        "Time::localtime" => 0,
        "Time::ParseDate" => 0,
        "Try::Tiny" => 0,
        "URI" => 0,
        "URI::Escape" => 0,
        "URI::Split" => 0,
        "XML::DOM" => 0,
        "XML::LibXML" => 0,
        "XML::Simple" => 0,
        "YAML" => 0,
        "YAML::Any" => 0,
		"YAML::XS" => 0,
        "namespace::autoclean" => 0,
    },
    recommends => {
        'IO::Prompt' => 0,
    },
    recursive_test_files => 1,
    add_to_cleanup      => [ 'ModelSeedCore-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
