
package EFI::Database::Schema;

use strict;
use warnings;


use constant DBI_MYSQL => 1;
use constant DBI_MARIADB => 2;
use constant DBI_SQLITE => 3;
use constant DBI_MYSQL_NAME => "mysql";
use constant DBI_MARIADB_NAME => "mariadb";
use constant DBI_SQLITE_NAME => "sqlite";

# The number of conditions that can be used when performing a SELECT.
use constant NUM_MULTIVALUE => 1000;


use Exporter qw(import);

my %dbi = qw(DBI_MYSQL DBI_MYSQL_NAME DBI_MARIADB DBI_MARIADB_NAME DBI_SQLITE DBI_SQLITE_NAME);

our @EXPORT_OK = (keys %dbi, values %dbi, 'get_dbi_name', 'get_dbi', 'NUM_MULTIVALUE');
our %EXPORT_TAGS = (
    dbi => [%dbi],
);
Exporter::export_ok_tags('dbi');


sub get_dbi_name {
    my $dbi = shift || "";
    return $dbi{$dbi} // "";
}


sub get_supported_dbi {
    return keys %dbi;
}


1;
__END__

=head1 EFI::Database::Schema

=head2 NAME

B<EFI::Database::Schema> - Perl module containing database schema constants

=head2 SYNOPSIS

    use EFI::Database::Schema qw(:dbi get_dbi_name get_supported_dbi);

    my @dbi = get_supported_dbi();
    foreach my $dbi (@dbi) {
        print "DBI is " . get_dbi_name($dbi) . "\n";
    }

    use EFI::Database::Schema qw(get_dbi_name DBI_MYSQL);
    print "MySQL DBI is " . get_dbi_name(DBI_MYSQL) . "\n";

    use EFI::Database::Schema qw(NUM_MULTIVALUE);
    print "Use " . NUM_MULTIVALUE . " values in SQL WHERE clause to improve performance\n";


=head2 DESCRIPTION

B<EFI::Database::Schema> is a utility module that contains constants for representing database
interfaces used by the Perl B<DBI> module.  The DBI constants are numbers and should always
be compared as integers.  Constants ending in C<_NAME> are also provided for use in config
files.


=head2 METHODS

=head3 C<get_supported_dbi()>

Return a list of the supported database interfaces.

=head4 Returns

A list of the constants listed below in L<CONSTANTS> (e.g. DBI_MYSQL).

=head4 Example Usage

    my @dbi = get_supported_dbi();
    map { print "DBI " . get_dbi_name($_) . \n"; } @dbi;


=head3 C<get_dbi_name($dbi)>

Return the name of the database interface, suitable for config files.

=head4 Parameters

=over

=item C<$dbi>

Database interface name, one of the outputs of C<get_supported_dbi()> or the available
exported constants.

=back

=head4 Returns

One of the name constants listed below in L<CONSTANTS> (e.g. DBI_MYSQL_NAME).

=head4 Example Usage

    my $dbi = $db->getDbiType();
    my $dbiName = get_dbi_name($dbi);
    print "DBI is $dbiName\n";


=head2 CONSTANTS

The DBI interface constants should be compared to each other, and not to strings such
as "mysql".  Database interfaces that are supported include:

=head3 Database Interfaces

=over

=item C<DBI_MYSQL>

The MySQL database interface name (e.g. "mysql").

=item C<DBI_MARIADB>

The MariaDB database interface name (e.g. "mariadb"); usually MySQL can be used
so MariaDB is not typically needed.

=item C<DBI_SQLITE>

The SQLite database interface name (e.g. "sqlite").

=back


=head3 Database Interface Names

The database interfaces also have "names" that can be used to store in and read from
config files.  Constants ending in C<_NAME> are exported and correspond to the database
interface constants from above:

=over

=item C<DBI_MYSQL_NAME>

The user-facing MySQL database interface name (e.g "MySQL").

=item C<DBI_MARIADB_NAME>

The user-facing MariaDB database interface name (e.g. "MariaDB").

=item C<DBI_SQLITE_NAME>

The user-facing SQLite database interface name (e.g. "SQLite").

=back


=head3 Other

The C<NUM_MULTIVALUE> constant can also be exported.  This value is used by scripts to
put multiple values in a C<WHERE> clause in SQL C<SELECT> queries.  For example, rather
than executing 1,000 C<SELECT id FROM PFAM WHERE accession = 'XXX'>, some of the scripts
are configured to execute C<SELECT id FROM PFAM WHERE accession IN ('A', 'B', 'C', ...)>.
The number of entries in the C<WHERE - IN> clause is defined in this module as an optimal
value that has been found to perform well.


=cut

