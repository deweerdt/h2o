use Net::EmptyPort qw(empty_port);
use t::Util;

my %seen_ports = {};
for (my $n = 0; $n < 1000; $n++) {
    $port = safe_empty_port();
    if ($seen_ports{$port} == 1) {
        print("duplicate port $port\n");
    }
    $seen_ports{$port} = 1;
    if (($n % 3) == 0) {
        my $rport = (keys %seen_ports)[rand keys %seen_ports];
        safe_empty_port_release($rport);
        $seen_ports{$rport} = 0;
    }
}

foreach my $k (keys %seen_ports) {
    safe_empty_port_release($k);
}
