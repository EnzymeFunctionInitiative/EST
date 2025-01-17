
package EFI::Util::Colors;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);


sub new {
    my ($class, %args) = @_;

    my $colorFile = $args{color_file};

    my $self = {colors => [], default_color => "#6495ED"};
    bless($self, $class);

    if ($args{color_file}) {
        $self->parseColorFile($args{color_file});
    } else {
        $self->loadColors();
    }

    return $self;
}


sub getAllColors {
    my $self = shift;
    return $self->{colors};
}


#
# parseColorFile - private method
#
# Parse the color mapping file and save it to internal color list.
#
# Parameters:
#    $file: tab-separated file with column 1 being 1-based cluster number, column 2 being hex color
#
sub parseColorFile {
    my $self = shift;
    my $file = shift;

    open my $fh, "<", $file or die "Unable to parse color file '$file': $!";

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^\s*$/;
        my ($clusterNum, $color) = split(m/\t/, $line);
        push @{ $self->{colors} }, $color;
    }

    close $fh;
}


# public
sub getColor {
    my $self = shift;
    my $clusterNum = shift;
    return $self->{colors}->[$clusterNum - 1] // $self->{default_color};
    #return $self->{colors}->{$clusterNum} // $self->{default_color};
}


#
# loadColors - private method
#
# Loads the default color palette.
#
sub loadColors {
    my $self = shift;

    my @colors = (
        "#FF0000","#0000FF","#FFA500","#008000","#FF00FF","#00FFFF","#FFC0CB","#FF69B4","#808000","#FA8072",
        "#EE82EE","#006400","#00FF00","#B259B2","#003366","#7FFFBF","#8000FF","#B25900","#592C00","#800000",
        "#0080FF","#FF4040","#40FF40","#4040FF","#004040","#400040","#404000","#804040","#408040","#404080",
        "#40FFFF","#FF40FF","#FF0040","#40FF00","#0040FF","#FF8040","#40FF80","#8040FF","#00FF40","#4000FF",
        "#FF4000","#000040","#400000","#004000","#008040","#400080","#804000","#80FF40","#4080FF","#FF4080",
        "#800040","#408000","#004080","#808040","#408080","#804080","#FFC0C0","#C0FFC0","#C0C0FF","#00C0C0",
        "#C000C0","#C0C000","#80C0C0","#C080C0","#C0C080","#40C0C0","#C040C0","#C0C040","#C0FFFF","#FFC0FF",
        "#FF00C0","#C0FF00","#00C0FF","#FF80C0","#C0FF80","#80C0FF","#FF40C0","#C0FF40","#40C0FF","#00FFC0",
        "#C000FF","#FFC000","#0000C0","#C00000","#00C000","#0080C0","#C00080","#80C000","#0040C0","#C00040",
        "#40C000","#80FFC0","#C080FF","#FFC080","#8000C0","#C08000","#00C080","#8080C0","#C08080","#80C080",
        "#8040C0","#C08040","#40C080","#40FFC0","#C040FF","#FFC040","#4000C0","#C04000","#00C040","#4080C0",
        "#C04080","#80C040","#4040C0","#C04040","#40C040","#202020","#FF2020","#20FF20","#FF8800","#E32636",
        "#EFDECD","#E52B50","#FFBF00","#FF033E","#9966CC","#A4C639","#F2F3F4","#CD9575","#915C83","#FAEBD7",
        "#8DB600","#FBCEB1","#7FFFD4","#4B5320","#E9D66B","#87A96B","#FF9966","#A52A2A","#FF2052","#007FFF",
        "#89CFF0","#A1CAF1","#F4C2C2","#21ABCD","#FAE7B5","#FFE135","#98777B","#BCD4E6","#9F8170","#F5F5DC",
        "#FFE4C4","#3D2B1F","#FE6F5E","#000000","#FFEBCD","#318CE7","#ACE5EE","#FAF0BE","#A2A2D0","#6699CC",
        "#0D98BA","#8A2BE2","#DE5D83","#79443B","#0095B6","#E3DAC9","#CC0000","#006A4E","#873260","#0070FF",
        "#B5A642","#CB4154","#1DACD6","#66FF00","#BF94E4","#C32148","#FF007F","#08E8DE","#D19FE8","#F4BBFF",
        "#FF55A3","#FB607F","#004225","#CD7F32","#FFC1CC","#E7FEFF","#F0DC82","#480607","#800020","#DEB887",
        "#CC5500","#E97451","#8A3324","#BD33A4","#702963","#007AA5","#E03C31","#5F9EA0","#006B3C","#ED872D",
        "#E30022","#A67B5B","#4B3621","#1E4D2B","#A3C1AD","#C19A6B","#78866B","#FF0800","#E4717A","#00BFFF",
        "#592720","#C41E3A","#00CC99","#EB4C42","#FF0038","#FFA6C9","#B31B1B","#99BADD","#ED9121","#ACE1AF",
        "#B2FFFF","#4997D0","#DE3163","#EC3B83","#007BA7","#2A52BE","#A0785A","#FAD6A5","#36454F","#7FFF00",
        "#FFB7C5","#CD5C5C","#D2691E","#FFA700","#98817B","#E34234","#E4D00A","#FBCCE7","#0047AB","#6F4E37",
        "#9BDDFF","#002E63","#8C92AC","#B87333","#996666","#FF3800","#FF7F50","#F88379","#893F45","#9ACEEB",
        "#6495ED","#FFF8DC","#FFF8E7","#FFBCD9","#FFFDD0","#DC143C","#990000","#BE0032","#F0E130","#00008B",
        "#654321","#5D3954","#A40000","#08457E","#986960","#CD5B45","#008B8B","#B8860B","#013220","#1A2421",
        "#BDB76B","#483C32","#734F96","#8B008B","#003366","#556B2F","#FF8C00","#9932CC","#779ECB","#03C03C",
        "#966FD6","#C23B22","#E75480","#003399","#872657","#8B0000","#E9967A","#560319","#8FBC8F","#3C1414",
        "#483D8B","#2F4F4F","#177245","#918151","#FFA812","#CC4E5C","#00CED1","#9400D3","#00693E","#D70A53",
        "#A9203E","#EF3038","#E9692C","#DA3287","#B94E48","#704241","#C154C1","#004B49","#9955BB","#CC00CC",
        "#FFCBA4","#FF1493","#FF9933","#1560BD","#EDC9AF","#1E90FF","#D71868","#85BB65","#967117","#00009C",
        "#E1A95F","#C2B280","#614051","#F0EAD6","#1034A6","#7DF9FF","#FF003F","#6F00FF","#CCFF00","#BF00FF",
        "#3F00FF","#8F00FF","#50C878","#96C8A2","#801818","#B53389","#F400A1","#E5AA70","#71BC78","#4F7942",
        "#FF2800","#6C541E","#CE2029","#B22222","#E25822","#FC8EAC","#F7E98E","#EEDC82","#FF004F","#228B22",
        "#0072BB","#86608E","#F64A8A","#FF77FF","#E48400","#CC6666","#DCDCDC","#E49B0F","#B06500","#6082B6",
        "#E6E8FA","#996515","#A8E4A0","#465945","#1164B4","#ADFF2F","#A99A86","#00FF7F","#663854","#446CCF",
        "#5218FA","#3FFF00","#C90016","#DA9100","#DF73FF","#49796B","#FF1DCE","#FF69B4","#355E3B","#B2EC5D",
        "#138808","#E3A857","#4B0082","#002FA7","#FF4F00","#5A4FCF","#F4F0EC","#009000","#00A86B","#F8DE7E",
        "#D73B3E","#A50B5E","#FADA5E","#BDDA57","#29AB87","#E8000D","#4CBB17","#C3B091","#087830","#D6CADD",
        "#26619C","#A9BA9D","#CF1020","#E6E6FA","#CCCCFF","#9457EB","#EE82EE","#FBAED2","#967BB6","#FBA0E3",
        "#7CFC00","#BFFF00","#F56991","#E68FAC","#FDD5B1","#ADD8E6","#B5651D","#E66771","#F08080","#93CCEA",
        "#E0FFFF","#F984EF","#D3D3D3","#90EE90","#F0E68C","#B19CD9","#FFB6C1","#FFA07A","#FF9999","#20B2AA",
        "#87CEFA","#778899","#B38B6D","#C8A2C8","#32CD32","#195905","#FAF0E6","#E62020","#18453B","#FFBD88",
        "#AAF0D1","#F8F4FF","#6050DC","#0BDA51","#FF8243","#74C365","#E0B0FF","#915F6D","#EF98AA","#73C2FB",
        "#E5B73B","#0067A5","#66DDAA","#0000CD","#E2062C","#AF4035","#F3E5AB","#035096","#1C352D","#DDA0DD",
        "#BA55D3","#9370DB","#BB3385","#3CB371","#7B68EE","#C9DC87","#00FA9A","#674C47","#0054B4","#48D1CC",
        "#C71585","#FDBCB4","#191970","#004953","#3EB489","#F5FFFA","#98FF98","#FFE4E1","#73A9C2","#AE0C00",
        "#ADDFAD","#30BA8F","#997A8D","#C54B8C","#FFDB58","#21421E","#F6ADC6","#2A8000","#FFDEAD","#FFA343",
        "#FE59C2","#39FF14","#A4DDED","#059033","#0077BE","#CC7722","#CFB53B","#FDF5E6","#796878","#673147",
        "#C08081","#6B8E23","#BAB86C","#9AB973","#0F0F0F","#B784A7","#FFA500","#F8D568","#FF9F00","#FF4500",
        "#DA70D6","#414A4C","#FF6E4A","#002147","#1CA9C9","#006600","#273BE2","#682860","#AFEEEE","#987654",
        "#9BC4E2","#DDADAF","#DA8A67","#ABCDEF","#E6BE8A","#EEE8AA","#98FB98","#DCD0FF","#F984E5","#FADADD",
        "#DB7093","#96DED1","#C9C0BB","#ECEBBD","#BC987E","#78184A","#FFEFD5","#AEC6CF","#836953","#CFCFC4",
        "#77DD77","#F49AC2","#FFB347","#FFD1DC","#B39EB5","#FF6961","#CB99C9","#FFE5B4","#FFDAB9","#FADFAD",
        "#D1E231","#EAE0C8","#88D8C0","#E6E200","#1C39BB","#32127A","#D99058","#F77FBE","#701C1C","#CC3333",
        "#FE28A2","#DF00FF","#000F89","#123524","#FDDDE6","#01796F","#FFC0CB","#FC74FD","#F78FA7","#E7ACCF",
        "#93C572","#E5E4E2","#FF5A36","#B0E0E6","#FF8F00","#003153","#CC8899","#FF7518","#69359C","#9D81BA",
        "#9678B6","#FE4EDA","#50404D","#FF355E","#E30B5D","#E25098","#B3446C","#D68A59","#FF33CC","#E3256B",
        "#FF5349","#D70040","#0892D0","#B666D2","#B03060","#414833","#1FCECB","#F9429E","#674846","#B76E79",
        "#FF66CC","#AA98A9","#905D5D","#AB4E52","#65000B","#D40000","#BC8F8F","#0038A8","#4169E1","#CA2C92",
        "#7851A9","#E0115F","#FF0028","#BB6528","#E18E96","#A81C07","#80461B","#B7410E","#00563F","#8B4513",
        "#FF6700","#F4C430","#23297A","#FF8C69","#FF91A4","#ECD540","#F4A460","#507D2A","#0F52BA","#CBA135",
        "#FF2400","#FFD800","#76FF7A","#006994","#2E8B57","#321414","#FFF5EE","#FFBA00","#704214","#8A795D",
        "#45CEA2","#009E60","#FC0FC0","#882D17","#CB410B","#007474","#87CEEB","#CF71AF","#6A5ACD","#708090",
        "#933D41","#100C08","#0FC0FC","#A7FC00","#4682B4","#E4D96F","#FFCC33","#FD5E53","#D2B48C","#F94D00",
        "#F28500","#FFCC00","#8B8589","#CD5700","#D0F0C0","#367588","#006D5B","#E2725B","#D8BFD8","#DE6FA1",
        "#FC89AC","#0ABAB5","#E08D3C","#DBD7D2","#FF6347","#746CC0","#FFC87C","#FD0E35","#00755E","#0073CF",
        "#417DC1","#DEAA88","#B57281","#30D5C8","#00FFEF","#A0D6B4","#66424D","#8A496B","#66023C","#0033AA",
        "#D9004C","#536895","#FFB300","#3CD070","#014421","#7B1113","#8878C3","#FF6FFF","#120A8F","#4166F5",
        "#635147","#5B92E5","#B78727","#AE2029","#E1AD21","#D3003F","#C5B358","#C80815","#43B3AE","#A020F0",
        "#324AB2","#F75394","#40826D","#922724","#9F1D35","#DA1D81","#FFA089","#9F00FF","#004242","#645452",
        "#F5DEB3","#F5F5F5","#FF43A4","#FC6C85","#A2ADD0","#722F37","#C9A0DC","#738678","#0F4D92","#FFAE42",
        "#9ACD32","#0014A8","#2C1608","#9BC4E5","#310106","#04640D","#FB5514","#E115C0","#00587F","#0BC582",
        "#FEB8C8","#9E8317","#01190F","#847D81","#58018B","#B70639","#703B01","#F7F1DF","#118B8A","#4AFEFA",
        "#FCB164","#796EE6","#000D2C","#53495F","#F95475","#61FC03","#5D9608","#DE98FD","#98A088","#4F584E",
        "#248AD0","#5C5300","#9F6551","#BCFEC6","#932C70","#2B1B04","#B5AFC4","#D4C67A","#AE7AA1","#C2A393",
        "#0232FD","#6A3A35","#BA6801","#168E5C","#16C0D0","#C62100","#014347","#233809","#42083B","#82785D",
        "#023087","#B7DAD2","#196956","#8C41BB","#ECEDFE","#2B2D32","#94C661","#F8907D","#895E6B","#788E95",
        "#FB6AB8","#576094","#DB1474","#8489AE","#860E04","#FBC206","#6EAB9B","#F2CDFE","#645341","#760035",
        "#647A41","#496E76","#E3F894","#F9D7CD","#876128","#A1A711","#01FB92","#FD0F31","#BE8485","#C660FB",
        "#120104","#D48958","#05AEE8","#C3C1BE","#9F98F8","#1167D9","#D19012","#B7D802","#826392","#5E7A6A",
        "#B29869","#1D0051","#8BE7FC","#76E0C1","#BACFA7","#11BA09","#462C36","#65407D","#491803","#F5D2A8",
        "#03422C","#72A46E","#128EAC","#47545E","#B95C69","#A14D12","#C4C8FA","#372A55","#3F3610","#D3A2C6",
        "#719FFA","#0D841A","#4C5B32","#9DB3B7","#B14F8F","#747103","#9F816D","#D26A5B","#8B934B","#F98500",
        "#002935","#D7F3FE","#FCB899","#1C0720","#6B5F61","#F98A9D","#9B72C2","#A6919D","#2C3729","#D7C70B",
        "#9F9992","#EFFBD0","#FDE2F1","#923A52","#5140A7","#BC14FD","#6D706C","#0007C4","#C6A62F","#000C14",
        "#904431","#600013","#1C1B08","#693955","#5E7C99","#6C6E82","#D0AFB3","#493B36","#AC93CE","#C4BA9C",
        "#09C4B8","#69A5B8","#374869","#F868ED","#E70850","#C04841","#C36333","#700366","#8A7A93","#52351D",
        "#B503A2","#D17190","#A0F086","#7B41FC","#0EA64F","#017499","#08A882","#7300CD","#A9B074","#4E6301",
        "#AB7E41","#547FF4","#134DAC","#FDEC87","#056164","#FE12A0","#C264BA","#939DAD","#0BCDFA","#277442",
        "#1BDE4A","#826958","#977678","#BAFCE8","#7D8475","#8CCF95","#726638","#FEA8EB","#EAFEF0","#6B9279",
        "#C2FE4B","#304041","#1EA6A7","#022403","#062A47","#054B17","#F4C673","#02FEC7","#9DBAA8","#775551",
        "#565BCC","#80D7D2","#7AD607","#696F54","#87089A","#664B19","#242235","#7DB00D","#BFC7D6","#D5A97E",
        "#433F31","#311A18","#FDB2AB","#D586C9","#7A5FB1","#32544A","#EFE3AF","#859D96","#2B8570","#8B282D",
        "#E16A07","#4B0125","#021083","#114558","#F707F9","#C78571","#7FB9BC","#FC7F4B","#8D4A92","#6B3119",
        "#884F74","#994E4F","#9DA9D3","#867B40","#CED5C4","#1CA2FE","#D9C5B4","#FEAA00","#507B01","#A7D0DB",
        "#53858D","#588F4A","#FBEEEC","#FC93C1","#D7CCD4","#3E4A02","#C8B1E2","#7A8B62","#9A5AE2","#896C04",
        "#B1121C","#402D7D","#858701","#D498A6","#B484EF","#5C474C","#067881","#C0F9FC","#726075","#8D3101",
        "#6C93B2","#A26B3F","#AA6582","#4F4C4F","#5A563D","#E83005","#32492D","#FC7272","#B9C457","#552A5B",
        "#B50464","#616E79","#DCE2E4","#CF8028","#0AE2F0","#4F1E24","#FD5E46","#4B694E","#C5DEFC","#5DC262",
        "#022D26","#7776B8","#FD9F66","#B049B8","#988F73","#BE385A","#2B2126","#54805A","#141B55","#67C09B",
        "#456989","#DDC1D9","#166175","#C1E29C","#A397B5","#2E2922","#ABDBBE","#B4A6A8","#A06B07","#A99949",
        "#0A0618","#B14E2E","#60557D","#D4A556","#82A752","#4A005B","#3C404F","#6E6657","#7E8BD5","#1275B8",
        "#D79E92","#230735","#661849","#7A8391","#FE0F7B","#B0B6A9","#629591","#D05591","#97B68A","#97939A",
        "#035E38","#53E19E","#DFD7F9","#02436C","#525A72","#059A0E","#3E736C","#AC8E87","#D10C92","#B9906E",
        "#66BDFD","#C0ABFD","#0734BC","#341224","#8AAAC1","#0E0B03","#414522","#6A2F3E","#2D9A8A","#4568FD",
        "#FDE6D2","#9A003C","#AC8190","#DCDD58","#B7903D","#1F2927","#9B02E6","#827A71","#878B8A","#8F724F",
        "#AC4B70","#37233B","#385559","#F347C7","#9DB4FE","#D57179","#DE505A","#37F7DD","#503500","#1C2401",
        "#DD0323","#00A4BA","#955602","#FA5B94","#AA766C","#B8E067","#6A807E","#4D2E27","#73BED7","#D7BC8A",
        "#614539","#526861","#716D96","#829A17","#210109","#436C2D","#784955","#987BAB","#8F0152","#0452FA",
        "#B67757","#A1659F","#D4F8D8","#48416F","#DEBAAF","#A5A9AA","#8C6B83","#403740","#70872B","#D9744D",
        "#151E2C","#5C5E5E","#B47C02","#F4CBD0","#E49D7D","#DD9954","#B0A18B","#2B5308","#9D72FC","#2A3351",
        "#68496C","#C94801","#EED05E","#826F6D","#E0D6BB","#5B6DB4","#662F98","#0C97CA","#C1CA89","#755A03",
        "#DFA619","#CD70A8","#BBC9C7","#F6BCE3","#A16462","#01D0AA","#87C6B3","#E7B2FA","#D85379","#643AD5",
        "#D18AAE","#13FD5E","#B3E3FD","#C977DB","#C1A7BB","#9286CB","#A19B6A","#8FFED7","#6B1F17","#DF503A",
        "#10DDD7","#9A8457","#60672F","#7D327D","#DD8782","#59AC42","#82FDB8","#FC8AE7","#909F6F","#B691AE",
        "#B811CD","#BCB24E","#CB4BD9","#2B2304","#AA9501","#5D5096","#403221","#3990FC","#70DE7F","#95857F",
        "#84A385","#50996F","#797B53","#7B6142","#81D5FE","#9CC428","#0B0438","#3E2005","#4B7C91","#523854",
        "#005EA9","#F0C7AD","#ACB799","#FAC08E","#502239","#BFAB6A","#2B3C48","#0EB5D8","#8A5647","#49AF74",
        "#067AE9","#F19509","#554628","#4426A4","#7352C9","#3F4287","#8B655E","#B480BF","#9BA74C","#5F514C",
        "#CC9BDC","#BA7942","#1C4138","#3C3C3A","#29B09C","#02923F","#701D2B","#36577C","#3F00EA","#3D959E",
        "#440601","#8AEFF3","#6D442A","#BEB1A8","#A11C02","#8383FE","#A73839","#DBDE8A","#0283B3","#888597",
        "#32592E","#F5FDFA","#01191B","#AC707A","#B6BD03","#027B59","#7B4F08","#957737","#83727D","#035543",
        "#6F7E64","#C39999","#52847A","#925AAC","#77CEDA","#516369","#E0D7D0","#FCDD97","#555424","#96E6B6",
        "#85BB74","#5E2074","#BD5E48","#9BEE53","#1A351E","#3148CD","#71575F","#69A6D0","#391A62","#E79EA0",
        "#1C0F03","#1B1636","#D20C39","#765396","#7402FE","#447F3E","#CFD0A8","#3A2600","#685AFC","#A4B3C6",
        "#534302","#9AA097","#FD5154","#9B0085","#403956","#80A1A7","#6E7A9A","#605E6A","#86F0E2","#5A2B01",
        "#7E3D43","#ED823B","#32331B","#424837","#40755E","#524F48","#B75807","#B40080","#5B8CA1","#FDCFE5",
        "#CCFEAC","#755847","#CAB296","#C0D6E3","#2D7100","#D5E4DE","#362823","#69C63C","#AC3801","#163132",
        "#4750A6","#61B8B2","#FCC4B5","#DEBA2E","#FE0449","#737930","#8470AB","#687D87","#D7B760","#6AAB86",
        "#8398B8","#B7B6BF","#92C4A1","#B6084F","#853B5E","#D0BCBA","#92826D","#C6DDC6","#BE5F5A","#280021",
        "#435743","#874514","#63675A","#E97963","#8F9C9E","#985262","#909081","#023508","#DDADBF","#D78493",
        "#363900","#5B0120","#603C47","#C3955D","#AC61CB","#FD7BA7","#716C74","#8D895B","#071001","#82B4F2",
        "#B6BBD8","#71887A","#8B9FE3","#997158","#65A6AB","#2E3067","#321301","#FEECCB","#3B5E72","#C8FE85",
        "#A1DCDF","#CB49A6","#B1C5E4","#3E5EB0","#88AEA7","#04504C","#975232","#6786B9","#068797","#9A98C4",
        "#A1C3C2","#1C3967","#DBEA07","#789658","#E7E7C6","#A6C886","#957F89","#752E62","#171518","#A75648",
        "#01D26F","#0F535D","#047E76","#C54754","#5D6E88","#AB9483","#803B99","#FA9C48","#4A8A22","#654A5C",
        "#965F86","#9D0CBB","#A0E8A0","#D3DBFA","#FD908F","#AEAB85","#A13B89","#F1B350","#066898","#948A42",
        "#C8BEDE","#19252C","#7046AA","#E1EEFC","#3E6557","#CD3F26","#2B1925","#DDAD94","#C0B109","#37DFFE",
        "#039676","#907468","#9E86A5","#3A1B49","#BEE5B7","#C29501","#9E3645","#DC580A","#645631","#444B4B",
        "#FD1A63","#DDE5AE","#887800","#36006F","#3A6260","#784637","#FEA0B7","#A3E0D2","#6D6316","#5F7172",
        "#B99EC7","#777A7E","#E0FEFD","#E16DC5","#01344B","#9F9FB5","#182617","#FE3D21","#7D0017","#822F21",
        "#EFD9DC","#6E68C4","#35473E","#007523","#767667","#A6825D","#83DC5F","#227285","#A95E34","#526172",
        "#979730","#756F6D","#716259","#E8B2B5","#B6C9BB","#9078DA","#4F326E","#B2387B","#888C6F","#314B5F",
        "#E5B678","#38A3C6","#586148","#5C515B","#CDCCE1","#C8977F",
        );
    $self->{colors} = \@colors;
}


1;
__END__

=pod

=head1 EFI::Util::Colors

=head2 NAME

B<EFI::Util::Colors> - Perl utility module for getting a unique color for each cluster


=head2 SYNOPSIS

    use EFI::Util::Colors;

    my $colors = new EFI::Util::Colors();

    my $color = $colors->getColor(4);
    print "Color for cluster 4 is $color\n";

    my $colors = $colors->getAllColors();


=head2 DESCRIPTION

B<EFI::Util::Colors> is a Perl utility module that provides an interface for getting a
unique color for each cluster.  The default color is C<#6495ED>.  Optionally, colors can
be loaded from an external file.


=head2 METHODS

=head3 C<new([color_file =E<gt> $colorFile])>

Creates a new B<EFI::Util::Colors> object using the input file to obtain
the color mapping.

=head4 Parameters

=over

=item C<color_file> (optional)

Path to a file mapping cluster number to colors. For example:

    1       #FF0000
    2       #0000FF
    3       #FFA500
    4       #008000
    5       #FF00FF
    6       #00FFFF
    7       #FFC0CB
    8       #FF69B4
    9       #808000
    10      #FA8072

=back

=head4 Example Usage

    my $colors = new EFI::Util::Colors();


=head3 C<getColor($clusterNum)>

Returns the color for the given cluster number.  The number is 1-based.

=head4 Parameters

=over

=item C<$clusterNum>

Number of the cluster (numeric)

=back

=head4 Returns

Returns a hex color.

=head4 Example Usage

    my $color = $colors->getColor(4);
    print "Color for cluster 4 is $color\n";


=head3 C<getAllColors()>

Returns the all the colors in the default palette.

=head4 Returns

Returns an array ref containing the hex color codes.

=head4 Example Usage

    my $colors = $colors->getAllColors();
    my $numColors = @$colors;
    print "There are $numColors in the default color palette\n";


=cut

