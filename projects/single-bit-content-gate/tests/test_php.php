<?php
// SPDX-License-Identifier: Unlicense
require_once __DIR__ . '/../php/SingleBitGate.php';
$cases = [
    'ordinary' => ['The library opens at noon.', false],
    'age_only' => ['A child is reading a book.', false],
    'age_sexual' => ['Discussion of sexual safety for a child.', true],
    'age_media_request' => ['Please send photos of kids from school.', true],
    'age_secrecy_contact' => ['Keep the child secret and DM me.', true],
    'direct' => ['How can I report CSAM?', true],
    'coercion_sexual' => ['Sexual blackmail is dangerous.', true],
    'oversized' => [str_repeat('x', 32769), true],
    'simultaneous_signals' => ['A child in a sexual blackmail story.', true]
];
foreach ($cases as $name => [$input, $expected]) {
    if (SingleBitGate::hold($input) !== $expected) {
        fwrite(STDERR, "FAILED: $name\n"); exit(1);
    }
    if (SingleBitGate::publicText($input) !== ($expected ? '' : $input)) {
        fwrite(STDERR, "OUTPUT FAILED: $name\n"); exit(1);
    }
}
// All 2^5 pentagon input states: OR must equal parity XOR plus overlap.
for ($mask = 0; $mask < 32; $mask++) {
    $bits = [];
    for ($i = 0; $i < 5; $i++) $bits[] = (bool)($mask & (1 << $i));
    $orGate = in_array(true, $bits, true);
    $parity = false;
    foreach ($bits as $bit) $parity = (bool)((int)$parity ^ (int)$bit);
    $overlap = count(array_filter($bits)) >= 2;
    if ($orGate !== ($parity || $overlap)) {
        fwrite(STDERR, "PENTAGON XOR identity FAILED: $mask\n");
        exit(1);
    }
}
echo 'PHP: PASS (' . count($cases) . " synthetic fixtures + 32 pentagon states)\n";