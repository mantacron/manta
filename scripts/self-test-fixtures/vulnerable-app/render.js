// Seeded fixture — intentional XSS sink to regression-test shallow-scan.sh's
// INJECTION pattern. See scripts/self-test.sh Check 6.
function renderComment(el, userInput) {
  el.innerHTML = userInput;
}
