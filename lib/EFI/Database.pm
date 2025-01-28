
package EFI::Database;

use strict;
use warnings;

use DBI;
use Config::IniFiles;

use constant DBI_MYSQL => 1;
use constant DBI_MARIADB => 2;
use constant DBI_SQLITE => 3;
use constant DBI_MYSQL_NAME => "mysql";
use constant DBI_MARIADB_NAME => "mariadb";
use constant DBI_SQLITE_NAME => "sqlite";

use Exporter qw(import);

our @EXPORT_OK = qw(DBI_MYSQL DBI_MYSQL_NAME DBI_MARIADB DBI_MARIADB_NAME DBI_SQLITE DBI_SQLIT_NAME);
our %EXPORT_TAGS = (
    dbi => ['DBI_MYSQL', 'DBI_MARIADB', 'DBI_SQLITE', 'DBI_MYSQL_NAME', 'DBI_MARIADB_NAME', 'DBI_SQLITE_NAME'],
);
Exporter::export_ok_tags('dbi');


use constant ERR_DBI => 1;
use constant ERR_AUTH => 2;
use constant ERR_DB_NAME => 4;
use constant ERR_HOST => 8;
use constant ERR_UNKNOWN => 16;

my %ERROR_MSG = (
    &ERR_DBI => "Invalid database interface",
    &ERR_AUTH => "Invalid username or password",
    &ERR_DB_NAME => "Invalid database name",
    &ERR_HOST => "Invalid database host",
    &ERR_UNKNOWN => "Other",
);


sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};
    bless($self, $class);

    die "Require config argument" if not $args{config};

    # Assume config file is existing, because validation should occur upstream
    $self->parseConfig($args{config}, $args{db_name});

    return $self;
}


# public
sub getDbiType {
    my $self = shift;
    return $self->{dbi};
}


#
# parseConfig - private method
#
# Parse a config file (e.g. 'efi.config') for database connection info.
#
# Parameters:
#    $efiConfigFile - path to configuration file
#    $dbName - optional, name of database; overrides database name in config file
#
sub parseConfig {
    my $self = shift;
    my $efiConfigFile = shift;
    my $dbName = shift || "";

    my $cfg = new Config::IniFiles(-file => $efiConfigFile);
    die "Unable to parse config file: " . join("; ", @Config::IniFiles::errors), "\n" if not defined $cfg;

    $self->{user} = $cfg->val("database", "user");
    $self->{password} = $cfg->val("database", "password");
    $self->{host} = $cfg->val("database", "host", "localhost");
    $self->{port} = $cfg->val("database", "port", "3306");

    my $dbi = lc $cfg->val("database", "dbi", DBI_MYSQL);
    if ($dbi eq DBI_MYSQL_NAME) {
        $self->{dbi} = DBI_MYSQL;
    } elsif ($dbi eq DBI_SQLITE_NAME) {
        $self->{dbi} = DBI_SQLITE;
    } elsif ($dbi eq DBI_MARIADB_NAME) {
        $self->{dbi} = DBI_MARIADB;
    } else {
        $self->{error} = ERR_DBI;
        return 0;
    }

    if ($self->{dbi} == DBI_MYSQL or $self->{dbi} == DBI_MARIADB) {
        if (not $self->{user} or not $self->{password}) {
            $self->{error} = ERR_AUTH;
            return 0;
        }
        if (not $self->{host} or not $self->{port}) {
            $self->{error} = ERR_HOST;
            return 0;
        }
    }

    # Database must come from argument or from config file
    if ($dbName) {
        $self->{name} = $dbName;
    } else {
        $self->{name} = $cfg->val("database", "name");
    }

    if (not $self->{name}) {
        $self->{error} = ERR_DB_NAME;
        return 0;
    }

    return 1;
}


#
# tableExists - private method
#
# Checks if the given table exists in the database.  If the database isn't
# specified then a connection is made.
#
# Parameters:
#    $tableName - name of the table to check for
#    $dbhCache - optional existing database connection handle
#
# Returns:
#    1 if table exists, 0 otherwise
#
sub tableExists {
    my $self = shift;
    my $tableName = shift;
    my $dbhCache = shift;

    my $dbh = $dbhCache ? $dbhCache : $self->getHandle();

    my $sth = $dbh->table_info('', '', '', 'TABLE');
    while (my (undef, undef, $name) = $sth->fetchrow_array()) {
        if ($tableName eq $name) {
            $dbh->disconnect() if not $dbhCache;
            return 1;
        }
    }

    # Disconnect from database if we opened it in this method
    $dbh->disconnect() if not $dbhCache;

    return 0;
}


# public
sub getHandle {
    my $self = shift;

    # If there was an error during creation (e.g. file parsing) then indicate that here
    if ($self->{error}) {
        return undef;
    }

    # Return already created handle if one exists
    if ($self->{dbh}) {
        return $self->{dbh};
    }

    my $dbh;
    if ($self->{dbi} == DBI_MYSQL or $self->{dbi} == DBI_MARIADB) {
        my $dbi = $self->{dbi} == DBI_MARIADB ? "MariaDB" : "mysql";
        my $connStr =
            "DBI:$dbi" .
            ":database=" . $self->{name} .
            ":host=" . $self->{host} .
            ":port=" . $self->{port};
        $connStr .= ";mysql_local_infile=1" if $self->{load_infile};

        eval {
            $dbh = DBI->connect($connStr, $self->{user}, $self->{password});
        };
        if ($@) {
            $self->parseError($@);
            return undef;
        }

        $dbh->{mysql_auto_reconnect} = 1 if $self->{dbi} == DBI_MYSQL;
    } elsif ($self->{dbi} == DBI_SQLITE) {
        eval {
            $dbh = DBI->connect("DBI:SQLite:dbname=$self->{name}","","");
        };
        if ($@) {
            $self->parseError($@);
            return undef;
        }
    }

    $self->{dbh} = $dbh;

    return $dbh;
}


#
# parseError - private method
#
# Parse errors output from the DBI connect method.  Sets an internal
# variable with the error number.
#
# Parameters:
#    $error - the error captured by the eval command when calling DBI->connect
#
sub parseError {
    my $self = shift;
    my $error = shift;

    if ($error =~ m/install_driver/s) {
        $self->{error} = ERR_DBI;
    } elsif ($error =~ m/Access denied/s) {
        $self->{error} = ERR_AUTH;
    } elsif ($error =~ m/Unknown database/s) {
        $self->{error} = ERR_DB_NAME;
    } elsif ($error =~ m/Unknown .*host/s) {
        $self->{error} = ERR_HOST;
    } else {
        $self->{error} = ERR_UNKNOWN;
    }
}


sub getError {
    my $self = shift;
    if ($self->{error}) {
        return $ERROR_MSG{$self->{error}};
    } else {
        return "";
    }
}


1;
__END__

=pod

=head1 EFI::Database

=head2 NAME

B<EFI::Database> - Perl module for creating connections to databases

=head2 SYNOPSIS

    # Perform $gnn computations and save data
    my $gnn = new EFI::GNT::GNN(...);


=head2 DESCRIPTION

B<EFI::Database> is a Perl module used to create connections to databases
using a configuration file that specifies the database interface and 
connection parameters.


=head2 METHODS

=head3 C<new(config =E<gt> $configFile, db_name =E<gt> $dbName)>

Creates a new B<EFI::Database> instance using the parameters in the config
file and the optional C<db_name> argument.

=head4 Parameters

=over

=item C<$configFile>

Path to a configuration file that contains parameters such as username
and password.  See L</"configuration file format"> for information about
the format.

=item C<$dbName>

Name of the database to use.  If the database type is SQLite then this
should be the path to the C<.sqlite> file.

=back

=head4 Example Usage

    # SQLite
    my $dbFile = "efi_db.sqlite";
    my $db = new EFI::Database(config => $configFile, db_name => $dbFile);
    my $dbh = $db->getHandle();
    if (not $dbh) {
        die $db->getError();
    }

    # MySQL
    my $dbName = "efi_202412";
    my $db = new EFI::Database(config => $configFile, db_name => $dbName);
    my $dbh = $db->getHandle();
    if (not $dbh) {
        die $db->getError();
    }


=head3 C<getDbiType()>

Returns the type of the database interface.  Should only be used to compare
to the C<DBI_*> constants.

=head4 Returns

One of C<DBI_MYSQL>, C<DBI_SQLITE>, or C<DBI_MARIADB>.

=head4 Example Usage

    use EFI::Database qw(:dbi);
    my $dbiType = $db->getDbiType();
    if ($dbiType == DBI_MYSQL) {
        print "Database interface is " . DBI_MYSQL_NAME . "\n";
    } elsif ($dbiType == DBI_SQLITE) {
        print "Database interface is " . DBI_SQLITE_NAME . "\n";
    } elsif ($dbiType == DBI_MARIADB) {
        print "Database interface is " . DBI_MARIADB_NAME . "\n";
    }


=head3 C<getHandle()>

Creates a connection to the database and returns a handle as a Perl DBI object.
The connection is cached in the object so if this method is called more than
once, the cached handle is returned.

=head4 Returns

A B<DBI> connection if successful, undef otherwise.

=head4 Example Usage

    my $dbh = $db->getHandle();
    if (not $dbh) {
        print "Error connecting to database: " . $db->getError() . "\n";
    }

    my $sql = "SELECT * FROM table";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while (my $row = $sth->fetchrow_hashref()) {
        processRow($row);
    }


=head3 C<getError()>

Returns an errors that were detected during connection.

=head4 Returns

An empty string of there were no errors, otherwise a non-empty string with
the problem message.

=head4 Example Usage

    my $dbh = $db->getHandle();
    if (not $dbh) {
        print "Error connecting to database: " . $db->getError() . "\n";
    }


=head2 CONFIGURATION FILE FORMAT

The configuration file (e.g. C<efi.config>) that is used throughout the
pipelines contains information for accessing EFI databases.  The file uses
the INI configuration format and the B<Config::IniFiles> Perl module is used
to parse the file.

The file contains a mandatory C<[database]> section with several options
that may or may not be present depending on the database interface (DBI).
Two DBIs are supported: SQLite and MySQL.  The configuration file for the
SQLite DBI is always as follows:

    [database]
    dbi=sqlite

When using MySQL to access EFI databases, the format contains additional
options:

    [database]
    dbi=mysql
    user=<USERNAME>
    password=<PASSWORD>
    host=<HOST>
    port=<PORT>

The C<port> option is optional and defaults to the standard MySQL port
number C<3306>.

Both DBIs may also include the C<name> parameter, which can alternatively 
be specified when the object is instantiated (see C<new()>).

=cut


