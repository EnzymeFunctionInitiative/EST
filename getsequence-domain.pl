#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}

#version 0.9.0 moved from getting accesions by grepping files to using sqlite database
#version 0.9.0 options of specifing ssf and gene3d numbers added
#version 0.9.2 modified to accept 6-10 characters as accession ids
#version 0.9.3 modified to use cfg file to load location of variables for database
#version 0.9.4 change way cfg file used to load database location
#version 1.0.0 added fasta parsing and manual accessions

use strict;

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use FindBin;
use Capture::Tiny ':all';
use EFI::IdMapping;
use EFI::Config;
use EFI::IdMapping::Util;
use EFI::Fasta::Headers;
use EFI::Database;



my ($ipro, $pfam, $gene3d, $ssf, $access, $maxsequence, $manualAccession, $accessionFile,
    $fastaFileOut, $fastaFileIn, $metaFileOut, $useFastaHeaders, $domain, $fraction, $noMatchFile,
    $seqCountFile, $unirefVersion, $unirefExpand, $configFile, $errorFile, $randomFraction);
my $result = GetOptions(
    "ipro=s"                => \$ipro,
    "pfam=s"                => \$pfam,
    "gene3d=s"              => \$gene3d,
    "ssf=s"                 => \$ssf,
    "accession-output=s"    => \$access,
    "error-file=s"          => \$errorFile,
    "maxsequence=s"         => \$maxsequence,
    "accession-id=s"        => \$manualAccession,
    "accession-file=s"      => \$accessionFile,
    "out=s"                 => \$fastaFileOut,
    "fasta-file=s"          => \$fastaFileIn,
    "meta-file=s"           => \$metaFileOut,
    "use-fasta-headers"     => \$useFastaHeaders,
    "domain=s"              => \$domain,
    "fraction=i"            => \$fraction,
    "random-fraction"       => \$randomFraction,
    "no-match-file=s"       => \$noMatchFile,
    "seq-count-file=s"      => \$seqCountFile,
    "uniref-version=s"      => \$unirefVersion,
    "uniref-expand"         => \$unirefExpand,  # expand to include all homologues of UniRef seed sequences that are provided.
    "config=s"              => \$configFile,
);

#die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my @accessions = ();
my $perpass = $ENV{EFIPASS};
my $data_files = $ENV{EFIDBPATH};
my %ids = ();
my %accessionhash = ();
my @ipros = ();
my @pfams = ();
my @gene3ds = ();
my @ssfs = ();
my @manualAccessions = ();
my $isDomainOn;

verifyArgs();

parseFamilyArgs();

my $db = new EFI::Database(config_file_path => $configFile);
my $dbh = $db->getHandle();


######################################################################################################################
# PARSE ANY MANUAL ACCESSION FILE FOR IDS
#
if (defined $accessionFile and -f $accessionFile) {
    parseManualAccessionFile();
}

# Do reverse-id database lookup if we've been given manual accessions.
my $idMapper;
if ($#manualAccessions >= 0) {
    $idMapper = new EFI::IdMapping(config_file_path => $configFile);
}


######################################################################################################################
# COUNTS FOR KEEPING TRACK OF THE VARIOUS TYPES OF IDS
my $familyIdCount = 0;
my $fileMatchedIdCount = 0;
my $fileUnmatchedIdCount = 0;
my $fileTotalIdCount = 0;
my $fileSequenceCount = 0; # The number of actual sequences in the FASTA file, not the number of IDs or headers.


#######################################################################################################################
# DATA FOR MAPPING UNIREF50 AND UNIREF90 CLUSTER IDS TO ACCESSION IDS
#
my $unirefData = {};
# If $unirefVersion is set, %accessionhash will contain the UniRef cluster IDs that are in the family.


#######################################################################################################################
# GETTING ACCESSIONS FROM INTERPRO, PFAM, GENE3D, AND SSF FAMILY(S), AND/OR PFAM CLANS
#

my @accessions;
my $FracCount = 0;
my $FracFlag = 0;
retrieveFamilyAccessions();

# Header data for fasta and accession file inputs.
my $headerData = {};

# Save the accessions that are specified through a family.
my %inFamilyIds = map { ($_, 1) } @accessions;


#######################################################################################################################
# PARSE FASTA FILE FOR HEADER IDS (IF ANY)
#
my @fastaUniprotIds;
my $numFastaSequences = 0;
if ($fastaFileIn =~ /\w+/ and -s $fastaFileIn) {
    parseFastaFile();
}

#######################################################################################################################
# ADDING MANUAL ACCESSION IDS FROM FILE OR ARGUMENT
#
# Reverse map any IDs that aren't UniProt.
my $accUniprotIdRevMap = {};
my @accUniprotIds;
my $noMatches;
if ($#manualAccessions >= 0) { 
    if ($unirefExpand) {
        expandUnirefSequences();
    }   
    reverseLookupManualAccessions();
}

$idMapper->finish() if defined $idMapper;
print "Done with rev lookup\n";


my $showNoMatches = $#manualAccessions >= 0 ? 1 : 0 and defined $noMatchFile;
# Write out the no matches to a file.
if ($showNoMatches) {
    openNoMatchesFile();
}


#######################################################################################################################
# VERIFY THAT THE ACCESSIONS ARE IN THE DATABASE AND RETRIEVE THE DOMAIN
#


#######################################################################################################################
# VERIFY THAT THE ACCESSIONS ARE IN THE DATABASE AND RETRIEVE THE DOMAIN
#
my %inUserIds;
my $overlapCount = 0;  # Number of IDs in the input file(s) that overlap with IDs from any family(s) specified.
my $addedFromFile = 0; # Number of IDs that were added to the list of accession IDs to retrieve FASTA sequences for.

my $sth;
if (scalar @accUniprotIds) {
    verifyAccessions();
}


# For the fasta sequences, we use the sequence so we don't look it up below.  They have been already
# written to the output file in a prior step.  Here we are setting a flag for the metadata process
# below.
setMetadataFlag();

$sth->finish if $sth;
$dbh->disconnect();


my $numIdsToRetrieve = scalar @accessions;
print "There are a total of $numIdsToRetrieve IDs whose sequences will be retrieved.\n";

checkMaxSequencesExceeded();

writeAccessions();

my @err;
my @origAccessions;
retrieveSequences();

my $totalIdCount;
writeMetadata();

writeErrors();

closeNoMatchesFile();

writeSequenceCountFile();

print "Completed getsequences\n";




















sub parseFastaHeaders {
    my ($fastaFileIn, $fastaFileOut, $useFastaHeaders, $idMapper, $seqMeta, $configFile, $fraction) = @_;

    my $parser = new EFI::Fasta::Headers(config_file_path => $configFile);

    open INFASTA, $fastaFileIn;
    open FASTAOUT, ">$fastaFileOut";

    my %seq;        # actual sequence data

    my $lastLineIsHeader = 0;
    my $lastId = "";
    my $id;
    my $seqLength = 0;
    my $seqCount = 0;
    my $headerCount = 0;
    while (my $line = <INFASTA>) {
        $line =~ s/[\r\n]+$//;

        my $headerLine = 0;
        my $writeSeq = 0;

        # Option E
        if ($useFastaHeaders) {
            my $result = $parser->parse_line_for_headers($line);

            if ($result->{state} eq EFI::Fasta::Headers::HEADER) {
                $headerCount += $result->{count};
            }
            # When we get here we are at the end of the headers and have started reading a sequence.
            elsif ($result->{state} eq EFI::Fasta::Headers::FLUSH) {
                
                if (not scalar @{ $result->{uniprot_ids} }) {
#                    print "ZZZ\n";
                    $id = makeSequenceId($seqCount);
                    $seqMeta->{$id}->{description} = $result->{raw_headers}; # substr($result->{raw_headers}, 0, 200);
                    $seqMeta->{$id}->{other_ids} = $result->{other_ids};
                    push(@{ $seq{$seqCount}->{ids} }, $id);
                } else {
                    foreach my $res (@{ $result->{uniprot_ids} }) {
                        $id = $res->{uniprot_id};
#                        print "FASTA ID $id\n";
                        my $ss = $seqMeta->{$id};
                        push(@{ $ss->{query_ids} }, $res->{other_id});
                        foreach my $dupId (@{ $result->{duplicates}->{$id} }) {
                            push(@{ $ss->{query_ids} }, $dupId);
                        }
                        push(@{ $seq{$seqCount}->{ids} }, $id);
                        push(@{ $ss->{other_ids} }, @{ $result->{other_ids} });
                        $ss->{copy_seq_from} = $id;
                        $seqMeta->{$id} = $ss;
                    }
                }

#                print "END FLUSH\n";
                
                # Ensure that the first line of the sequence is written to the file.
                $writeSeq = 1;
                $seqCount++;
                $headerLine = 1;

            # Here we have encountered a sequence line.
            } elsif ($result->{state} eq EFI::Fasta::Headers::SEQUENCE) {
                $writeSeq = 1;
            }
        # Option C
        } else {
            # Custom header for Option C
            if ($line =~ /^>/ and not $lastLineIsHeader) {
                $line =~ s/^>//;

                # $id is written to the file at the bottom of the while loop.
                $id = makeSequenceId($seqCount);
                my $ss = exists $seqMeta->{$id} ? $seqMeta->{$id} : {};
                push(@{ $seq{$seqCount}->{ids} }, $id);
                
                $ss->{description} = $line;

                $seqCount++;
                $headerLine = 1;
                $headerCount++;

                $seqMeta->{$id} = $ss;
                $lastLineIsHeader = 1;
            } elsif ($line =~ /\S/ and $line !~ /^>/) {
                $writeSeq = 1;
                $lastLineIsHeader = 0;
            }
        }

        if ($headerLine and $seqCount > 1) {
            $seq{$seqCount - 2}->{seq_len} = $seqLength;
            $seqLength = 0;
        }

        if ($writeSeq) {
            my $ss = $seq{$seqCount - 1};
            if (not exists $ss->{seq}) {
                $ss->{seq} = $line . "\n";
            } else {
                $ss->{seq} .= $line . "\n";
            }
            $seqLength += length($line);
        }
    }

    $seq{$seqCount - 1}->{seq_len} = $seqLength;

    my $numMultUniprotIdSeq = 0;
    my @seqToWrite;
    foreach my $seqIdx (sort sortFn keys %seq) {
        # Since multiple Uniprot IDs may map to the same sequence in the FASTA file, we need to write those
        # as sepearate sequences which is what "Expanding" means.
        my @seqIds = @{ $seq{$seqIdx}->{ids} };
        push(@seqToWrite, @seqIds);
        $numMultUniprotIdSeq++ if scalar @seqIds > 1;

        # Since the same sequence may be pointed to by multiple uniprot IDs, we need to copy that sequence
        # because it won't by default be saved for all sequences above.
        my $sequence = "";
        if ($seq{$seqIdx}->{seq}) {
            $sequence = $seq{$seqIdx}->{seq};
        }

        foreach my $id (@{ $seq{$seqIdx}->{ids} }) {
            if ($sequence) { #$seqIdx =~ /^z/) {
                print FASTAOUT ">$id\n";
                print FASTAOUT $sequence;
                print FASTAOUT "\n";
            } else {
                print "ERROR: Couldn't find the sequence for $seqIdx\n";
            }
            $seqMeta->{$id}->{seq_len} = $seq{$seqIdx}->{seq_len} if $id =~ /^z/;
        }
    }

    close FASTAOUT;
    close INFASTA;

    $parser->finish();

    return ($seqCount, $headerCount, $numMultUniprotIdSeq, grep !/^z/, @seqToWrite);
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
    my ($id, $seqMeta, $mfh) = @_;

    my $desc = "";
    if ($seqMeta->{description}) {
        # Get rid of commas, since they are used to transform the multiple headers into lists
        ($desc = $seqMeta->{description}) =~ s/,//g;
        $desc =~ s/>/,/g;
    }
    print $mfh "\tDescription\t" . $desc . "\n"                                                 if $desc;
    print $mfh "\tSequence_Length\t" . $seqMeta->{seq_len} . "\n"                               if exists $seqMeta->{seq_len};
    print $mfh "\tOther_IDs\t" . join(",", @{ $seqMeta->{other_ids} }) . "\n"                   if exists $seqMeta->{other_ids};
    print $mfh "\tQuery_IDs\t" . join(",", @{ $seqMeta->{query_ids} }) . "\n"                   if exists $seqMeta->{query_ids};
}


sub makeSequenceId {
    my ($seqCount) = @_;
    my $id = sprintf("%6d", $seqCount);
    $id =~ tr/ /z/;
    return $id;
}


sub getDomainFromDb {
    my ($dbh, $table, $accessionHash, $fractionFunc, $unirefData, $unirefVersion, $isDomainOn, @elements) = @_;
    my $c = 1;
    my %unirefFamSizeHelper;
    print "Accessions found in $table:\n";
    my %idsProcessed;
    foreach my $element (@elements) {
        #my $sth = $dbh->prepare("select accession,start,end,uniref50_cluster_id,uniref90_cluster_id from $table where id = '$element'");
        my $sth = $dbh->prepare("select * from $table where id = '$element'");
        $sth->execute;
        my $ac = 1;
        while (my $row = $sth->fetchrow_hashref) {
            (my $uniprotId = $row->{accession}) =~ s/\-\d+$//;
            next if (not $isDomainOn and exists $idsProcessed{$uniprotId});
            $idsProcessed{$uniprotId} = 1;

            if ($unirefVersion) {
                my $idx = $unirefVersion eq "90" ? "uniref90_cluster_id" : "uniref50_cluster_id";
                my $unirefId = $row->{$idx};
                if (&$fractionFunc($c)) {
                    push @{$unirefData->{$unirefId}}, $uniprotId;
                    # The accessionHash element will be overwritten multiple times, once for each accession ID 
                    # in the UniRef cluster that corresponds to the UniRef cluster ID.
                    $accessionHash->{$unirefId} = [{}]; 
                }
                # Only increment the family size if the uniref cluster ID hasn't yet been encountered.  This
                # is because the select query above retrieves all accessions in the family based on UniProt
                # not based on UniRef.
                if (not exists $unirefFamSizeHelper{$unirefId}) {
                    $unirefFamSizeHelper{$unirefId} = 1;
                    $c++;
                }
            } else {
                if (&$fractionFunc($c)) {
                    $ac++;
                    push @{$accessionHash->{$uniprotId}}, {'start' => $row->{start}, 'end' => $row->{end}};
                }
                $c++;
            }
        }
        print "Family $element had $ac elements that were added\n";
        $sth->finish;
    }
    my @accessions = keys %$accessionHash;
    print "Initial " . scalar @accessions . " sequences after $table\n";
    return $c;
}


sub retrieveFamiliesForClans {
    my (@clans) = @_;

    my @fams;
    foreach my $clan (@clans) {
        my $sql = "select pfam_id from PFAM_clans where clan_id = '$clan'";
        my $sth = $dbh->prepare($sql);
        $sth->execute;
    
        while (my $row = $sth->fetchrow_arrayref) {
            push @fams, $row->[0];
        }
    }

    return @fams;
}


sub parseFastaFile {

    print "Parsing the FASTA file.\n";

    ## Any ids from families are assigned a query_id value but only do it if we have specified
    ## an FASTA input file.
    #map { $headerData->{$_}->{query_ids} = [$_]; } keys %accessionhash;

    $useFastaHeaders = defined $useFastaHeaders ? 1 : 0;
    # Returns the Uniprot IDs that were found in the file.  All sequences found in the file are written directly
    # to the output FASTA file.
    # The '1' parameter tells the function not to apply any fraction computation.
    my ($fastaNumHeaders, $fastaNumUnmatched, $numMultUniprotIdSeq) = (0, 0, 0);
    ($fileSequenceCount, $fastaNumHeaders, $numMultUniprotIdSeq, @fastaUniprotIds) = 
        parseFastaHeaders($fastaFileIn, $fastaFileOut, $useFastaHeaders, $idMapper, $headerData, $configFile, 1);

    my $fastaNumUniprotIdsInDb = scalar @fastaUniprotIds;
    $fastaNumUnmatched = $fastaNumHeaders - $fastaNumUniprotIdsInDb;
    
    print "There were $fastaNumHeaders headers, $fastaNumUniprotIdsInDb IDs with matching UniProt IDs, ";
    print "$fastaNumUnmatched IDs that weren't found in idmapping, and $fileSequenceCount sequences in the FASTA file.\n";
    print "There were $numMultUniprotIdSeq sequences that were replicated because they had multiple Uniprot IDs in the headers.\n";
#    print "The uniprot ids that were found in the FASTA file:", "\t", join(",", @fastaUniprotIds), "\n";

    $fileMatchedIdCount += $fastaNumUniprotIdsInDb;
    $fileTotalIdCount = $fileSequenceCount;
    $fileUnmatchedIdCount += $fastaNumUnmatched;
}


sub parseManualAccessionFile {
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


sub reverseLookupManualAccessions {

    print "Parsing the accession ID file.\n";

    my $upIds = [];
    ($upIds, $noMatches, $accUniprotIdRevMap) = $idMapper->reverseLookup(EFI::IdMapping::Util::AUTO, @manualAccessions);
    @accUniprotIds = @$upIds;
    
    # Any ids from families are assigned a query_id value but only do it if we have specified
    # an accession ID input file.
    map { $headerData->{$_}->{query_ids} = [$_]; } keys %accessionhash;

    my $numUniprotIds = scalar @accUniprotIds;
    my $numNoMatches = scalar @$noMatches;

    print "There were $numUniprotIds Uniprot ID matches and $numNoMatches no matches in the input accession ID file.\n";
#    print "The uniprot ids that were found in the accession file:", "\t", join(",", @accUniprotIds), "\n";

    $fileMatchedIdCount += $numUniprotIds;
    $fileUnmatchedIdCount += $numNoMatches;
    $fileTotalIdCount += $numUniprotIds + $numNoMatches;
}


sub expandUnirefSequences {
    print "Expanding UniRef seed sequences\n";

    my $col = "uniref${unirefVersion}_seed";

    my @origIds = @manualAccessions;
    @manualAccessions= ();
    foreach my $id (@origIds) {
        my $sql = "select $col from uniref where accession = '$id'";
        my $sth = $dbh->prepare($sql);
        $sth->execute;
        my $row = $sth->fetchrow_arrayref;
        next if not $row;
        
        my $seed = $row->[0];
        $sql = "select accession from uniref where $col = '$seed'";
        $sth = $dbh->prepare($sql);
        $sth->execute;
        $row = $sth->fetchrow_arrayref;
        
        while ($row) {
            push @manualAccessions, $row->[0];
            $row = $sth->fetchrow_arrayref;
        }

        $sth->finish if $sth;
    }
}


sub verifyAccessions {

    my @uniqAccUniprotIds = uniq @accUniprotIds;
    
    my $noMatchCount = 0;
    my $numDuplicate = (scalar @accUniprotIds) - (scalar @uniqAccUniprotIds);
    
    # Lookup each manual accession ID to get the domain as well as verify that it exists.
    foreach my $element (@uniqAccUniprotIds) {
        my $sql = "select accession from annotations where accession = '$element'";
        $sth = $dbh->prepare($sql);
        $sth->execute;
        if ($sth->fetch) {
            $inUserIds{$element} = 1;
            
            if (exists $accessionhash{$element}) {
                $overlapCount++;
            } else {
                $addedFromFile++;
                push(@accessions, $element);
            }
    
            $accessionhash{$element} = [{}];
            $headerData->{$element}->{query_ids} = $accUniprotIdRevMap->{$element};
        } else {
            $noMatchCount++;
            print NOMATCH "$element\tNOT_FOUND_DATABASE\n";
        }
    }
    
    print "There were $numDuplicate duplicate IDs in the Uniprot IDs that were idenfied from the accession file.\n";
    print "The number of Uniprot IDs in the accession file that were already in the specified family is $overlapCount.\n";
    print "The number of Uniprot IDs in the accession file that were added to the retrieval list is $addedFromFile.\n";
    print "The number of Uniprot IDs in the accession file that didn't have a match in the annotations database is $noMatchCount\n";
}


sub openNoMatchesFile {
    if ($noMatchFile) {
        open NOMATCH, ">$noMatchFile" or die "Unable to create nomatch file '$noMatchFile': $!";
    } else {
        open NOMATCH, ">/dev/null";
    }
    foreach my $noMatch (@$noMatches) {
        print NOMATCH "$noMatch\tNOT_FOUND_IDMAPPING\n";
    }
}


sub setMetadataFlag {
    foreach my $element (@fastaUniprotIds) {
        if (exists $accessionhash{$element}) {
            $overlapCount++;
        } else {
            $addedFromFile++;
        }
    
        $inUserIds{$element} = 1;
    }
}


sub writeAccessions {
    print "Final accession count $numIdsToRetrieve\n";
    print "Print out accessions\n";

    return if not $access;
    open GREP, ">$access" or die "Could not write to output accession ID file '$access': $!";
    foreach my $accession (keys %accessionhash) {
        my @domains = @{$accessionhash{$accession}};
        foreach my $piece (@domains) {
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
}


sub retrieveSequences {
    print "Retrieving Sequences\n";

    if ($fastaFileIn =~ /\w+/ and -s $fastaFileIn) {
        open OUT, ">>$fastaFileOut" or die "Cannot write to output fasta $fastaFileOut\n";
    } elsif ($fastaFileOut) {
        open OUT, ">$fastaFileOut" or die "Cannot write to output fasta $fastaFileOut\n";
    } else {
        open OUT, ">/dev/null";
    }
    
    @origAccessions = @accessions;
    while(scalar @accessions) {
        my @batch=splice(@accessions, 0, $perpass);
        my $batchline=join ',', @batch;
        my ($fastacmdOutput, $fastaErr) = capture {
            system("fastacmd", "-d", "${data_files}/combined.fasta", "-s", "$batchline");
        };
        push(@err, $fastaErr);
        #print "fastacmd -d $data_files/combined.fasta -s $batchline\n";
        my @sequences=split /\n>/, $fastacmdOutput;
        $sequences[0] = substr($sequences[0], 1) if $#sequences >= 0 and substr($sequences[0], 0, 1) eq ">";
        my $accession = "";
        foreach my $sequence (@sequences) { 
            #print "raw $sequence\n";
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
    
}


sub writeMetadata {
    print "Starting to write to metadata file $metaFileOut\n";

    return if not $metaFileOut;

    open META, ">$metaFileOut" or die "Unable to open user fasta ID file '$metaFileOut' for writing: $!";
    
    my @metaAcc = @origAccessions;
    # Add in the sequences that were in the fasta file (which we didn't retrieve from the fasta database).
    push(@metaAcc, @fastaUniprotIds);
    foreach my $acc (sort sortFn @metaAcc) {
        print META "$acc\n";
    
        print META "\t", EFI::Config::FIELD_SEQ_SRC_KEY, "\t";
        if (exists $inUserIds{$acc} and exists $inFamilyIds{$acc}) {
            print META EFI::Config::FIELD_SEQ_SRC_VALUE_BOTH;
        } elsif (exists $inUserIds{$acc}) {
            print META EFI::Config::FIELD_SEQ_SRC_VALUE_FASTA;
        } else {
            print META EFI::Config::FIELD_SEQ_SRC_VALUE_FAMILY;
            # Don't write the query ID for ones that are family-only
            delete $headerData->{$acc}->{query_ids};
        }
        print META "\n";
        if (exists $unirefData->{$acc} and $unirefVersion) {
            my @urIds = uniq @{ $unirefData->{$acc} };
            print META "\tUniRef${unirefVersion}_IDs\t", join(",", @urIds), "\n";
            print META "\tUniRef${unirefVersion}_Cluster_Size\t", scalar(@urIds), "\n";
        }
    
        # For user-supplied FASTA sequences that have headers with metadata and that appear in an input
        # PFAM family, write out the metadata.
        if (exists $headerData->{$acc}) {
            writeSeqData($acc, $headerData->{$acc}, \*META);
            delete $headerData->{$acc}; # delete this key so we don't write the same entry again below.
        }
    }
    
    # Add up all of the IDs that were identified (or retrieved in previous steps) with the number of sequences
    # in the FASTA file that did not have matching entries in our database.
    $totalIdCount = scalar @fastaUniprotIds + $numIdsToRetrieve;
    
    # Write out the remaining zzz headers
    foreach my $acc (sort sortFn keys %$headerData) {
        $totalIdCount++;
        print META "$acc\n";
        writeSeqData($acc, $headerData->{$acc}, \*META);
        print META "\t", EFI::Config::FIELD_SEQ_SRC_KEY, "\t";
        print META EFI::Config::FIELD_SEQ_SRC_VALUE_FASTA;
        print META "\n";
    }
    
    close META;
    
}


sub writeErrors {
    print "Starting to write errors\n";
    
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
}


sub closeNoMatchesFile {
    close NOMATCH if $showNoMatches;
}


sub checkMaxSequencesExceeded {
    if ($numIdsToRetrieve > $maxsequence and $maxsequence != 0) {
        open ERROR, ">$errorFile" or die "cannot write error output file $errorFile\n";
        print ERROR "Number of sequences $numIdsToRetrieve exceeds maximum specified $maxsequence\n";
        close ERROR;
        die "Number of sequences $numIdsToRetrieve exceeds maximum specified $maxsequence";
    }
}


sub writeSequenceCountFile {
    print "Starting to write $seqCountFile\n";
    
    if ($seqCountFile) {
        open SEQCOUNT, "> $seqCountFile" or die "Unable to write to sequence count file $seqCountFile: $!";
    
        print SEQCOUNT "FileTotal\t$fileTotalIdCount\n";
        print SEQCOUNT "FileMatched\t$fileMatchedIdCount\n";
        print SEQCOUNT "FileUnmatched\t$fileUnmatchedIdCount\n";
        
        # The FASTA sequences are always written in addition to any sequences found in families, even
        # if they are duplicate IDs, resulting in a different number of sequences than the total number
        # of IDs found in the families and file.
        print SEQCOUNT "FastaFileSeqTotal\t$fileSequenceCount\n";
    
        print SEQCOUNT "Family\t$familyIdCount\n";
        print SEQCOUNT "Total\t$totalIdCount\n";
    
        close SEQCOUNT;
    }
}


sub retrieveFamilyAccessions {
    my @clans = grep {m/^cl/i} @pfams;
    @pfams = grep {m/^pf/i} @pfams;
    push @pfams, retrieveFamiliesForClans(@clans);
    
    my $fractionFunc;
    if (not defined $fraction or $fraction == 1) {
        $fractionFunc = sub {
            return 1;
        };
    } elsif (not defined $randomFraction) {
        $fractionFunc = sub {
            my $count = shift;
            return $count % $fraction == 0;
        };
    } else {
        my $halfFrac = int($fraction / 2);
        $halfFrac = $halfFrac < 2 ? 1 : $halfFrac;
        $fractionFunc = sub {
            #my $count = shift;
            if (++$FracCount >= $fraction) {
                if (not $FracFlag) {
                    $FracCount = 0;
                    $FracFlag = 0;
                    return 1;
                } else {
                    $FracCount = 0;
                    $FracFlag = 0;
                    return 0;
                }
            } elsif (int(rand($fraction)) == $halfFrac and not $FracFlag) {
                $FracFlag = 1;
                return 1;
            } else {
                return 0;
            }
        };
    }

    print "Getting Acession Numbers in specified Families\n";
    my $famAcc = getDomainFromDb($dbh, "INTERPRO", \%accessionhash, $fractionFunc, $unirefData, $unirefVersion, $isDomainOn, @ipros);
    $famAcc = getDomainFromDb($dbh, "PFAM", \%accessionhash, $fractionFunc, $unirefData, $unirefVersion, $isDomainOn, @pfams);
    $famAcc = getDomainFromDb($dbh, "GENE3D", \%accessionhash, $fractionFunc, $unirefData, $unirefVersion, $isDomainOn, @gene3ds);
    $famAcc = getDomainFromDb($dbh, "SSF", \%accessionhash, $fractionFunc, $unirefData, $unirefVersion, $isDomainOn, @ssfs);
    
    @accessions = uniq keys %accessionhash;
    $familyIdCount = scalar @accessions;
    
    print "Done with family lookup. There are $familyIdCount IDs in the family(s) selected.\n";
}


sub verifyArgs {
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
    
    $unirefExpand = 0               if not defined $unirefExpand or not $unirefVersion;
    $maxsequence = 0                unless(defined $maxsequence);
    $errorFile = "$access.failed"   if not $errorFile;
    $isDomainOn = lc($domain) eq "on";

    if ((not $configFile or not -f $configFile) and exists $ENV{EFICONFIG}) {
        $configFile = $ENV{EFICONFIG};
    }

    die "Config file (--config=...) option is required" unless (defined $configFile and -f $configFile);

    my $pwd = `pwd`; chomp $pwd;
    $access = "$pwd/getseq.default.access"                  if not $access;
    $fastaFileOut = "$pwd/getseq.default.fasta"             if not $fastaFileOut;
    $metaFileOut = "$pwd/getseq.default.meta"               if not $metaFileOut;
    $noMatchFile = "$pwd/getseq.default.nomatch"            if not $noMatchFile;
    $seqCountFile = "$pwd/getseq.default.seqcount"          if not $seqCountFile;

    if (not $ipro and not $pfam and not $gene3d and not $ssf and not $manualAccession and not $fastaFileIn and not $accessionFile) {
        print "Nope\n";
        $access = $fastaFileOut = $metaFileOut = $noMatchFile = $seqCountFile = "";
    }
}


sub parseFamilyArgs {
    if (defined $ipro and $ipro ne 0) {
        print ":$ipro:\n";
        @ipros=split /,/, $ipro;
    }
    
    if (defined $pfam and $pfam ne 0) {
        print ":$pfam:\n";
        @pfams=split /,/, $pfam;
    }
    
    if (defined $gene3d and $gene3d ne 0) {
        print ":$gene3d:\n";
        @gene3ds=split /,/, $gene3d;
    }
    
    if (defined $ssf and $ssf ne 0) {
        print ":$ssf:\n";
        @ssfs=split /,/, $ssf;
    }
    
    if (defined $manualAccession and $manualAccession ne 0) {
        print ":manual $manualAccession:\n";
        @manualAccessions = split m/,/, $manualAccession;
    }
}



