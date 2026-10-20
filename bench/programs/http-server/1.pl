# HTTP over IO::Socket::INET: a forked server process and, in the parent, a pool of keep-alive client
# connections, each side driven by an IO::Select event loop. Each client POSTs {"value": i}; the server
# answers with the value, and the client sums the answers.
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use POSIX ();

my $clients = 32;
my $total = shift || 10;

# Removes one complete message from the front of the buffer; returns its body, or undef if incomplete.
sub take_message {
    my ($buffer) = @_;
    my $end = index($$buffer, "\r\n\r\n");
    return undef if $end < 0;
    my $length = substr($$buffer, 0, $end) =~ /^content-length:\s*(\d+)/mi ? $1 : 0;
    return undef if length($$buffer) < $end + 4 + $length;
    my $body = substr($$buffer, $end + 4, $length);
    substr($$buffer, 0, $end + 4 + $length) = '';
    return $body;
}

my ($listener, $port);
until ($listener) {
    $port = 20000 + int(rand(30000));
    $listener = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $port, Listen => 512, ReuseAddr => 1);
}

my $server_pid = fork() // die "fork: $!";
if ($server_pid == 0) {
    my $select = IO::Select->new($listener);
    my %buffers;
    while (1) {
        for my $socket ($select->can_read) {
            if ($socket == $listener) {
                my $conn = $listener->accept or next;
                $select->add($conn);
                $buffers{fileno $conn} = '';
                next;
            }
            my $got = sysread($socket, my $chunk, 65536);
            if (!$got) {
                $select->remove($socket);
                delete $buffers{fileno $socket};
                close $socket;
                next;
            }
            my $buffer = \$buffers{fileno $socket};
            $$buffer .= $chunk;
            while (defined(my $body = take_message($buffer))) {
                my ($value) = $body =~ /"value"\s*:\s*(-?\d+)/;
                syswrite($socket, "HTTP/1.1 200 OK\r\nContent-Length: " . length($value) . "\r\n\r\n$value");
            }
        }
    }
    POSIX::_exit(0);
}

my $next = 1;
my ($sum, $answered) = (0, 0);
my $select = IO::Select->new;
my %buffers;

sub send_request {
    my ($socket, $value) = @_;
    my $payload = qq({"value":$value});
    syswrite($socket, "POST / HTTP/1.1\r\nHost: localhost:$port\r\nContent-Type: application/json\r\n"
        . 'Content-Length: ' . length($payload) . "\r\n\r\n$payload");
}

for (1 .. $clients) {
    last if $next > $total;
    my $socket;
    $socket = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $port, Proto => 'tcp') until $socket;
    $select->add($socket);
    $buffers{fileno $socket} = '';
    send_request($socket, $next++);
}
while ($answered < $total) {
    for my $socket ($select->can_read) {
        sysread($socket, my $chunk, 65536) or next;
        my $buffer = \$buffers{fileno $socket};
        $$buffer .= $chunk;
        while (defined(my $body = take_message($buffer))) {
            $sum += $body;
            $answered++;
            send_request($socket, $next++) if $next <= $total;
        }
    }
}
kill 'TERM', $server_pid;
waitpid($server_pid, 0);
print "$sum\n";
