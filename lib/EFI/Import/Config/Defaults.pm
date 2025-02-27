
package EFI::Import::Config::Defaults;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(get_default_path);

my %files = (
    accession_ids => "accession_ids.txt",
    source_ids => "source_seq.tab",
    filtered_ids => "filtered_seq.tab",
    sequence_metadata => "sequence_metadata.tab",
    sunburst_ids => "sunburst_ids.tab",
    sunburst_data => "sunburst_tax.json",
    import_stats => "import_stats.json",
    all_sequences => "all_sequences.fasta",
    seq_mapping => "seq_mapping.tab",
    blastout => "blastout.tab",
);


sub get_default_path {
    my $file = shift;
    my $path = shift || "";
    if ($files{$file}) {
        return ($path ? "$path/$files{$file}" : $files{$file});
    } else {
        return "";
    }
}


1;

