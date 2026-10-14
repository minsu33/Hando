# Hando

AI 쓸 때 Claude / Codex 한도를 상시 확인하고 싶어서 만든 메뉴바 앱

<img src="assets/menubar-claude.png" width="604" alt="Claude">
<img src="assets/menubar-codex.png" width="588" alt="Codex">

글자는 5시간, 아래 잔디는 주간 사용량. 쓸수록 채워지고, 다 쓰면 몇 초마다 글자가 움직임

<img src="assets/states.png" width="608" alt="상태">

## 꾸미기

글꼴 7개, 한도 다 찼을 때 움직임 5개 중에 팝오버에서 고를 수 있음

<img src="assets/typefaces.png" width="760" alt="글꼴">

<img src="assets/wave.gif" width="152" alt="다 찼을 때 웨이브">

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
