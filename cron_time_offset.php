<?php
/**
 * Script that calculates the time difference in seconds between the current
 * server time (PHP) and the real time obtained from an NTP server.
 * Saves the result in a "time-offset" file.
 */

function getNTPTime($host = "time.cloudflare.com", $port = 123)
{
    $socket = @fsockopen("udp://$host", $port, $errNo, $errStr, 1);
    if (!$socket) {
        die("Error: Could not connect to the NTP server ($errStr)\n");
    }

    // Send NTP request (48 bytes)
    $msg = chr(0b11100011) . str_repeat(chr(0), 47);
    fwrite($socket, $msg);

    $response = fread($socket, 48);
    fclose($socket);

    if (strlen($response) !== 48) {
        die("Error: Invalid response from the NTP server\n");
    }

    // Extract the 4 bytes of timestamp at index 40
    $data = unpack("N12", $response);
    $timestamp = $data[9]; // index 9 contains the timestamp
    $ntp_epoch_offset = 2208988800; // difference between epochs (NTP vs Unix)

    return $timestamp - $ntp_epoch_offset;
}

$real_time = getNTPTime();
$php_time  = time();
$offset    = $real_time - $php_time;

// Save offset to file in the same directory as the script
$script_dir = __DIR__;
file_put_contents("$script_dir/time-offset.txt", $offset);

// Console output
echo "NTP: $real_time\n";
echo "PHP: $php_time\n";
echo "Offset: $offset\n";
