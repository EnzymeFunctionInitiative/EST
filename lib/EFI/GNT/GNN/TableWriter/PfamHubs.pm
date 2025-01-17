
package EFI::GNT::GNN::TableWriter::PfamHubs;

use strict;
use warnings;

use File::Path qw(make_path remove_tree);

# Pfam hub name, meeting cooccurrence threshold
use constant PFAM_HUB_COOC => 1;
# All Pfam hubs, even those that are less than the cooccurrence threshold
use constant PFAM_HUB_ALL => 2;
# Indicates that output files for each constituent Pfam in a hub should be written
use constant PFAM_SPLIT => 4;
# Merge all outputs into one file
use constant MERGED_TABLE => 8;


sub new {
    my $class = shift;
    my %args = @_;

    die "Require colors (EFI::Util::Colors) argument" if not $args{colors};
    die "Require hubs (EFI::GNT::GNN:Hubs) argument" if not $args{hubs};
    die "Require output_dir argument" if not $args{output_dir};

    my $self = {};
    bless $self, $class;

    $self->{colors} = $args{colors};
    $self->{hubs} = $args{hubs};
    $self->{output_dir} = $args{output_dir};

    $self->{pfam_dirs} = {};
    $self->{handles} = {};

    $self->{print_headers} = 1;

    $self->initializeTableOutputs($self->{output_dir});

    return $self;
}


# public
sub writeAllHubTables {
    my $self = shift;
    my $pfamHubName = shift;
    my $hub = shift;
    $self->writeHubTables($pfamHubName, $hub, 0);
}


# public
sub writeFilteredHubTables {
    my $self = shift;
    my $pfamHubName = shift;
    my $hub = shift;
    $self->writeHubTables($pfamHubName, $hub, 1);
}


#
# writeHubTables - private method
#
# Writes the ID list and table data for the given hub to the various output
# files (hub table; filtered/no filter), and all Pfams.
#
# Parameters:
#    $pfamHubName - Pfam hub name (can be multiple families joined with hyphen)
#    $hub - hash ref of cluster numbers to spoke data for a Pfam hub (see
#        EFI::GNT::GNN::Hubs for more detail)
#    $filterOnCooccurrence - 1 to save to the cooccurrence-threshold files,
#        0 to save to the all-clusters files
#
sub writeHubTables {
    my $self = shift;
    my $pfamHubName = shift;
    my $hub = shift;
    my $filterOnCooccurrence = shift;

    my @clusterNums = sort keys %$hub;

    my $tableType = $filterOnCooccurrence ? PFAM_HUB_COOC : PFAM_HUB_ALL;

    my @lines;
    foreach my $clusterNum (@clusterNums) {
        my $cluster = $hub->{$clusterNum};
        my $color = $self->{colors}->getColor($clusterNum);

        foreach my $queryData (@{ $cluster->{query_ids_in_pfam} }) {
            foreach my $nb (@{ $queryData->{neighbors} }) {
                my $distance = sprintf("%02d", abs($nb->{distance}));
                my $clusterId = $clusterNum || "none";
                my @line = ($queryData->{id}, $nb->{id}, $pfamHubName, $clusterId, $color, $distance, "$queryData->{direction}-$nb->{direction}");
                my $line = join("\t", @line);
                push @lines, $line;
            }
        }
    }

    if (@lines) {
        $self->saveRecordsToTables($tableType, $pfamHubName, \@lines);
    }
}


# saveRecordsToTables - private method
#
# Save the records to all of the tables that the records belong to (e.g. the ALL_PFAM
# and split pfam files, etc.).
#
# Parameters:
#    $tableType - the type of table to save to [e.g. all (PFAM_HUB_ALL) or threshold
#        (PFAM_HUB_COOC)]
#    $pfamHubName - the dash-separated Pfam hub name
#    $records - lines to save to the files
#
sub saveRecordsToTables {
    my $self = shift;
    my $tableType = shift;
    my $pfamHubName = shift;
    my $records = shift;

    # Get an output file handle for the Pfam hub name (all family IDs joined);
    # the file path depends on filtering
    my @handles;
    push @handles, $self->getTableFileHandle($tableType, $pfamHubName);

    # Get an output file handle for each Pfam ID (hub split); file path depends
    # on filtering
    my @splitPfams = split(m/\-/, $pfamHubName);
    foreach my $pfam (@splitPfams) {
        push @handles, $self->getTableFileHandle($tableType | PFAM_SPLIT, $pfam);
    }

    # Get an output file handle for ALL Pfams; the file path depends on filtering
    push @handles, $self->getTableFileHandle($tableType | MERGED_TABLE);
    push @handles, $self->getTableFileHandle($tableType | PFAM_SPLIT | MERGED_TABLE);

    # Save the line to every handle that is related to this Pfam hub,
    # including the ALL Pfam output
    foreach my $line (@$records) {
        foreach my $fh (@handles) {
            $fh->print($line, "\n");
        }
    }

    $self->finish();
}


# public
sub finish {
    my $self = shift;

    foreach my $tableType (keys %{ $self->{handles} }) {
        foreach my $name (keys %{ $self->{handles}->{$tableType} }) {
            $self->{handles}->{$tableType}->{$name}->close();
        }
        $self->{handles}->{$tableType} = {};
    }
}


#
# getTableFileHandle - private method
#
# Returns a table file handle for the data type (e.g. Pfam filtered, no filtered)
# and Pfam name (hub or individual).  If the data type/name combination already is
# opened for writing (i.e. cached) then the cached handle is returned.  If the file
# does not already exist then the file is created and opened for writing; the
# output header line is also written.
#
# Parameters:
#    $tableType - one of PFAM_HUB_COOC or PFAM_HUB_ALL, can be combined with
#        PFAM_SPLIT or MERGED_TABLE
#    $name - Pfam name (hub or individual); if not specified then the merged table
#        output handle will be returned
#
# Returns:
#    file handle that is open and ready to write
#
sub getTableFileHandle {
    my $self = shift;
    my $tableType = shift;
    my $name = shift || "ALL_PFAM";

    if ($self->{handles}->{$tableType}->{$name}) {
        return $self->{handles}->{$tableType}->{$name};
    }

    my $outputDir = $self->getOutputDir($tableType & ~MERGED_TABLE);

    my $filePath = "$outputDir/pfam_neighbors_$name.txt";
    if ($tableType & MERGED_TABLE) {
        $filePath = "$outputDir/$name.txt";
    }

    my $fileExists = -e $filePath;

    open my $fh, ">>", $filePath or die "Unable to write to Pfam table $filePath: $!";
    $self->{handles}->{$tableType}->{$name} = $fh;

    if (not $fileExists and $self->{print_headers}) {
        my @headers = $self->getTableHeaders();
        $fh->print(join("\t", @headers), "\n");
    }

    return $fh;
}


#
# initializeTableOutputs - private method
#
# Sets the output directory paths and creates the output directories if they
# do not already exist.
#
# Parameters:
#    $outputDir - path to output dir; multiple Pfam table output dirs will be
#        created in this directory
#
sub initializeTableOutputs {
    my $self = shift;
    my $outputDir = shift;

    # All Pfam hubs, even those that are less than the cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_ALL} = "$outputDir/all_pfam";
    # Each Pfam ID from the hub (e.g. hub is split), even those that are less than the cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_ALL | &PFAM_SPLIT} = "$outputDir/all_pfam_split";
    # Pfam hub name, meeting cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_COOC} = "$outputDir/pfam";
    # Each Pfam ID from the hub (e.g. hub is split), meeting cooccurrence threshold
    $self->{pfam_dirs}->{&PFAM_HUB_COOC | &PFAM_SPLIT} = "$outputDir/pfam_split";

    foreach my $tableType (keys %{ $self->{pfam_dirs} }) {
        my $dir = $self->getOutputDir($tableType);
        remove_tree($dir) if -e $dir;
        make_path($dir) or die "Unable to create table output directory $dir: $!";
        $self->{handles}->{$tableType} = {};
    }
}


#
# getOutputDir  - private method
#
# Returns the path to an output directory for a given table type.
#
# Parameters:
#    $tableType - the type of table (a combination of the PFAM_* flags)
#
# Returns:
#    path to a directory
#
sub getOutputDir {
    my $self = shift;
    my $tableType = shift;
    my $outputDir = $self->{pfam_dirs}->{$tableType};
    return $outputDir;
}


#
# getTableHeaders - private method
# 
# Returns a list of headers that are writte to every table file created.
#
# Returns:
#    An array of headers
#
sub getTableHeaders {
    my $self = shift;
    my @headers = ("Query ID", "Neighbor ID", "Neighbor Pfam", "SSN Query Cluster #", "SSN Query Cluster Color", "Query-Neighbor Distance", "Query-Neighbor Directions");
    return @headers;
}


1;
__END__


# Initialize directory for all the query IDs in all of the Pfam hubs, grouped by hub name
# (e.g. multiple family IDs joined by hyphen).  All hubs are considered, i.e. no
# filtering by cooccurrence is performed.
PFAM_HUB_ALL

# Initialize directory for all the query IDs in all of the Pfams, but each Pfam has it's
# own file (e.g. the hub name has been split into the constituent family IDs).
# All hubs are considered, i.e. no filtering by cooccurrence is performed.
(PFAM_HUB_ALL | PFAM_SPLIT)

# Initialize directory for all the query IDs in all of the Pfam hubs, grouped by hub name
# (e.g. multiple family IDs joined by hyphen).  The hubs are filtered by cooccurrence.
PFAM_HUB_COOC

# Initialize directory for all the query IDs in all of the Pfams, but each Pfam has it's
# own file (e.g. the hub name has been split into the constituent family IDs).
# The hubs are filtered by cooccurrence.
(PFAM_HUB_COOC | PFAM_SPLIT)

