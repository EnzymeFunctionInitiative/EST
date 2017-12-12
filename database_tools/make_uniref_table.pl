#!/usr/bin/env perl

# Writes out two tabular files, one containing a list of all of the UniRef entries in the input
# directory; the second containing a mapping of UniRef reference ID to clustered IDs.

use XML::LibXML;
use XML::Parser;
use Data::Dumper;
use IO::Handle;
use Getopt::Long;
use strict;



my ($inputDir, $unirefList, $unirefMap, $unirefSeq) = ("", "", "", "");

my $result = GetOptions(
    "in-dir=s"      => \$inputDir,
    "out-list=s"    => \$unirefList,
    "out-map=s"     => \$unirefMap,
    "out-seq=s"     => \$unirefSeq,
);

die "No input directory provided" if not $inputDir;
die "No output list file provided" if not $unirefList;
die "No output map file provided" if not $unirefMap;
#die "No output sequence file provided" if not $unirefSeq;


open LIST, ">$unirefList";
open MAP, ">$unirefMap";
if ($unirefSeq) {
    open SEQ, ">$unirefSeq";
}


my %isoformWritten;

foreach my $xmlFile (glob("$inputDir/*.xml")) {
    print "Processing $xmlFile\n";

    my $baseTag = "uniref";

    open PREVIEW, $xmlFile;
    while (<PREVIEW>) {
        if (m/<(UniRef\d*)[^a-z\d]/i) {
            $baseTag = $1;
        }
    }
    close PREVIEW;
    
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file($xmlFile);
    $doc->indexElements();

    foreach my $entry ($doc->findnodes("/$baseTag/entry")) {
        my $entryId = $entry->getAttribute("id");
        my ($repMember) = $entry->findnodes("./representativeMember");
        if (not $repMember) {
            print "Unable to find representative member for id $entryId\n";
            next;
        }

#        my $repType = $repMember->getAttribute("type");
#        my $repId = $repMember->getAttribute("id");
#        if ($repType ne "UniProtKB ID") {
#            print "Skipping entry $entryId since the representative member wasn't a UniProtKB ID";
#            next;
#        }

        my $accId = "";
        my $ok = 1;

        ($accId, $ok) = getAccessionId($repMember);
        print "Skipping entry $entryId since the representative member didn't have UniProtKB accession\n" and next if not $ok;

        if ($accId =~ s/\-\d+$//) {
#            if (exists $isoformWritten{$accId}) {
#                print "Skipping entry $entryId since the representative member is an isoform of $accId and we already wrote the first one\n";
#                next;
#            } else {
#                $isoformWritten{$accId} = 1;
#            }
        }

        $ok = saveMembers($entry, $accId);
        print "Skipping entry $entryId ($accId) since the representative member didn't have valid members\n" and next if not $ok;

        if ($unirefSeq) {
            $ok = writeSequence($repMember, $accId);
            print "Skipping entry $entryId since the representative member didn't have a sequence\n" and next if not $ok;
        }

        print LIST $accId, "\n";
    }
}


print "Completed processing\n";

close SEQ if $unirefSeq;
close MAP;
close LIST;


print "Wrapping up...\n";


sub saveMembers {
    my $entryMember = shift;
    my $accId = shift;

    foreach my $member ($entryMember->findnodes("./member")) {
        my ($dbRef) = $member->findnodes("./dbReference");
        my $type = $dbRef->getAttribute("type");
        if ($type ne "UniProtKB ID") {
            next;
        }

        my $memberAccId = "";

        foreach my $prop ($dbRef->findnodes("./property")) {
            my $propType = $prop->getAttribute("type");
            if ($propType eq "UniProtKB accession") {
                $memberAccId = $prop->getAttribute("value");
                last;
            }
        }

        print MAP join("\t", $accId, $memberAccId), "\n";
    }

    print MAP join("\t", $accId, $accId), "\n";

    return 1;
}


sub getAccessionId {
    my $repMember = shift;

    my $accId = "";
    foreach my $prop ($repMember->findnodes("./dbReference/property")) {
        my $propType = $prop->getAttribute("type");
        if ($propType eq "UniProtKB accession") {
            $accId = $prop->getAttribute("value");
            last;
        }
    }

    my $ok = 1;
    if (not $accId) {
        $ok = 0;
    }

    return ($accId, $ok);
}


sub writeSequence {
    my $repMember = shift;
    my $accId = shift;

    my ($seqNode) = $repMember->findnodes("./sequence");
    if (not $seqNode) {
        return 0;
    }

    my $seqLen = $seqNode->getAttribute("length");
    my $seqText = $seqNode->textContent();

    print SEQ ">$accId\n$seqText\n";

    return 1;
}


