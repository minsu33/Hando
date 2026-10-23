#!/bin/zsh
# Hando 빌드용 자체 서명 인증서 만들기 (한 번만)
# 같은 인증서로 계속 서명하면 다시 빌드해도 키체인 "항상 허용"이 유지됨.
# Apple 개발자 계정이 아니라서 Gatekeeper 경고는 그대로임.
#   ./scripts/make-signing-cert.sh
set -euo pipefail

NAME="Hando Self Signed"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "이미 있음: $NAME"; exit 0
fi

DIR="$(mktemp -d)"; trap 'rm -rf "$DIR"' EXIT
cat > "$DIR/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$DIR/key.pem" -out "$DIR/cert.pem" -config "$DIR/cert.cnf" 2>/dev/null
PASS="$(openssl rand -hex 12)"
openssl pkcs12 -export -legacy -inkey "$DIR/key.pem" -in "$DIR/cert.pem" \
  -name "$NAME" -out "$DIR/cert.p12" -passout "pass:$PASS" 2>/dev/null \
  || openssl pkcs12 -export -inkey "$DIR/key.pem" -in "$DIR/cert.pem" \
       -name "$NAME" -out "$DIR/cert.p12" -passout "pass:$PASS"

# 로그인 키체인에 넣고 codesign이 쓸 수 있게
security import "$DIR/cert.p12" -k ~/Library/Keychains/login.keychain-db -P "$PASS" -T /usr/bin/codesign
echo "✓ $NAME 만들었어요. 이제 ./scripts/build-app.sh 가 이걸로 서명해요."
echo "  처음 서명할 때 키체인 암호를 물어보면 '항상 허용'을 눌러주세요."
