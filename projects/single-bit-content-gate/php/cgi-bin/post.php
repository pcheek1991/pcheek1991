#!/usr/bin/env php-cgi
<?php
// SPDX-License-Identifier: Unlicense
// EVALUATION ONLY. NO WARRANTY, NO TRADEMARK CLAIM, NO INSURANCE.
declare(strict_types=1);
require_once dirname(__DIR__) . '/SingleBitGate.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
function reply(int $status, array $data): never {
    http_response_code($status);
    echo json_encode($data, JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function appendAudit(array $event): void {
    $path = getenv('SAFETY_AUDIT_OUTBOX');
    if (!$path || !is_file($path) || !is_writable($path)) {
        throw new RuntimeException('Audit outbox unavailable');
    }
    $line = json_encode($event, JSON_THROW_ON_ERROR) . "\n";
    if (file_put_contents($path, $line, FILE_APPEND | LOCK_EX) !== strlen($line)) {
        throw new RuntimeException('Audit persistence failed');
    }
}
function queueRestrictedOriginal(string $id, string $original): void {
    $dir = getenv('SAFETY_REVIEW_DIR');
    $secret = getenv('SAFETY_REVIEW_KEY_B64');
    $key = is_string($secret) ? base64_decode($secret, true) : false;
    if (!$dir || !is_dir($dir) || !is_writable($dir) || !is_string($key) || strlen($key) !== 32) {
        throw new RuntimeException('Restricted encrypted review storage unavailable');
    }
    $nonce = random_bytes(12); $tag = '';
    $ciphertext = openssl_encrypt($original, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $nonce, $tag);
    if ($ciphertext === false) throw new RuntimeException('Encryption failure');
    $doc = json_encode([
        'id' => $id, 'policy_version' => '3.0.0-single-bit',
        'nonce' => base64_encode($nonce), 'tag' => base64_encode($tag),
        'ciphertext' => base64_encode($ciphertext)
    ], JSON_THROW_ON_ERROR);
    $path = rtrim($dir, '/') . '/' . $id . '.json';
    $fh = fopen($path, 'x');
    if ($fh === false) throw new RuntimeException('Review write failed');
    try {
        chmod($path, 0600);
        if (fwrite($fh, $doc) !== strlen($doc) || !fflush($fh)) throw new RuntimeException('Review write incomplete');
    } finally { fclose($fh); }
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') reply(405, ['error' => 'POST required']);
if (!isset($_POST['post']) || !is_string($_POST['post'])) reply(400, ['error' => 'post text required']);
$id = bin2hex(random_bytes(16));
try {
    $original = $_POST['post'];
    $hold = SingleBitGate::hold($original); // SINGLE FINAL BOOLEAN
    if ($hold) queueRestrictedOriginal($id, $original);
    appendAudit([
        'event_id' => $id,
        'timestamp_utc' => gmdate('c'),
        'policy_version' => '3.0.0-single-bit',
        'hold' => $hold
    ]);
    // The original is never sent to Datadog or echoed on a held submission.
    reply(202, ['accepted' => true, 'id' => $id, 'public_text' => $hold ? '' : $original]);
} catch (Throwable $e) {
    error_log('Safety intake unavailable; event id ' . $id);
    reply(503, ['accepted' => false, 'error' => 'Safety processing unavailable; retry']);
}