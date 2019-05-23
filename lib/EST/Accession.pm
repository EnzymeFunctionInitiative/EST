
package EST::Accession;

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFI_SHARED};
    use lib $ENV{EFI_SHARED};
}

use warnings;
use strict;

use Data::Dumper;
use Getopt::Long qw(:config pass_through);
use Exporter;
use List::MoreUtils qw(uniq);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(getAccessionCmdLineArgs);
@EXPORT_OK   = qw();

use EFI::IdMapping;

use base qw(EST::Base);
use EST::Base;


sub new {
    my $class = shift;
    my %args = @_;
    
    my $self = EST::Base->new(%args);

    die "No dbh provided" if not exists $args{dbh};
    die "No config parameter provided" if not exists $args{config_file_path};

    $self->{config_file_path} = $args{config_file_path};
    $self->{dbh} = $args{dbh};
    $self->{data} = {};

    return bless $self, $class;
}


# Public
sub configure {
    my $self = shift;
    my %args = @_;

    die "No accession ID file provided" if not $args{id_file} or not -f $args{id_file};

    $self->{config}->{id_file} = $args{id_file};
    $self->{config}->{domain_family} = $args{domain_family};
}


# Public
# Look in @ARGV
sub getAccessionCmdLineArgs {

    my ($idFile);
    my $result = GetOptions(
        "accession-file|id-file=s"      => \$idFile,
    );

    $idFile = "" if not $idFile;

    return (id_file => $idFile);
}


# Public
sub parseFile {
    my $self = shift;
    my $file = shift || $self->{config}->{id_file};

    if (not $file or not -f $file) {
        warn "Unable to parse accession file: invalid parameters";
        return 0;
    }

    open ACCFILE, $file or die "Unable to open user accession file $file: $!";
    
    # Read the case where we have a mac file (CR \r only); we read in the entire file and then split.
    my $delim = $/;
    $/ = undef;
    my $line = <ACCFILE>;
    $/ = $delim;

    close ACCFILE;

    my %rawIds;

    my @lines = split /[\r\n\s]+/, $line;
    foreach my $accId (grep m/.+/, map { split(",", $_) } @lines) {
        $rawIds{$accId} = [];
    }

    $self->{data}->{ids} = \%rawIds;

    my $idMapper = new EFI::IdMapping(config_file_path => $self->{config_file_path});
    $self->reverseLookupManualAccessions($idMapper);

    print "DOMAIN : $self->{config}->{domain_family}\n";
    if ($self->{config}->{domain_family}) {
        $self->retrieveDomains();
    }

    $self->{stats}->{num_ids} = scalar keys %rawIds;
}


sub retrieveDomains {
    my $self = shift;

    my $domainFamily = uc($self->{config}->{domain_family});
    my $famTable = $domainFamily =~ m/^PF/ ? "PFAM" : "INTERPRO";
    
    foreach my $id (keys %{$self->{data}->{uniprot_ids}}) {
        my $sql = "SELECT start, end FROM $famTable WHERE $famTable.id = '$domainFamily' AND accession = '$id'";
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            push @{$self->{data}->{uniprot_ids}->{$id}}, {'start' => $row->{start}, 'end' => $row->{end}};
        }
    }
}


# Reverse map any IDs that aren't UniProt.
sub reverseLookupManualAccessions {
    my $self = shift;
    my $idMapper = shift;

    my @ids = keys %{$self->{data}->{ids}};
    my ($upIds, $noMatches, $reverseMap) = $idMapper->reverseLookup(EFI::IdMapping::Util::AUTO, @ids);
    my @accUniprotIds = @$upIds;

    $self->{data}->{uniprot_ids} = {};
    map { $self->{data}->{uniprot_ids}->{$_} = []; } @accUniprotIds;
    my $numUniprotIds = scalar @accUniprotIds;
    my $numNoMatches = scalar @$noMatches;

    print "There were $numUniprotIds Uniprot ID matches and $numNoMatches no-matches in the input accession ID file.\n";

    my $meta = {};
    foreach my $id (@accUniprotIds) {
        $meta->{$id} = {query_ids => []};
        if (exists $reverseMap->{$id}) {
            $meta->{$id}->{query_ids} = $reverseMap->{$id};
        }
    }

    $self->{data}->{meta} = $meta;

    $self->{stats}->{num_matched} = $numUniprotIds;
    $self->{stats}->{num_unmatched} = $numNoMatches;
}


sub getSequenceIds {
    my $self = shift;

    return $self->{data}->{uniprot_ids}; # contains domain info, if applicable.
}


sub getMetadata {
    my $self = shift;

    my $meta = $self->{data}->{meta};

    return $meta;
}


sub getStatistics {
    my $self = shift;

    return $self->{stats};
}


1;

