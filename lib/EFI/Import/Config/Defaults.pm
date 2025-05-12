
package EFI::Import::Config::Defaults;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(get_default_path);

my %files = (
    # output from get_sequence_ids.pl
    source_ids => "source_ids.tab",
    source_meta => "source_seq.tab",
    seq_mapping => "seq_mapping.tab",
    blastout => "blastout.tab",
    source_stats => "source_stats.json",
    unmatched_ids => "unmatched_ids.tab",

    # output from filter_ids.pl
    sequence_meta => "sequence_metadata.tab",
    accession_table => "accession_table.tab",
    import_stats => "import_stats.json",
    retrieval_ids => "retrieval_ids.tab",

    # output from get_sunburst_data.pl
    sunburst_ids => "sunburst_ids.tab",
    sunburst_data => "sunburst_tax.json",

    # output from get_sequences.pl
    all_sequences => "all_sequences.fasta",
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

