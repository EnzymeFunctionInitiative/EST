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
is($cfg->{db_user}, "testuser", "db_user");
is($cfg->{db_password}, "testpassword", "db_password");
is($cfg->{db_host}, "10.1.1.3", "db_host");
is($cfg->{db_port}, "3307", "db_port");
is($cfg->{id_mapping_table}, "idmapping", "id_mapping_table");
is($cfg->{id_mapping_remote_url}, "http://url-to-id-mapping", "id_mapping_remote_url");
is(scalar keys %{ $cfg->{id_mapping_map}}, 3, "# id mappings");
is($cfg->{id_mapping_map}->{"GI"}->[0], 0, "gi index");
is($cfg->{id_mapping_map}->{"GI"}->[1], "gi", "gi ID");
is($cfg->{id_mapping_map}->{"EMBL-CDS"}->[0], 1, "genbank index");
is($cfg->{id_mapping_map}->{"EMBL-CDS"}->[1], "genbank", "genbank ID");
is($cfg->{id_mapping_map}->{"RefSeq"}->[0], 2, "RefSeq index");
is($cfg->{id_mapping_map}->{"RefSeq"}->[1], "ncbi", "RefSeq ID");
is($cfg->{cluster_queue}, "efi", "cluster_queue");

done_testing(14);


