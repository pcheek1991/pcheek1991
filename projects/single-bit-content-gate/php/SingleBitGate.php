<?php
// SPDX-License-Identifier: Unlicense
// FOR EVALUATION PURPOSES. NO WARRANTY / NO COPYRIGHT CLAIM / NO TRADEMARK
// CLAIM / NO INSURANCE. ONLY BEST EFFORT SELF DIRECTED AGENCY LOGIC.
declare(strict_types=1);

final class SingleBitGate
{
    private const MAX_BYTES = 32768;
    private const PATTERNS = [
        'age' => '~(*UCP)\b(?:child|children|kids?|minors?|underage|preteen|teens?|teenagers?|(?:[1-9]|1[0-7])\s*(?:years?\s*old|yo))\b~iu',
        'sexual' => '~(*UCP)\b(?:sex|sexual|sexually|sexting|sexts?|nudes?|naked|porn|pornography|explicit|intimate)\b~iu',
        'media' => '~(*UCP)\b(?:photos?|pics?|pictures?|images?|videos?|clips?|snaps?)\b~iu',
        'request' => '~(*UCP)\b(?:send|share|trade|swap|buy|sell|upload|download|exchange|request)\b~iu',
        'secrecy' => '~(*UCP)\b(?:secret|secretly|privately|quietly|don.?t\s+tell)\b~iu',
        'contact' => '~(*UCP)\b(?:dm\s+me|pm\s+me|private\s+message|add\s+me)\b~iu',
        'coercion' => '~(*UCP)\b(?:blackmail|extort|extortion|threaten|threatened|threatening)\b~iu',
        'direct' => '~(*UCP)\b(?:csam|csae|child\s+sexual\s+abuse|child\s+sexual\s+exploitation)\b~iu'
    ];

    // ONLY retained classification decision: true means hold entire public output.
    public static function hold(string $original): bool
    {
        if (strlen($original) > self::MAX_BYTES || preg_match('//u', $original) !== 1) {
            return true;
        }
        try {
            if (class_exists('Normalizer')) {
                $text = \Normalizer::normalize($original, \Normalizer::FORM_KC);
                if ($text === false) return true;
            } else {
                // Without ICU, fail closed for Unicode instead of silently bypassing NFKC.
                if (preg_match('/[^\x00-\x7F]/', $original) === 1) return true;
                $text = $original;
            }
            $text = preg_replace('/[\x{200B}-\x{200D}\x{FEFF}]/u', '', $text);
            if ($text === null) return true;
            $h = [];
            foreach (self::PATTERNS as $name => $regex) {
                $matched = preg_match($regex, $text);
                if ($matched === false) return true;
                $h[$name] = ($matched === 1);
            }
            return $h['direct']
                || ($h['age'] && $h['sexual'])
                || ($h['age'] && $h['coercion'])
                || ($h['age'] && $h['secrecy'] && $h['contact'])
                || ($h['age'] && $h['media'] && $h['request'])
                || ($h['sexual'] && $h['coercion']);
        } catch (\Throwable $e) {
            return true;
        }
    }

    public static function publicText(string $original): string
    {
        return self::hold($original) ? '' : $original;
    }
}