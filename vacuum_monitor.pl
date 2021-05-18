my $pid = $ARGV[0];
my $total = $ARGV[1];

print "\nCurrent Vacuum progress for PID $pid with total table size $total:\n";

my $awk = q['{print $2}'];
my $current = `sudo cat /proc/$pid/io | grep read_bytes | awk $awk`;
chomp $current;
my $perc = sprintf("%.2f", $current / $total);
print "  $perc percent\n";
print "  $current current\n";
print "  $total total\n";
