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
    'oversized' => [str_repeat('x', 32769), true]
];
foreach ($cases as $name => [$input, $expected]) {
    if (SingleBitGate::hold($input) !== $expected) {
        fwrite(STDERR, "FAILED: $name\n"); exit(1);
    }
    if (SingleBitGate::publicText($input) !== ($expected ? '' : $input)) {
        fwrite(STDERR, "OUTPUT FAILED: $name\n"); exit(1);
    }
}
foreach ([false,true] as $a) {
    foreach ([false,true] as $b) {
        if (($a || $b) !== (($a xor $b) || ($a && $b))) {
            fwrite(STDERR, "XOR identity FAILED\n"); exit(1);
        }
    }
}
echo 'PHP: PASS (' . count($cases) . " safe synthetic fixtures + OR/XOR identity)\n";