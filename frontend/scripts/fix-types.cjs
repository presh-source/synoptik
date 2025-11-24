
const fs = require('fs');
const path = require('path');

const typesPath = path.join(__dirname, '../src/graphql/generated/types.ts');

try {
    let content = fs.readFileSync(typesPath, 'utf8');

    // Fix BaseMutationOptions -> MutationHookOptions
    content = content.replace(/BaseMutationOptions/g, 'MutationHookOptions');

    fs.writeFileSync(typesPath, content);
    console.log('Successfully patched generated types.');
} catch (err) {
    console.error('Error patching types:', err);
    process.exit(1);
}
