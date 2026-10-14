# Hando

Claude / Codex 쓰다가 한도 걸리는 게 싫어서 만든 메뉴바 앱

<img src="assets/menubar-light.png" width="604" alt="메뉴바">

글자는 5시간, 아래 잔디는 주간 사용량. 쓸수록 채워짐

<img src="assets/states.png" width="760" alt="상태">

## 설치

```bash
git clone https://github.com/minsu33/Hando.git
cd Hando
./scripts/build-app.sh --install
```

macOS 14+, `claude auth login` 이나 `codex login` 되어 있어야 함

## 참고

- 공식 API 아니라서 언제든 깨질 수 있음
- 로그인 정보는 읽기만 하고 아무 데도 안 보냄
- 처음에 키체인 허용 창 뜨면 항상 허용

## License

MIT
