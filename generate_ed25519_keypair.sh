#! /usr/bin/env bash
generate() {
    openssl genpkey -algorithm Ed25519 -out secret.pem
    openssl pkey -in secret.pem -pubout -out public.pem

    SECRET_KEY_RAW=$(cat secret.pem | sed -n '2p')
    SECRET_KEY=$(echo $SECRET_KEY_RAW | base64 -d | od -t x1 -An | tr -d '\n ' | cut -c 33-)

    PUBLIC_KEY_RAW=$(cat public.pem | sed -n '2p' | cut -c 17-)
    PUBLIC_KEY=$(echo $PUBLIC_KEY_RAW | base64 -d | od -t x1 -An | tr -d '\n ')

    PUBKEY_HASH=$(echo $PUBLIC_KEY | sha256sum | head -c 64)
    jq -n \
       --arg key_id "$PUBKEY_HASH" \
       --arg private "$SECRET_KEY_RAW" \
       --arg public "$PUBLIC_KEY_RAW" \
       '{($key_id): ({keytype: "ed25519", keyval: ({private: $private, public: $public})})}'
}

KEYS=""
for type in "target" "timestamp" "snapshot" "mirrors"; do
    KEYS_PER_TYPES=""
    for _ in {1..3}; do
	KEYS_PER_TYPES+=$(generate)
    done
    KEYS+=$(echo $KEYS_PER_TYPES | jq -s --arg type $type '{($type): . | add}')
done
nix eval --expr "(builtins.fromJSON ''$(echo $KEYS | jq -s '. | add')'')" --impure | nixfmt
