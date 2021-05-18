my $pid = $ARGV[0];
my $total = $ARGV[1];

print "\nCurrent Vacuum progress for PID $pid with total table size $total:\n";

my $running = `ps -o etimes= -p $pid`;
chomp $running;
$running =~ s/^\s+|\s+$//g ;

my $awk = q['{print $2}'];
my $current = `sudo cat /proc/$pid/io | grep read_bytes | awk $awk`;
chomp $current;
my $perc = sprintf("%.2f", $current / $total * 100);

my $totaltime = int($running / $perc * 100);
my $estimate = $totaltime - $running;
my $pretty = sprintf("%.2f", $estimate / 60 / 60);

print "  $perc percent\n";
print "  $current current\n";
print "  $total total\n\n";
print "  $running running\n";
print "  $totaltime total estimate\n";
print "  $estimate will run more ($pretty hours)\n";
