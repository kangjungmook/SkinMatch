const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createHandler } = require('../src/api');
const { mapCategory, toProduct, cleanText } = require('../src/naver');

// 네이버 공식 문서의 응답 형식대로 만든 가짜 응답
const naverItems = [
  {
    title: '<b>라운드랩</b> 1025 독도 <b>토너</b> 200ml',
    link: 'https://search.shopping.naver.com/catalog/1',
    image: 'https://shopping-phinf.pstatic.net/1.jpg',
    lprice: '15900', hprice: '', mallName: '네이버', productId: '111', productType: '1',
    brand: '라운드랩', maker: '라운드랩',
    category1: '화장품/미용', category2: '스킨케어', category3: '스킨/토너', category4: '',
  },
  {
    // 같은 제품이 다른 판매처로 또 나와요 → 합쳐야 해요
    title: '라운드랩 1025 독도 토너 200ml',
    link: 'https://smartstore.naver.com/x', image: '', lprice: '16500', productId: '112', productType: '2',
    brand: '라운드랩', maker: '',
    category1: '화장품/미용', category2: '스킨케어', category3: '스킨/토너', category4: '',
  },
  {
    // 화장품이 아니에요 → 빼야 해요
    title: '<b>토너</b> 패드 보관 케이스', link: '', image: '', lprice: '3000', productId: '113', productType: '2',
    brand: '', maker: '',
    category1: '생활/건강', category2: '수납', category3: '', category4: '',
  },
  {
    title: '닥터지 레드 블레미쉬 클리어 수딩 크림 &amp; 세트', link: '', image: '', lprice: '20000', productId: '114',
    productType: '1', brand: '닥터지', maker: '고운세상코스메틱',
    category1: '화장품/미용', category2: '스킨케어', category3: '크림', category4: '',
  },
];

function fakeFetch(calls) {
  return async (url, init) => {
    calls.push({ url, headers: init.headers });
    return { ok: true, status: 200, json: async () => ({ items: naverItems }), text: async () => '' };
  };
}

async function withServer(handler, fn) {
  const server = http.createServer(handler);
  await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

test('검색: 네이버 결과를 Product 형식으로 바꾸고, 화장품만 남기고, 중복을 합쳐요', async () => {
  const calls = [];
  const handle = createHandler({ clientId: () => 'id', clientSecret: () => 'secret', fetch: fakeFetch(calls) });
  await withServer(handle, async (base) => {
    const res = await fetch(`${base}/products/search?q=${encodeURIComponent('토너')}&limit=5`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('access-control-allow-origin'), '*');
    const list = await res.json();
    assert.equal(list.length, 2);
    assert.deepEqual(list[0], {
      id: 'naver_111',
      brand: '라운드랩',
      name: '1025 독도 토너 200ml',
      category: '토너',
      ingredients: [],
      imageUrl: 'https://shopping-phinf.pstatic.net/1.jpg',
      source: 'naver',
      naverCategory: '화장품/미용 > 스킨케어 > 스킨/토너',
      price: 15900,
      link: 'https://search.shopping.naver.com/catalog/1',
    });
    assert.equal(list[1].name, '레드 블레미쉬 클리어 수딩 크림 & 세트');
    assert.equal(list[1].category, '크림');

    // 키는 헤더로만 보내요
    assert.equal(calls.length, 1);
    assert.equal(calls[0].headers['X-Naver-Client-Id'], 'id');
    assert.equal(calls[0].headers['X-Naver-Client-Secret'], 'secret');
    assert.ok(calls[0].url.startsWith('https://openapi.naver.com/v1/search/shop.json?query=%ED%86%A0%EB%84%88'));

    // 같은 검색은 캐시에서 줘요
    await fetch(`${base}/products/search?q=${encodeURIComponent('토너')}&limit=5`);
    assert.equal(calls.length, 1);

    // Firebase 주소처럼 /api를 붙여도 돼요
    const res2 = await fetch(`${base}/api/products/search?q=x`);
    assert.equal(res2.status, 200);
  });
});

test('고른 단계 종류(cat)를 앞으로 보내요', async () => {
  const handle = createHandler({ clientId: () => 'id', clientSecret: () => 's', fetch: fakeFetch([]) });
  await withServer(handle, async (base) => {
    const list = await (await fetch(`${base}/products/search?q=a&cat=${encodeURIComponent('크림')}`)).json();
    assert.equal(list[0].category, '크림');
  });
});

test('키가 없으면 503, 네이버 오류면 502, 바코드·id는 404, 카테고리는 빈 목록', async () => {
  const noKey = createHandler({ clientId: () => '', clientSecret: () => '' });
  await withServer(noKey, async (base) => {
    assert.equal((await fetch(`${base}/products/search?q=a`)).status, 503);
    assert.deepEqual(await (await fetch(`${base}/products/search?q=`)).json(), []);
    assert.deepEqual(await (await fetch(`${base}/health`)).json(), { ok: true, naver: false });
    assert.equal((await fetch(`${base}/products/barcode/8801234567890`)).status, 404);
    assert.equal((await fetch(`${base}/products/naver_1`)).status, 404);
    assert.deepEqual(await (await fetch(`${base}/products?cat=x`)).json(), []);
  });
  const broken = createHandler({
    clientId: () => 'id',
    clientSecret: () => 'bad',
    fetch: async () => ({ ok: false, status: 401, text: async () => 'Authentication failed' }),
  });
  await withServer(broken, async (base) => {
    const res = await fetch(`${base}/products/search?q=a`);
    assert.equal(res.status, 502);
    assert.equal((await res.json()).detail, 401);
  });
});

test('카테고리 규칙', () => {
  assert.equal(mapCategory('독도 토너', []), '토너');
  assert.equal(mapCategory('레티놀 앰플', []), '에센스·앰플');
  assert.equal(mapCategory('비타C 세럼', []), '세럼');
  assert.equal(mapCategory('레티놀 아이크림', []), '아이크림');
  assert.equal(mapCategory('마일드 업 선크림 SPF50+', []), '선크림');
  assert.equal(mapCategory('톤업 선크림', []), '선크림');
  assert.equal(mapCategory('수분 크림', []), '크림');
  assert.equal(mapCategory('커버 쿠션', []), '메이크업');
  assert.equal(mapCategory('어떤 제품', ['화장품/미용', '스킨케어', '에센스']), '에센스·앰플');
  assert.equal(mapCategory('어떤 제품', ['화장품/미용', '클렌징', '폼클렌저']), '기타');
  assert.equal(mapCategory('시카 스킨케어 세트', []), '기타');
  assert.equal(cleanText('<b>A</b>&amp;B'), 'A&B');
  assert.equal(toProduct({ ...naverItems[0], category1: '디지털/가전' }), null);
});
