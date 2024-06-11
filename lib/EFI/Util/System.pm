
package EFI::Util::System;

BEGIN {
    if ($^O eq "MSWin32")
    {
        require Win32; Win32::->import();
        require Win32::API; Win32::API::->import();
        require Win32::TieRegistry; Win32::TieRegistry::->import();
    }
}

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(getSystemSpec);

use List::Util qw(first);


sub trim {
    my $s = shift;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}


sub getSystemSpec {
    my $cpu = 'Unknown';
    my $cpus = 0;
    my $cpufreq = 0;
    my $ram = 0;
    my $os = 'Unknown';

    my $spec = {
        num_cpu => 0,
        cpu_name => "Unknown",
        cpu_freq => 0, # GHz
        ram => 0,
        os => "Unknown",
    };
    
    if ($^O eq "MSWin32") {
        $spec = getSystemSpecWin();
    } elsif ($^O eq 'darwin') {
        $spec = getSystemSpecDarwin();
    } else { # Linux
        $spec = getSystemSpecLinux();
    }

    $spec->{ram} = int($spec->{ram} / 1024 / 1024 / 1024 + 0.5);
    $spec->{cpu_freq} = int($spec->{cpu_freq}) / 1000;

    return $spec;
}


sub getSystemSpecLinux {
    # 0.03s
    # OS: 'Linux Ubuntu 16.04.2 LTS'
    # CPU: 'Intel(R) Core(TM) i7-5820K CPU @ 3.30GHz'
    # CPU count: 12
    # CPU freq: 3.301 GHz
    # RAM: 16 GB
    
    my $spec = {};

    open my $h, "/proc/cpuinfo";
    if ($h)
    {
        my @info = <$h>;
        close $h;
        $spec->{num_cpu} = scalar(map /^processor/, @info);
        my $strCPU = first { /^model name/ } @info;
        $spec->{cpu_name} = $1 if ($strCPU && $strCPU =~ /:\s+(.*)/);
        my $strFreq = first { /^cpu MHz/ } @info;
        $spec->{cpu_freq} = $1 if ($strFreq && $strFreq =~ /:\s+(.*)/);
    }
    open $h, "/proc/meminfo";
    if ($h)
    {
        my @info = <$h>;
        close $h;
        my $strRAM = first { /^MemTotal/ } @info;
        $spec->{ram} = $1 * 1024 if ($strRAM && $strRAM =~ /:\s+(\d+)/);
    }
    $spec->{os} = 'Linux Unknown';
    open $h, "/etc/lsb-release";
    if ($h)
    {
        my @info = <$h>;
        close $h;
        my $strOS = first { /^DISTRIB_DESCRIPTION/ } @info;
        $spec->{os} = 'Linux ' . $1 if ($strOS && $strOS =~ /=\"(.*)\"/);
    }

    return $spec;
}


sub getSystemSpecDarwin {
    # 0.03s
    # OS: 'macOS 10.12.6'
    # CPU: 'Intel(R) Core(TM) i7-4850HQ CPU @ 2.30GHz'
    # CPU count: 8
    # CPU freq: 2.3 GHz
    # RAM: 16 GB
    
    my $spec = {};

    $spec->{os} = 'macOS Unknown';
    my $strOS = trim(scalar(`sw_vers`));
    $spec->{os} = 'macOS ' . $1 if $strOS =~ /ProductVersion:\s*(.+)/;
    
    $spec->{cpu_name} = trim(`sysctl -n machdep.cpu.brand_string`);
    $spec->{num_cpu} = trim(`sysctl -n hw.ncpu`);
    $spec->{cpu_freq} = trim(`sysctl -n hw.cpufrequency`) / 1000000.0;
    $spec->{ram} = trim(`sysctl -n hw.memsize`);

    return $spec;
}


sub getSystemSpecWin {
    # 0.09s
    # Note: could use "wmic" to query that stuff, but that is a bit slower (e.g. whole sysinfo.pl script takes 0.38s)
    #
    # OS: 'Windows 10.0.15063'
    # CPU: 'Intel(R) Core(TM) i7-5820K CPU @ 3.30GHz'
    # CPU count: 12
    # CPU freq: 3.3 GHz
    # RAM: 16 GB
    
    my $spec = {};
    $spec->{num_cpu} = $ENV{'NUMBER_OF_PROCESSORS'};
    
    my $cpuKey = $Registry->Open( "LMachine/HARDWARE/DESCRIPTION/System/CentralProcessor/0", {Access=>Win32::TieRegistry::KEY_READ(),Delimiter=>"/"} );
    if ($cpuKey) {
        $spec->{cpu_name} = $cpuKey->{"/ProcessorNameString"};
        $spec->{cpu_freq} = hex($cpuKey->{"/~MHz"});
        $spec->{cpu_freq} = int(($spec->{cpu_freq} + 50) / 100) * 100; # round to hundreds of MHz
    }
    
    Win32::API::Struct->typedef(
        MEMORYSTATUSEX => qw{
            DWORD dwLength;
            DWORD MemLoad;
            ULONGLONG TotalPhys;
            ULONGLONG AvailPhys;
            ULONGLONG TotalPage;
            ULONGLONG AvailPage;
            ULONGLONG TotalVirtual;
            ULONGLONG AvailVirtual;
            ULONGLONG AvailExtendedVirtual;
        }
    );  

    if (Win32::API->Import('kernel32', 'BOOL GlobalMemoryStatusEx(LPMEMORYSTATUSEX lpMemoryStatusEx)'))
    {
        my $memstatus = Win32::API::Struct->new('MEMORYSTATUSEX');
        $memstatus->{dwLength} = $memstatus->sizeof();
        $memstatus->{MemLoad} = 0;
        $memstatus->{TotalPhys} = 0;
        $memstatus->{AvailPhys} = 0; 
        $memstatus->{TotalPage} = 0;
        $memstatus->{AvailPage} = 0;
        $memstatus->{TotalVirtual} = 0;
        $memstatus->{AvailVirtual} = 0;
        $memstatus->{AvailExtendedVirtual} = 0;
        GlobalMemoryStatusEx($memstatus);
        $spec->{ram} = $memstatus->{TotalPhys}; 
    }
    
    my ($osString, $osMajor, $osMinor, $osBuild, $osID) = Win32::GetOSVersion();
    $spec->{os} = "Windows $osMajor.$osMinor.$osBuild";

    return $spec;
}



1;

