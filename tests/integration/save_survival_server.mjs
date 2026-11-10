// Runs a cloud bundle (the JSON file named on the command line, as Game.cloud_bundle_json
// wrote it) through the accounts server's validateBundle: exit 0 when it is accepted,
// 1 with the server's reason when it is refused (save_survival_test).
import {readFileSync} from 'node:fs';
import {validateBundle} from '../../hosting/accounts/server/accounts.js';

try {
  validateBundle(JSON.parse(readFileSync(process.argv[2], 'utf8')));
  console.log('accepted');
} catch (error) {
  console.log(`refused: ${error.message ?? error} ${JSON.stringify(error.details ?? '')}`);
  process.exit(1);
}
