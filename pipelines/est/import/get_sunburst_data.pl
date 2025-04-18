
use strict;
use warnings;

use FindBin;
use JSON;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Import::Config::Sunburst;
use EFI::Sequence::Collection;
use EFI::Sunburst::Data;


my $optionParser = new EFI::Import::Config::Sunburst();
my ($status, $help) = $optionParser->validateOptions();
if ($help) {
    print "$help\n";
    exit(not $status); # if error, status is 0, so exit non zero to indicate to shell that there was a problem
}
my $opts = $optionParser->getOptions();


my $efiDb = new EFI::Database(config => $opts->{efi_config_file}, db_name => $opts->{efi_db});
my $dbh = $efiDb->getHandle();


my $seqData = new EFI::Sequence::Collection();
$seqData->load($opts->{sequence_meta_file}, $opts->{accession_table_file});


my $creator = new EFI::Sunburst::Data(dbh => $dbh);

my ($sbData) = $creator->getSunburstTaxonomy($seqData);


saveToJson($sbData, $opts->{sunburst_data_file});












sub saveToJson {
    my $data = shift;
    my $outputFile = shift;

    $data = {
        data => $data,
    };

    open my $fh, ">", $outputFile;

    my $json = JSON->new->canonical(1);
    if ($opts->{pretty_print}) {
        $fh->print($json->pretty->encode($data));
    } else {
        $fh->print($json->encode($data));
    }

    close $fh;
}




1;
__END__

=head1 get_sunburst_data.pl

=head2 NAME

B<get_sunburst_data.pl> - obtain taxonomic data for the input sequences for sunburst diagrams

=head2 SYNOPSIS

    get_sunburst_data.pl --efi-config <EFI_CONFIG_FILE> --efi-db <EFI_DB_FILE>
        [--sequence-meta-file <FILE> --accession-table-file <FILE> --sunburst-data-file <FILE>
        --pretty-print]

=head2 DESCRIPTION

This script takes output from the C<filter_ids.pl> process in the EST pipeline and retrieves
taxonomic information for every sequence in the input.  See B<EFI::Sunburst::Data> for a
description of the output data.


=head3 Arguments

=over

=item C<--efi-config> (required)

The path to the config file used for the database.

=item C<--efi-db> (required)

The path to the SQLite database file or the name of a MySQL/MariaDB database.  The database
connection parameters are specified in the C<--efi-config> file.

=item C<--sequence-meta-file> (required, default value)

Path to the file containing sequence metadata, such as sequence source.
Defaults to C<sequence_metadata.tab> in the current directory.

=item C<--accession-table-file> (required, default value)

Path to the file containing the accession ID mapping table.
Defaults to C<accession_table.tab> in the current directory.

=item C<--sunburst-data-file> (required, default value)

Path to the output file that will contain the JSON data necessary for the web UI to display
sunburst diagrams.
Defaults to C<sunburst_tax.json> in the current directory.

=item C<--pretty-print> (optional)

Indicates if the JSON output should be human-readable.
Defaults to false (compact file format).

=back

