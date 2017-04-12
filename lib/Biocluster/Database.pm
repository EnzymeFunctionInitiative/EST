
package Biocluster::Database;

use strict;
use DBI;
use Log::Message::Simple qw[:STD :CARP];
require 'Config.pm';
use Biocluster::Config qw(biocluster_configure);


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    biocluster_configure($self, %args);

    return $self;
}


sub createTable {
    my ($self, $tableName) = @_;

    my $dbh = $self->getHandle();
    my $result = 1;
    eval {
        $dbh->do("CREATE TABLE $tableName");
        1;
    } or do {
        error("Creating table $tableName failed: $@");
        $result = 0;
    };

    $dbh->finish();

    return $result;
}


sub loadTabular {
    my ($self, $tabularFile) = @_;

    my $dbh = $self->getHandle();
    my $result = 1;
    eval {
        $dbh->do("LOAD DATA INFILE '$tabularFile'");
        1;
    } or do {
        error("Loading data from file '$tabularFile' failed: $@", 1);
        $result = 0;
    };

    $dbh->finish();

    return $result;
}












#######################################################################################################################
# UTILITY METHODS
#


sub getHandle {
    my ($self) = @_;

    my $connStr =
        "DBI:mysql" .
        ":database=" . $self->{db_name} .
        ":host=" . $self->{db_host} .
        ":port=" . $self->{db_port};
    
    my $dbh = DBI->connect($connStr, $self->{db_user}, $self->{db_password});

    return $dbh;
}


1;

