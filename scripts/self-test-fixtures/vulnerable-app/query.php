<?php
// Seeded fixture — SQL injection via direct string interpolation, PHP style
// (no cursor.execute()/subprocess() the way the original Python-oriented
// patterns expect). Regression-tests shallow-scan.sh's PHP SQLI pattern.
// See scripts/self-test.sh Check 6.
function getTasksByUser(string $userId): array {
    $query = "SELECT * FROM tasks WHERE user_id = '$userId'";
    return $this->db->query($query)->fetchAll();
}
