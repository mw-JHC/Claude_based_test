const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch();
  const dir = process.argv[2];
  const shots = [
    ['home_wood', '나만의 <em>위스키</em> 진열장', '마셔본 위스키를 선반에 세우고<br>길게 눌러 자리를 바꿔요', 'Your own <em>whisky cabinet</em>', 'Line up every bottle you have tasted<br>and drag them into place'],
    ['home_museum', '세 가지 진열장 분위기', '원목장 · 바 진열장 · 박물관 유리 케이스', 'Three cabinet styles', 'Wood shop · Back bar · Museum case'],
    ['detail', '한 병 한 병의<br>테이스팅 노트', '점수, 도수, 색, 생산지까지<br>병 사진으로 라벨을 읽어 채워요', 'A tasting note<br>for every bottle', 'Score, ABV, colour and origin —<br>the label is read from your photo'],
    ['detail_flavor', '향 · 맛 · 여운을<br>차트로', '눌러서 강도를 정하는 레이더 차트', 'Nose, palate and finish<br>at a glance', 'Tap the radar chart to set intensity'],
    ['memory', '다 마신 병은<br><em>Memory Library</em>로', '함께한 사람과 그날의 이야기를<br>빈 병과 함께 남겨요', 'Empty bottles live on<br>in the <em>Memory Library</em>', 'Keep the stories and the people<br>you shared each bottle with'],
    ['stats', '내 취향을 한눈에', '생산지 · 종류 · 점수 순위 통계', 'Know your taste', 'Origins, types and your top rated'],
  ];
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  let i = 1;
  for (const [img, tk, sk, te, se] of shots) {
    for (const [lang, t, s] of [['ko', tk, sk], ['en', te, se]]) {
      const url = 'file://' + path.join(dir, 'frame.html') + '?img=' + encodeURIComponent('raw/' + img + '.png') + '&t=' + encodeURIComponent(t) + '&s=' + encodeURIComponent(s);
      await p.goto(url); await p.waitForTimeout(1500);
      await p.screenshot({ path: path.join(dir, 'out', `screenshot_${lang}_${i}.png`) });
    }
    i++;
  }
  const f = await b.newPage({ viewport: { width: 1024, height: 500 }, deviceScaleFactor: 1 });
  await f.goto('file://' + path.join(dir, 'feature.html')); await f.waitForTimeout(1500);
  await f.screenshot({ path: path.join(dir, 'out', 'feature_graphic.png') });
  await b.close();
})();
