// 네이버 쇼핑 검색 API → 앱의 Product 형식으로 바꾸는 부분.
// Firebase에 의존하지 않아서 로컬 서버(dev-server.js)와 테스트에서도 그대로 써요.
//
// 네이버 응답 항목(공식 문서 기준): title, link, image, lprice, hprice, mallName,
// productId, productType, brand, maker, category1~4
// 전성분과 바코드는 네이버 응답에 없어요. 그래서 ingredients는 항상 빈 배열이에요.

const NAVER_URL = 'https://openapi.naver.com/v1/search/shop.json';

/** 앱 단계 종류 (lib/core/ingredient_db.dart의 kStepCategories와 같아야 해요) */
const APP_CATEGORIES = ['토너', '에센스·앰플', '세럼', '아이크림', '크림', '선크림', '메이크업', '기타'];

/** HTML 태그(<b>)와 자주 나오는 엔티티를 지워요. */
function cleanText(s) {
  return String(s ?? '')
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

// 제품명에 들어 있는 단어가 카테고리보다 정확해요 (예: 카테고리는 "에센스"인데 이름은 "세럼").
// 순서가 중요해요: "아이크림"이 "크림"보다, "선크림"이 "크림"보다 먼저 와야 해요.
const RULES = [
  [/선크림|선케어|선스틱|선쿠션|선로션|선젤|선세럼|선블록|자외선|sun\s?(cream|stick|screen)|spf\s?\d/i, '선크림'],
  [/아이\s?크림|아이케어|아이\s?세럼|eye\s?cream/i, '아이크림'],
  [/쿠션|파운데이션|비비크림|bb크림|cc크림|프라이머|컨실러|립스틱|틴트|메이크업|베이스/i, '메이크업'],
  [/토너|스킨(?!케어)|토닝|패드|toner/i, '토너'],
  [/앰플|에센스|ampoule|essence/i, '에센스·앰플'],
  [/세럼|serum/i, '세럼'],
  [/크림|로션|에멀전|cream|lotion/i, '크림'],
];

/** 제품명 → 카테고리 → 기타 순서로 앱 단계 종류를 정해요. */
function mapCategory(title, categories) {
  for (const text of [title, categories.join(' ')]) {
    for (const [re, cat] of RULES) if (re.test(text)) return cat;
  }
  return '기타';
}

/** 비교용: 공백·기호를 지우고 소문자로 */
function norm(s) {
  return s.toLowerCase().replace(/[\s\-_/·,.()[\]]/g, '');
}

/** 네이버 상품 하나 → Product (화장품이 아니면 null) */
function toProduct(item) {
  const cats = [item.category1, item.category2, item.category3, item.category4].map(cleanText).filter(Boolean);
  // 케이스, 소품, 다른 분류 상품을 걸러요.
  if (cats[0] !== '화장품/미용') return null;
  if (/소품|도구|용기|파우치/.test(cats.join(' '))) return null;

  const title = cleanText(item.title);
  if (!title) return null;
  const brand = cleanText(item.brand) || cleanText(item.maker);
  // 제품명이 브랜드로 시작하면 브랜드를 한 번만 보여 줘요.
  let name = title;
  if (brand && norm(name).startsWith(norm(brand))) {
    const rest = name.slice(brand.length).trim();
    if (rest) name = rest;
  }
  return {
    id: `naver_${item.productId}`,
    brand: brand || '브랜드 정보 없음',
    name,
    category: mapCategory(title, cats),
    ingredients: [],
    imageUrl: item.image || null,
    source: 'naver',
    naverCategory: cats.join(' > '),
    price: Number(item.lprice) || null,
    link: item.link || null,
  };
}

/** 같은 제품이 판매처별로 여러 번 나오는 걸 합쳐요. */
function dedupe(products) {
  const seen = new Set();
  const out = [];
  for (const p of products) {
    const key = norm(p.brand + p.name);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(p);
  }
  return out;
}

class NaverError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/**
 * 네이버 쇼핑에서 화장품을 검색해요.
 * @param {string} query
 * @param {{clientId: string, clientSecret: string, fetch?: typeof fetch, limit?: number, category?: string}} opts
 */
async function searchProducts(query, opts) {
  const q = String(query ?? '').trim();
  if (!q) return [];
  const limit = Math.min(Math.max(Number(opts.limit) || 5, 1), 20);
  const doFetch = opts.fetch ?? fetch;
  // 화장품이 아닌 상품이 섞여 오니 넉넉히 받아서 걸러요.
  const url = `${NAVER_URL}?query=${encodeURIComponent(q)}&display=40&start=1&sort=sim`;
  const res = await doFetch(url, {
    headers: { 'X-Naver-Client-Id': opts.clientId, 'X-Naver-Client-Secret': opts.clientSecret },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new NaverError(res.status, `네이버 API 오류 ${res.status}: ${body.slice(0, 200)}`);
  }
  const json = await res.json();
  let list = dedupe((json.items ?? []).map(toProduct).filter(Boolean));
  if (opts.category && APP_CATEGORIES.includes(opts.category)) {
    // 고른 단계 종류를 앞으로 보내요 (다른 종류도 빼지는 않아요).
    list = [...list.filter((p) => p.category === opts.category), ...list.filter((p) => p.category !== opts.category)];
  }
  return list.slice(0, limit);
}

module.exports = { searchProducts, toProduct, mapCategory, cleanText, dedupe, NaverError, APP_CATEGORIES };
