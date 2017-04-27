#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use lib "$FindBin::Bin/lib";
use Biocluster::TestHelpers qw(writeTestConfig);

use Biocluster::Config qw(biocluster_configure);

my $cfgFile = "$FindBin::Bin/test.config";
writeTestConfig($cfgFile);

use Test::More;

my $cfg = {};
biocluster_configure($cfg, config_file_path => $cfgFile);
is($cfg->{db}->{user}, "efitest", "db_user");
is($cfg->{db}->{password}, "efitest", "db_password");
is($cfg->{db}->{host}, "10.1.1.3", "db_host");
is($cfg->{db}->{port}, "3307", "db_port");
is($cfg->{id_mapping}->{table}, "idmapping", "id_mapping_table");
is($cfg->{id_mapping}->{remote_url}, "ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.example", "id_mapping_remote_url");
is(scalar keys %{ $cfg->{id_mapping}->{map}}, 3, "# id mappings");
is($cfg->{id_mapping}->{map}->{"GI"}, "enabled", "gi ID");
is($cfg->{id_mapping}->{map}->{"EMBL-CDS"}, "enabled", "genbank ID");
is($cfg->{id_mapping}->{map}->{"RefSeq"}, "enabled", "RefSeq ID");
is($cfg->{cluster}->{queue}, "efi", "cluster_queue");

done_testing(11);


