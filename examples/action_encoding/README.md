# Action Encoding: Unchanged Function Detection

This example demonstrates how the Pled encoder intelligently handles action functions during the encoding process.

## Feature Overview

When encoding actions back to Bubble.io format, Pled now detects whether the JavaScript files (`server.js` and `client.js`) have been modified from their original state. This prevents unnecessary reformatting and preserves the exact original function syntax when no changes were made. Additionally, all other action properties (like package information, automatically added packages, etc.) are fully preserved during the encoding process.

## How It Works

1. **During Decoding**: When Pled pulls a plugin from Bubble, it extracts the function bodies from the action's code and saves them as separate JS files.

2. **During Encoding**: When pushing back to Bubble, Pled:
   - Reads the original function from the action's JSON file
   - Compares it with the current JS file content
   - If unchanged (after normalization), uses the original function
   - If changed, wraps the new JS content in the appropriate function signature

## Benefits

- **Preserves Original Formatting**: Maintains Bubble's exact function format when no changes were made
- **Preserves All Properties**: Maintains package information, dependencies, hash values, and all other action metadata
- **Reduces Diff Noise**: Prevents unnecessary changes in version control
- **Maintains Compatibility**: Ensures functions work exactly as before if unmodified
- **Intelligent Property Handling**: Only function code is updated when changed, all other properties remain intact

## Example Behavior

### Original Action in Bubble with Package Dependencies
```json
{
  "code": {
    "automatically_added_packages": "{\"jsonwebtoken\":\"latest\",\"node:util\":\"latest\"}",
    "package": {
      "fn": "{\n    \"dependencies\": {\n        \"jsonwebtoken\": \"latest\"\n    }\n}",
      "invalid_package": false
    },
    "package_hash": "1e76bc4a16a53766f915",
    "package_status": "out_of_date",
    "package_used": true,
    "server": {
      "fn": "async function(properties, context) {\n    const jwt = require('jsonwebtoken');\n    return { token: jwt.sign(data, key) };\n}"
    }
  }
}
```

### Extracted to `server.js`
```javascript
    const jwt = require('jsonwebtoken');
    return { token: jwt.sign(data, key) };
```

### Encoding Behavior

**If Unchanged**: 
- Console output: "↻ Using original server function (no changes detected)"
- Result: Exact original function AND all package properties are preserved

**If Modified**:
- Console output: "✏️ Using modified server function from server.js"
- Result: New content is wrapped in function signature, all package properties remain intact

## Normalization

The comparison process normalizes whitespace to avoid false positives:
- Multiple spaces become single spaces
- Spaces around delimiters (`{}();,`) are removed
- Only structural changes trigger the "modified" status

This means minor formatting differences won't cause the function to be marked as changed.

## Property Preservation

All action properties are intelligently preserved during encoding:
- **Package Dependencies**: `automatically_added_packages`, `package`, `package_hash`, etc.
- **Action Metadata**: `category`, `display`, `type`, `fields`, `return_value`
- **Function Properties**: Only the `fn` property is updated when JS files change
- **Missing Files**: When JS files are deleted, only function properties are removed, all other metadata remains