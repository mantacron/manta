<?php
// Seeded fixture — intentional weak hash to regression-test shallow-scan.sh's
// CRYPTO pattern. See scripts/self-test.sh Check 6.
function hashPassword($password) {
    return md5($password);
}
