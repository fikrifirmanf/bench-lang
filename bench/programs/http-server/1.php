<?php
// PHP has no threads, so the server and a pool of keep-alive clients share one stream_select event loop on
// non-blocking sockets. Each client POSTs {"value": i}; the server answers with the value, and the client
// sums the answers.
const CLIENTS = 32;

// Splits one complete message off the front of $buffer; returns its body, or null if more bytes are needed.
function takeMessage(string &$buffer): ?string
{
    $end = strpos($buffer, "\r\n\r\n");
    if ($end === false) {
        return null;
    }
    $length = preg_match('/^content-length:\s*(\d+)/mi', substr($buffer, 0, $end), $m) ? (int) $m[1] : 0;
    if (strlen($buffer) < $end + 4 + $length) {
        return null;
    }
    $body = substr($buffer, $end + 4, $length);
    $buffer = (string) substr($buffer, $end + 4 + $length);
    return $body;
}

$total = (int) ($argv[1] ?? 10);
do {
    $port = random_int(20000, 49999);
    $server = @stream_socket_server("tcp://127.0.0.1:$port", $errno, $error);
} while ($server === false);
stream_set_blocking($server, false);

$next = 1;
$sum = 0;
$answered = 0;
$serverConns = [];   // id => [stream, buffer]
$clientConns = [];   // id => [stream, buffer]

function sendRequest($stream, int $value, int $port): void
{
    $payload = json_encode(['value' => $value]);
    fwrite($stream, "POST / HTTP/1.1\r\nHost: localhost:$port\r\nContent-Type: application/json\r\n"
        . 'Content-Length: ' . strlen($payload) . "\r\n\r\n$payload");
}

for ($c = 0; $c < CLIENTS && $next <= $total; $c++) {
    $stream = stream_socket_client("tcp://127.0.0.1:$port", $errno, $error, 5);
    stream_set_blocking($stream, false);
    $clientConns[(int) $stream] = [$stream, ''];
    sendRequest($stream, $next++, $port);
}

while ($answered < $total) {
    $read = [$server];
    foreach ($serverConns as [$stream]) {
        $read[] = $stream;
    }
    foreach ($clientConns as [$stream]) {
        $read[] = $stream;
    }
    $write = $except = null;
    if (stream_select($read, $write, $except, 5) === false) {
        break;
    }
    foreach ($read as $stream) {
        $id = (int) $stream;
        if ($stream === $server) {
            while ($conn = @stream_socket_accept($server, 0)) {
                stream_set_blocking($conn, false);
                $serverConns[(int) $conn] = [$conn, ''];
            }
            continue;
        }
        $chunk = fread($stream, 65536);
        if (isset($serverConns[$id])) {
            if ($chunk === '' || $chunk === false) {
                if (feof($stream)) {
                    fclose($stream);
                    unset($serverConns[$id]);
                }
                continue;
            }
            $serverConns[$id][1] .= $chunk;
            while (($body = takeMessage($serverConns[$id][1])) !== null) {
                $answer = (string) json_decode($body, true)['value'];
                fwrite($stream, "HTTP/1.1 200 OK\r\nContent-Length: " . strlen($answer) . "\r\n\r\n$answer");
            }
        } elseif (isset($clientConns[$id])) {
            if ($chunk === '' || $chunk === false) {
                continue;
            }
            $clientConns[$id][1] .= $chunk;
            while (($body = takeMessage($clientConns[$id][1])) !== null) {
                $sum += (int) $body;
                $answered++;
                if ($next <= $total) {
                    sendRequest($stream, $next++, $port);
                }
            }
        }
    }
}
echo "$sum\n";
