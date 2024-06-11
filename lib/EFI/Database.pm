
package EFI::Database;

use strict;
use DBI;
use Log::Message::Simple qw[:STD :CARP];
require 'Config.pm';
use EFI::Config qw(cluster_configure);


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    cluster_configure($self, %args);

    if (exists $args{load_infile}) {
        $self->{load_infile} = $args{load_infile};
    } else {
        $self->{load_infile} = 0;
    }

    return $self;
}


#sub createTable {
#    my ($self, $tableName) = @_;
#
#    my $dbh = $self->getHandle();
#    my $result = 1;
#    eval {
#        $dbh->do("CREATE TABLE $tableName");
#        1;
#    } or do {
#        error("Creating table $tableName failed: $@");
#        $result = 0;
#    };
#
#    $dbh->finish();
#
#    return $result;
#}


sub loadTabular {
    my ($self, $tableName, $tabularFile) = @_;

    my $dbh = $self->getHandle();
    my $result = 1;
    eval {
        $dbh->do("load data local infile '$tabularFile' into table $tableName");
        1;
    } or do {
        error("Loading data from file '$tabularFile' failed: $@", 1);
        $result = 0;
    };

    $dbh->disconnect();

    return $result;
}


sub stuff {

#grant select,execute,show view on `efi_20170412`.* to 'efignn'@'10.1.0.0/255.255.0.0';
}


sub tableExists {
    my ($self, $tableName, $dbhCache) = @_;

    my $dbh = $dbhCache ? $dbhCache : $self->getHandle();

    my $sth = $dbh->table_info('', '', '', 'TABLE');
    while (my (undef, undef, $name) = $sth->fetchrow_array()) {
        if ($tableName eq $name) {
            $dbh->disconnect() if not $dbhCache;
            return 1;
        }
    }

    $dbh->disconnect() if not $dbhCache;

    return 0;
}


sub dropTable {
    my ($self, $tableName) = @_;

    my $dbh = $self->getHandle();

    my $ok = $dbh->do("drop table $tableName");

    $dbh->disconnect();

    return $ok;
}


sub createTable {
    my ($self, $schema) = @_;

    my $dbh = $self->getHandle();

    my @sql = $schema->getCreateSql();
    my $ok;
    foreach my $sql (@sql) {
        $ok = $dbh->do($sql);
    }

    $dbh->disconnect();

    return $ok;
}


# Private
sub getVersion {
    my ($self, $dbh) = @_;

    if (exists $self->{db_version}) {
        return $self->{db_version};
    }

    my $ver = 0;

    if ($self->tableExists("version", $dbh)) {
        my $sth = $dbh->prepare("SELECT * FROM version LIMIT 1");
        $sth->execute();
        my $row = $sth->fetchrow_hashref();
        if ($row) {
            $ver = $row->{db_version};
        }
    }

    $self->{db_version} = $ver;

    return $ver;
}













#######################################################################################################################
# UTILITY METHODS
#


sub getCommandLineConnString {
    my ($self) = @_;

    my $connStr ="";
    if ($self->{db}->{dbi} eq EFI::Config::DATABASE_MYSQL) {
        $connStr =
            "mysql"
            . " -u " . $self->{db}->{user}
            . " -p"
            . " -P " . $self->{db}->{port}
            . " -h " . $self->{db}->{host};
    } else {
        $connStr = "sqlite3 $self->{db}->{name}";
    }

    return $connStr;
}


sub getHandle {
    my ($self) = @_;

    my $dbh;
    if ($self->{db}->{dbi} eq EFI::Config::DATABASE_MYSQL) {
        my $connStr =
            "DBI:mysql" .
            ":database=" . $self->{db}->{name} .
            ":host=" . $self->{db}->{host} .
            ":port=" . $self->{db}->{port};
        $connStr .= ";mysql_local_infile=1" if $self->{load_infile};
    
        $dbh = DBI->connect($connStr, $self->{db}->{user}, $self->{db}->{password});
        $dbh->{mysql_auto_reconnect} = 1;
    } else {
        $dbh = DBI->connect("DBI:SQLite:dbname=$self->{db}->{name}","","");
    }

    return $dbh;
}


1;

