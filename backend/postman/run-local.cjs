/* Run the Postman collection against a local development server.
 * Codes come only from that server's console-mail log, never from the API.
 * The collection still requires manual codes when used in the Postman app.
 */
const fs = require('node:fs');
const path = require('node:path');
const newman = require('../.venv/postman-tools/node_modules/newman');

const backend = path.resolve(__dirname, '..');
const logFile = process.env.AUTH_CONSOLE_LOG || path.join(backend, '.venv', 'postman-server.log');
const baseUrl = process.env.POSTMAN_BASE_URL || 'http://127.0.0.1:8000';
const target = new URL(baseUrl);
if (!['127.0.0.1', 'localhost', '[::1]'].includes(target.hostname)) {
  throw new Error('This console-code runner is limited to the local development server.');
}
if (!fs.existsSync(logFile)) {
  throw new Error(`Console-mail log does not exist: ${logFile}`);
}
const collection = JSON.parse(fs.readFileSync(path.join(__dirname, 'StudentHub.postman_collection.json'), 'utf8'));
const environment = JSON.parse(fs.readFileSync(path.join(__dirname, 'StudentHub.postman_environment.json'), 'utf8'));
const baseVariable = environment.values.find((variable) => variable.key === 'base_url');
baseVariable.value = baseUrl;

function latestCode(email) {
  const content = fs.readFileSync(logFile, 'utf8');
  const emailPosition = content.lastIndexOf(`To: ${email}`);
  if (emailPosition === -1) {
    throw new Error('Verification email for this test account was not found in the console log.');
  }
  const code = content.slice(emailPosition).match(/код: ([0-9]{6})/u);
  if (!code) {
    throw new Error('Verification code was not found in the console log.');
  }
  return code[1];
}

console.log(`Running the Postman collection against ${baseUrl}`);
const runner = newman.run({
  collection,
  environment,
  reporters: [],
  timeoutRequest: 10000,
  timeoutScript: 5000,
}, (error, summary) => {
  if (error) {
    console.error(`Collection could not complete: ${error.message}`);
    process.exitCode = 1;
    return;
  }
  const failures = summary.run.failures;
  const report = {
    checked_at: new Date().toISOString(),
    base_url: baseUrl,
    test_email: summary.environment.get('email'),
    requests: summary.run.stats.requests,
    assertions: summary.run.stats.assertions,
    responses: summary.run.executions.map((execution) => ({
      name: execution.item.name,
      status: execution.response ? execution.response.code : null,
      assertions: (execution.assertions || []).map((assertion) => ({
        name: assertion.assertion,
        passed: !assertion.error,
      })),
    })),
    failures: failures.map((failure) => ({
      request: failure.source && failure.source.name,
      test: failure.error.test || failure.error.name,
    })),
  };
  const reportFile = path.join(backend, '.venv', 'postman-results.json');
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n', 'utf8');
  console.log(`Requests: ${report.requests.total}; assertions: ${report.assertions.total}; failures: ${failures.length}`);
  console.log(`Test account: ${report.test_email}`);
  console.log(`Report (without tokens/passwords/codes): ${reportFile}`);
  for (const failure of failures) {
    console.error(`Failed: ${failure.source && failure.source.name}: ${failure.error.test || failure.error.message}`);
  }
  if (failures.length || summary.run.error) process.exitCode = 1;
});

runner.on('request', (error, args) => {
  if (error) return;
  console.log(`${args.item.name}: HTTP ${args.response.code}`);
  if (args.response.code !== 202) return;
  const response = JSON.parse(args.response.stream.toString('utf8'));
  if (!['register', 'login'].includes(response.purpose)) return;
  const email = runner.summary.environment.get('email');
  runner.summary.environment.set(
    response.purpose === 'register' ? 'registration_code' : 'login_code',
    latestCode(email),
  );
});
