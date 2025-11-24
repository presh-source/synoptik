#!/bin/bash
# Fix Apollo Client imports in generated types
sed -i '' "s|from '@apollo/client/core'|from '@apollo/client'|g" src/graphql/generated/types.ts
echo "Fixed Apollo Client imports"
