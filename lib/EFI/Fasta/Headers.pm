
package EFI::Fasta::Headers;

use File::Basename;
use Cwd qw(abs_path);
use strict;
use lib abs_path(dirname(__FILE__)) . "/../../";
use Exporter;
use EFI::IdMapping;
use EFI::IdMapping::Util;
use EFI::Database;


use constant HEADER     => 1;
use constant SEQUENCE   => 2;
use constant FLUSH      => 3;

our @ISA        = qw(Exporter);
our @EXPORT     = qw();
our @EXPORT_OK  = qw(get_fasta_header_ids);



sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    die "config_file_path argument must be passed to EFI::Fasta::Headers." if not exists $args{config_file_path};

    $self->reset();
    $self->{id_mapper} = new EFI::IdMapping(config_file_path => $args{config_file_path});
    $self->{db_obj} = new EFI::Database(%args);
    $self->{dbh} = $self->{db_obj}->getHandle();

    return $self;
}


sub finish {
    my ($self) = @_;

    $self->{dbh}->disconnect();
}


sub get_primary_id {
    my ($self) = @_;

    return defined $self->{primary_id} ? $self->{primary_id} : "";
}


sub get_fasta_header_ids {
    my ($line) = @_;

    chomp $line;
    my @ids;

    my @headers = split(m/[>\|]/, $line);
    foreach my $id (@headers) {
        next if $id =~ m/^\s*$/;
        #$id =~ s/^\s*([^\|]+\|)?([^\s\|]+).*$/$2/;
        #$id =~ s/^\s*(tr|sp)\|([^\s\|]+).*$/$2/;
        $id =~ s/^\s*(\S+)\s*.*$/$1/;
        next if length $id < 5;
        push(@ids, $id); # if (check_id_type($id) ne UNKNOWN);
    }

    return @ids;
}


sub reset {
    my ($self) = @_;

    $self->{other_ids} = [];
    $self->{raw_headers} = "";
    $self->{uniprot_ids} = [];
    $self->{duplicates} = {};
}


sub parse_line_for_headers {
    my ($self, $line) = @_;

    my $result = { state => HEADER, ids => [], primary_id => undef };

    # This flag treats the line as an option C style format where the ID format is unknown.
    my $saveAsUnknownHeader = 0;

    # This checks the user-fasta Option C case.
    if ($line =~ m/^>z/) {
        $saveAsUnknownHeader = 1;

    # Handle multiple headers on a single line.
    } elsif ($line =~ m/>/) {
        $self->{raw_headers} .= $line;
        $saveAsUnknownHeader = 1;
        # Iterate over each ID in the header line to check if we know anything about it.
        foreach my $id (get_fasta_header_ids($line)) {
            # Check the ID type and if it's unknown, we add it to the ID list and move on.
            my $idType = check_id_type($id);
            if ($idType eq EFI::IdMapping::Util::UNKNOWN) {
                next;
            }

            $saveAsUnknownHeader = 0; # We found a valid header so don't treat this line as an unknown format (Option C)

            # Check if the ID is in the idmapping database
            my $upId = $id;
            $upId =~ s/\..+$// if $idType eq EFI::IdMapping::Util::UNIPROT;
            if ($idType ne EFI::IdMapping::Util::UNIPROT) {
                my ($uniprotId, $noMatch) = $self->{id_mapper}->reverseLookup($idType, $id);
                if (defined $uniprotId and $#$uniprotId >= 0) {
                    $upId = $uniprotId->[0];
                    $idType = EFI::IdMapping::Util::UNIPROT;
                }
            }

            # Check if we known anything about the accession ID by querying the database.
            if ($idType eq EFI::IdMapping::Util::UNIPROT) {
                my $sql = "select accession from annotations where accession = '$upId'";
                my $sth = $self->{dbh}->prepare($sql);
                $sth->execute();

                # We need to have a primary ID so we set that here if we haven't yet.
                if ($sth->fetch) {
                    if (not grep { $_->{uniprot_id} eq $upId } @{ $self->{uniprot_ids} }) {
                        push(@{ $self->{uniprot_ids} }, { uniprot_id => $upId, other_id => $id });
                        $self->{duplicates}->{$upId} = [];
                    } elsif (not grep { $_->{other_id} eq $id } @{ $self->{uniprot_ids} }) {
                        push(@{ $self->{duplicates}->{$upId} }, $id) if not grep { $_ eq $id } @{ $self->{duplicates}->{$upId} };
                    }
                } else {
                    push(@{ $self->{other_ids} }, $id);
                }
            } else {
                push(@{ $self->{other_ids} }, $id);
            }
        }
    } else {
        # If the line doesn't contain a whitespace character, and we have some IDs, we assume we have just
        # finished parsing the header, so we write the header info and reset the variables.
        if ($line =~ m/\S/ and $self->{raw_headers}) { #$#{ $self->{other_ids} } >= 0) {
            $result->{other_ids} = $self->{other_ids};
            ($result->{raw_headers} = $self->{raw_headers}) =~ s/^\s*>(.*?)\s*$/$1/g;
            $result->{raw_headers} =~ s/[\n\r\t]+/ /g;
            $result->{state} = FLUSH;
            $result->{uniprot_ids} = $self->{uniprot_ids};
            $result->{duplicates} = $self->{duplicates};
            # Reset for the next header
            $self->reset();
        } else {
            $result->{state} = SEQUENCE;
        }
    }

    if ($saveAsUnknownHeader) {
        ($self->{primary_id} = $line) =~ s/^>//;
        push(@{ $self->{cur_ids} }, $self->{primary_id});
    }

    return $result;
}


1;


