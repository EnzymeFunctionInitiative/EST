
package EFI::Database;

use strict;
use warnings;

use DBI;
use Config::IniFiles;

use constant MYSQL => "mysql";


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    die "Require config argument" if not $args{config};

    # Assume config is existing, because validation occurs upstream
    $self->parseConfig($args{config}, $args{db_name});

    return $self;
}


sub isMysql {
    my $self = shift;
    return ($self->{db} and $self->{db}->{dbi} eq MYSQL);
}


sub parseConfig {
    my $self = shift;
    my $efiConfigFile = shift;
    my $dbName = shift || "";

    my $cfg = new Config::IniFiles(-file => $efiConfigFile);
    die "Unable to parse config file: " . join("; ", @Config::IniFiles::errors), "\n" if not defined $cfg;

    my $db = {};
    $db->{user} = $cfg->val("database", "user");
    $db->{password} = $cfg->val("database", "password");
    $db->{host} = $cfg->val("database", "host", "localhost");
    $db->{port} = $cfg->val("database", "port", "3306");
    $db->{ip_range} = $cfg->val("database", "ip_range", "");
    $db->{dbi} = lc $cfg->val("database", "db", MYSQL);

    if ($dbName) {
        $db->{name} = $dbName;
    } else {
        $db->{name} = $cfg->val("database", "name");
    }
    die "Missing database name\n" if not $db->{name};

    if ($db->{dbi} eq MYSQL) {
        die "Missing database username\n" if not defined $db->{user};
        die "Missing database password\n" if not defined $db->{password};
    }

    $self->{db} = $db;
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
    if ($self->{db}->{dbi} eq MYSQL) {
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

    if ($self->{dbh}) {
        return $self->{dbh};
    }

    my $dbh;
    if ($self->{db}->{dbi} eq MYSQL) {
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

    $self->{dbh} = $dbh;

    return $dbh;
}


1;

