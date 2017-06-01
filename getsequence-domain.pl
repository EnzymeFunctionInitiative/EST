#!/usr/bin/env perl


#version 0.9.0 moved from getting accesions by grepping files to using sqlite database
#version 0.9.0 options of specifing ssf and gene3d numbers added
#version 0.9.2 modified to accept 6-10 characters as accession ids
#version 0.9.3 modified to use cfg file to load location of variables for database
#version 0.9.4 change way cfg file used to load database location

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;
use FindBin;
use lib "$FindBin::Bin/lib";
use Biocluster::IdMapping;
use Biocluster::Config;
use Biocluster::IdMapping::Util;
use Biocluster::Fasta::Headers;
use Biocluster::Database;


#print "config file is located at: ".$ENV{'EFICFG'}."\n";
#$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
#eval $configfile;
#
#print "Configfile is \n > $configfile\n";

my ($ipro, $pfam, $gene3d, $ssf, $access, $maxsequence, $manualAccession, $accessionFile, $fastaFileOut, $fastaFileIn, $metaFileOut, $useFastaHeaders, $domain, $fraction, $noMatchFile, $configFile);
my $result = GetOptions(
    "ipro=s"               => \$ipro,
    "pfam=s"               => \$pfam,
    "gene3d=s"             => \$gene3d,
    "ssf=s"                => \$ssf,
    "accession-output=s"   => \$access,
    "maxsequence=s"        => \$maxsequence,
    "accession-id=s"       => \$manualAccession,
    "accession-file=s"     => \$accessionFile,
    "out=s"                => \$fastaFileOut,
    "fasta-file=s"         => \$fastaFileIn,
    "meta-file=s"          => \$metaFileOut,
    "use-fasta-headers"    => \$useFastaHeaders,
    "domain=s"             => \$domain,
    "fraction=i"           => \$fraction,
    "no-match-file=s"      => \$noMatchFile,
    "config=s"             => \$configFile,
);

die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my @accessions = ();
my $perpass = $ENV{EFIPASS};
my $data_files = $ENV{EFIDBPATH};
my %ids = ();
my %accessionhash = ();

if (defined $domain) {
    unless($domain eq "off" or $domain eq "on") {
        die "domain value must be either on or off\n";
    }
} else {
    $domain="off";
}

if (defined $fraction) {
    unless($fraction =~ /^\d+$/ and $fraction >0) {
        die "if fraction is defined, it must be greater than zero\n";
    }
} else {
    $fraction=1;
}

if (defined $ipro and $ipro ne 0) {
    print ":$ipro:\n";
    @ipros=split /,/, $ipro;
} else {
    @ipros = ();
}

if (defined $pfam and $pfam ne 0) {
    print ":$pfam:\n";
    @pfams=split /,/, $pfam;
} else {
    @pfams = ();
}

if (defined $gene3d and $gene3d ne 0) {
    print ":$gene3d:\n";
    @gene3ds=split /,/, $gene3d;
} else {
    @gene3ds = ();
}

if (defined $ssf and $ssf ne 0) {
    print ":$ssf:\n";
    @ssfs=split /,/, $ssf;
} else {
    @ssfs = ();
}

if (defined $manualAccession and $manualAccession ne 0) {
    print ":manual $manualAccession:\n";
    @manualAccessions = split m/,/, $manualAccession;
} else {
    @manualAccessions = ();
}

if (defined $accessionFile and -f $accessionFile) {
    print ":accessionFile $accessionFile:\n";
    open ACCFILE, $accessionFile or die "Unable to open user accession file $accessionFile: $!";
    
    # Read the case where we have a mac file (CR \r only)
    my $delim = $/;
    $/ = undef;
    my $line = <ACCFILE>;
    $/ = $delim;
    
    my @lines = split /[\r\n\s]+/, $line;
#    my $c = 1;
    foreach my $line (grep m/.+/, map { split(",", $_) } @lines) {
#        if ($fraction == 1 or $c % $fraction == 0) {
            push(@manualAccessions, $line);
#        }
#        $c++;
    }

    print "There were ", scalar @manualAccessions, " manual accession IDs taken from ", scalar @lines, " lines in the accession file\n";
}


unless(defined $maxsequence) {
    $maxsequence=0;
}

die "Config file (--config=...) option is required" unless (defined $configFile and -f $configFile);
my $db = new Biocluster::Database(config_file_path => $configFile);

my $idMapper;
if ($#manualAccessions >= 0) {
    $idMapper = new Biocluster::IdMapping(config_file_path => $configFile);
}


print "Getting Acession Numbers in specified Families\n";

my $dbh = $db->getHandle();


#######################################################################################################################
# GETTING ACCESSIONS FROM INTERPRO FAMILY(S)
#
getDomainFromDb($dbh, "INTERPRO", \%accessionhash, $fraction, @ipros);


#######################################################################################################################
# GETTING ACCESSIONS FROM PFAM FAMILY(S)
#
getDomainFromDb($dbh, "PFAM", \%accessionhash, $fraction, @pfams);


#######################################################################################################################
# GETTING ACCESSIONS FROM GENE3D FAMILY(S)
#
getDomainFromDb($dbh, "GENE3D", \%accessionhash, $fraction, @gene3ds);

#######################################################################################################################
# GETTING ACCESSIONS FROM SSF FAMILY(S)
#
getDomainFromDb($dbh, "SSF", \%accessionhash, $fraction, @ssfs);


# Save the accessions that are specified through a family.
my %inFamilyIds = map { ($_, 1) } keys %accessionhash;


#######################################################################################################################
# PARSE FASTA FILE FOR HEADER IDS (IF ANY)
#
my @fastaUniprotIds;
if ($fastaFileIn =~ /\w+/ and -s $fastaFileIn) {
    $useFastaHeaders = defined $useFastaHeaders ? 1 : 0;
    # Returns the Uniprot IDs that were found in the file.  If there were sequences found that didn't map
    # to a Uniprot ID, they are written to the output FASTA file directly.  The sequences that corresponded
    # to a Uniprot ID are not written, they are retrieved from the sequences below.
    # The '1' parameter tells the function not to apply any fraction computation.
    @fastaUniprotIds = parseFastaHeaders($fastaFileIn, $fastaFileOut, $metaFileOut, $useFastaHeaders, $idMapper, $configFile, 1);
    print "The uniprot ids that were found in the FASTA file:\n", "\t", join("\n\t", @fastaUniprotIds), "\n";
}

#######################################################################################################################
# ADDING MANUAL ACCESSION IDS FROM FILE OR ARGUMENT
#
# Reverse map any IDs that aren't UniProt.
my $uniprotRevMap = {};
my @uniprotIds;
my $noMatches;
if ($#manualAccessions >= 0) { 
    my $upIds = [];
    ($upIds, $noMatches, $uniprotRevMap) = $idMapper->reverseLookup(Biocluster::IdMapping::Util::AUTO, @manualAccessions);
    @uniprotIds = @$upIds;
    print "There were ", scalar @uniprotIds, " matches and ", scalar @$noMatches, " no matches\n";
    print "The uniprot ids that were found in the accession file:\n", "\t", join("\n\t", @uniprotIds), "\n";

    # This code could be used to apply a fraction to the user-supplied IDs, but that doesn't make a lot of sense, does it?
    #my $c = 1;
    #my %dups;
    #foreach my $id (@$upIds) {
    #    next if exists $dups{$id};
    #    $dups{$id} = 1;
    #    if ($fraction == 1 or $c % $fraction == 0) {
    #        push(@uniprotIds, $id);
    #    }
    #    $c++;
    #}
}


my $showNoMatches = $#manualAccessions >= 0 ? 1 : 0 and defined $noMatchFile;
# Write out the no matches to a file.
if ($showNoMatches) {
    open NOMATCH, ">$noMatchFile" or die "Unable to create nomatch file '$noMatchFile': $!";
    foreach my $noMatch (@$noMatches) {
        print NOMATCH "$noMatch\tNOT_FOUND_IDMAPPING\n";
    }
}


#######################################################################################################################
# VERIFY THAT THE ACCESSIONS ARE IN THE DATABASE AND RETRIEVE THE DOMAIN
#
my %inUserIds;
# Lookup each manual accession ID to get the domain as well as verify that it exists.
foreach $element (@uniprotIds, @fastaUniprotIds) {
    $sql = "select accession,start,end from PFAM where accession = '$element'";
    $sth = $dbh->prepare("select accession,start,end from PFAM where accession = '$element'");
    $sth->execute;
    if ($row = $sth->fetch) {
        print NOMATCH "$element\tDUPLICATE\n" if exists $inUserIds{$element} and $showNoMatches;
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
        $inUserIds{$element} = 1;
    } elsif ($element !~ m/^z/) {
        # No PFAM found so we use the entire sequence
        $accessionhash{$element} = [];
        $inUserIds{$element} = 1;
    } else {
        print NOMATCH "$element\tNOT_FOUND_DATABASE\n" if $showNoMatches;
    }
}

$sth->finish if $sth;
$dbh->disconnect();



# Now write out the IDs that were included in the input manual user accession file that mapped back to a Uniprot ID.
#if ($#manualAccessions >= 0) { 
#    open META, "> $metaFileOut";
#    foreach my $id (sort keys %inUserIds) {
#        print META "$id\n";
#        print META "\tSequence_Source\t";
#        if (exists $inUserIds{$id} and exists $inFamilyIds{$id}) {
#            print META "FAMILY+USER";
#        } else {
#            print META "USER";
#        }
#    }
#    close META;
#}

@accessions=keys %accessionhash;
print "Initial " . scalar @accessions . " sequences after manual accessions\n";


#one more unique in case of accessions being added in multiple databases
@accessions=keys %accessionhash;
print scalar @accessions . " total accessions\n";
@accessions=uniq @accessions;
print scalar @accessions . " after uniquing\n";


if (scalar @accessions>$maxsequence and $maxsequence != 0) {
    open ERROR, ">$access.failed" or die "cannot write error output file $access.failed\n";
    print ERROR "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence\n";
    close ERROR;
    die "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence";
}

print "Print out accessions\n";
open GREP, ">$access" or die "Could not write to output accession ID file '$access': $!";
foreach $accession (keys %accessionhash) {
    my @domains = @{$accessionhash{$accession}};
    foreach $piece (@domains) {
        if ($domain eq "off") {
            print GREP "$accession\n";
        } elsif ($domain eq "on") {
            print GREP "$accession:${$piece}{'start'}:${$piece}{'end'}\n"
        } else {
            die "domain must be set to either on or off\n";
        }
    }
}
close GREP;


print "Final accession count " . scalar @accessions . "\n";
print "Retrieving Sequences\n";

use Capture::Tiny ':all';
my @err;

if ($fastaFileIn =~ /\w+/ and -s $fastaFileIn) {
    open OUT, ">>$fastaFileOut" or die "Cannot write to output fasta $fastaFileOut\n";
} else {
    open OUT, ">$fastaFileOut" or die "Cannot write to output fasta $fastaFileOut\n";
}

my @origAccessions = @accessions;
while(scalar @accessions) {
    @batch=splice(@accessions, 0, $perpass);
    $batchline=join ',', @batch;
    my ($fastacmdOutput, $fastaErr) = capture {
        system("fastacmd", "-d", "${data_files}/combined.fasta", "-s", "$batchline");
    };
    push(@err, $fastaErr);
    #print "fastacmd -d $data_files/combined.fasta -s $batchline\n"; #[[[$fastacmdOutput]]]\n";
    @sequences=split /\n>/, $fastacmdOutput;
    $sequences[0] = substr($sequences[0], 1) if $#sequences >= 0 and substr($sequences[0], 0, 1) eq ">";
    foreach $sequence (@sequences) { 
        print "raw $sequence\n";
        if ($sequence =~ s/^\w\w\|(\w{6,10})\|.*//) {
            $accession=$1;
        } else {
            $accession="";
        }
        if ($domain eq "off" and $accession ne "") {
            print OUT ">$accession$sequence\n\n";
        } elsif ($domain eq "on" and $accession ne "") {
            $sequence =~ s/\s+//g;
            my @domains = @{$accessionhash{$accession}};
            if (scalar @domains) {
                foreach my $piece (@domains) {
                    my $thissequence=join("\n", unpack("(A80)*", substr $sequence,${$piece}{'start'}-1,${$piece}{'end'}-${$piece}{'start'}+1));
                    print OUT ">$accession:${$piece}{'start'}:${$piece}{'end'}\n$thissequence\n\n";
                }
            } else {
                print OUT ">$accession$sequence\n\n";
            }
        } elsif ($accession eq "") {
            #do nothing
        } else {
            die "Domain must be either on or off\n";
        }
    }
}
close OUT;


if ($useFastaHeaders) {
    open META, ">>$metaFileOut" or die "Unable to open user fasta ID file '$metaFileOut' for writing: $!";
} else {
    open META, ">$metaFileOut" or die "Unable to open user fasta ID file '$metaFileOut' for writing: $!";
}


foreach my $acc (@origAccessions) {
    print META "$acc\n";
    if (exists $uniprotRevMap->{$acc}) {
        print META "\tQuery_IDs\t", join(",", uniq @{ $uniprotRevMap->{$acc} }), "\n";
    }
    print META "\t", Biocluster::Config::FIELD_SEQ_SRC_KEY, "\t";
    if (exists $inUserIds{$acc} and exists $inFamilyIds{$acc}) {
        print META Biocluster::Config::FIELD_SEQ_SRC_VALUE_BOTH;
    } elsif (exists $inUserIds{$acc}) {
        print META Biocluster::Config::FIELD_SEQ_SRC_VALUE_FASTA;
    } else {
        print META Biocluster::Config::FIELD_SEQ_SRC_VALUE_FAMILY;
    }
    print META "\n";
}

close META;


foreach my $err (@err) {
    my @lines = split(m/[\r\n]+/, $err);
    foreach my $line (@lines) {
        if ($line =~ s/^\[fastacmd\]\s+ERROR:\s+Entry\s+"([^"]+)"\s+not\s+found\s*$/$1/) {
            print NOMATCH "$line\tNOT_FOUND_DATABASE\n" if $showNoMatches;
        } else {
            print STDERR $line, "\n";
        }
    }
}

close NOMATCH if $showNoMatches;






















sub parseFastaHeaders {
    my ($fastaFileIn, $fastaFileOut, $metadataFile, $useFastaHeaders, $idMapper, $configFile, $fraction) = @_;

    my $parser = new Biocluster::Fasta::Headers(config_file_path => $configFile);

    open INFASTA, $fastaFileIn;
    open META, ">$metadataFile" or die "Unable to open user fasta ID file '$metadataFile' for writing: $!";
    open FASTAOUT, ">$fastaFileOut";

    my $lastId = "";
    my $id;
    my $seqLength = 0;
    my $seqCount = 0;
    while (my $line = <INFASTA>) {
        $line =~ s/[\r\n]+$//;

        my $headerLine = 0;
        my $writeSeq = 0;

        # Option E
        if ($useFastaHeaders) {
            my $result = $parser->parse_line_for_headers($line);

            # When we get here we are at the end of the headers and have started reading a sequence.
            if ($result->{state} eq Biocluster::Fasta::Headers::FLUSH) {
                
                if (not scalar @{ $result->{uniprot_ids} }) {
                    $id = makeSequenceId($seqCount);
                    $seq{$id}->{description} = substr($result->{raw_headers}, 0, 200);
                    $seq{$id}->{query_ids} = [];
                    $seq{$id}->{other_ids} = $result->{other_ids};
                } else {
                    # We discard the sequences for known Uniprot IDs since we will look them up at a later point.
                    $id = "discard_me";
                    foreach my $res (@{ $result->{uniprot_ids} }) {
                        push(@{ $seq{$res->{uniprot_id}}->{query_ids} }, $res->{other_id});
                        foreach my $dupId (@{ $result->{duplicates}->{$res->{uniprot_id}} }) {
                            push(@{ $seq{$res->{uniprot_id}}->{query_ids} }, $dupId);
                        }
                        push(@{ $seq{$res->{uniprot_id}}->{other_ids} }, @{ $result->{other_ids} });
                    }
                }
                
                # Ensure that the first line of the sequence is written to the file.
                $writeSeq = 1;
                $seqCount++;
                $headerLine = 1;

            # Here we have encountered a sequence line.
            } elsif ($result->{state} eq Biocluster::Fasta::Headers::SEQUENCE) {
                $writeSeq = 1;
            }
        # Option C
        } else {
            # Custom header for Option C
            if ($line =~ s/^>//) {
                # $id is written to the file at the bottom of the while loop.
                $id = makeSequenceId($seqCount);
                my $ss = exists $seq{$id} ? $seq{$id} : {};
                
                $ss->{description} = $line;

                $seqCount++;
                $headerLine = 1;

                $seq{$id} = $ss;
            } elsif ($line =~ /\S/) {
                $writeSeq = 1;
            }
        }

        if ($headerLine) {
            if ($lastId) {
                my $ss = $seq{$lastId};
                $ss->{seq_length} = $seqLength    if $lastId =~ /^z/;
                $ss->{src} = Biocluster::Config::FIELD_SEQ_SRC_VALUE_FASTA;
            }
            $seqLength = 0;
            $lastId = $id;
        }

        if ($writeSeq) {
            my $ss = $seq{$id};
            if (not exists $ss->{seq}) {
                $ss->{seq} = $line . "\n";
            } else {
                $ss->{seq} .= $line . "\n";
            }
            $seqLength += length($line);
        }
    }

    if ($id ne "discard_me") {
        $seq{$id}->{seq_length} = $seqLength    if $id =~ /^z/;
        $seq{$id}->{src} = Biocluster::Config::FIELD_SEQ_SRC_VALUE_FASTA;
    }

    my @seqToWrite;
    my $c = 1;
    foreach my $id (sort sortFn keys %seq) {
        if ($fraction == 1 or $c % $fraction == 0) {
            # Since multiple Uniprot IDs may map to the same sequence in the FASTA file, we need to write those
            # as sepearate sequences which is what "Expanding" means.
            push(@seqToWrite, $id);
            writeSeqData($id, $seq{$id}, \*FASTAOUT, \*META);
        }
        $c++;
    }

    close FASTAOUT;
    close META;
    close INFASTA;

    $parser->finish();

    return sort sortFn grep !/^z/, @seqToWrite;
}


sub sortFn {
    if ($a =~ /^z/ and $b =~ /^z/) {
        (my $aa = $a) =~ s/\D//g;
        (my $bb = $b) =~ s/\D//g;
        return $aa <=> $bb;
    } else {
        return $a cmp $b;
    }
}


sub writeSeqData {
    my ($id, $seq, $ffh, $mfh) = @_;

    # Only write out sequences that do not have a Uniprot ID, instead we retrieve them from the database rather
    # than use them from the FASTA file.
    if ($id =~ /^z/) {
        print $ffh ">" . $id . "\n";
        print $ffh $seq->{seq};
        print $ffh "\n";
    }
    
    print $mfh $id . "\n";
    print $mfh "\tDescription\t" . $seq->{description} . "\n"                               if $seq->{description};
    print $mfh "\tSequence_Length\t" . $seq->{seq_length} . "\n"                            if exists $seq->{seq_length};
    print $mfh "\t" . Biocluster::Config::FIELD_SEQ_SRC_KEY . "\t" . $seq->{src} . "\n"     if exists $seq->{src};
    print $mfh "\tOther_IDs\t" . join(",", @{ $seq->{other_ids} }) . "\n"                   if exists $seq->{other_ids};
    print $mfh "\tQuery_IDs\t" . join(",", @{ $seq->{query_ids} }) . "\n";#                   if scalar @queryIds;
}


sub makeSequenceId {
    my ($seqCount) = @_;
    my $id = sprintf("%6d", $seqCount);
    $id =~ tr/ /z/;
    return $id;
}


sub getDomainFromDb {
    my ($dbh, $table, $accessionHash, $fraction, @elements) = @_;
    my $c = 1;
    print "Accessions found in $table:\n";
    foreach my $element (@elements) {
        my $sth = $dbh->prepare("select accession,start,end from $table where id = '$element'");
        $sth->execute;
        while (my $row = $sth->fetch) {
            (my $uniprotId = $row->[0]) =~ s/\-\d+$//;
            if ($fraction == 1 or $c % $fraction == 0) {
                push @{$accessionHash->{$uniprotId}}, {'start' => $row->[1], 'end' => $row->[2]};
            }
            $c++;
        }
        $sth->finish;
    }
    my @accessions = keys %$accessionHash;
    print "Initial " . scalar @accessions . " sequences after $table\n";
}



