
use strict;
use warnings;

use FindBin;
use JSON;

use lib "$FindBin::Bin/../../../lib";

use EFI::Database;
use EFI::Import::Config::Sunburst;
use EFI::Sequence::Collection;
use EFI::Sequence::Type;
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





__END__

