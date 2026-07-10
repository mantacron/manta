<?php
// Seeded fixture — hardcoded credential via PHP define(), not a "password="
// assignment. Regression-tests shallow-scan.sh's define()/const SECRET
// pattern. See scripts/self-test.sh Check 6.
define('DB_PASS', 'admin123');
