// 앱이 부르는 제품 API (README의 "제품 DB API 연결" 형식과 같아요).
//   GET /products/search?q=&cat=&limit=5   → Product[]   (네이버 쇼핑 검색)
//   GET /products/barcode/{barcode}        → 404         (네이버 응답에 바코드가 없어요)
//   GET /products?cat=                     → []          (대체 추천은 전성분이 있는 제품 DB가 생기면 채워요)
//   GET /products/{id}                     → 404
//   GET /health                            → { ok, naver }
const { searchProducts, NaverError } = require('./naver');

const CACHE_MS = 10 * 60 * 1000;
const CACHE_MAX = 500;

/**
 * Node의 (req, res)를 받는 핸들러를 만들어요. Firebase(onRequest)와 로컬 서버가 같이 써요.
 * @param {{clientId: () => string, clientSecret: () => string, fetch?: typeof fetch}} cfg
 */
function createHandler(cfg) {
  // 같은 검색어를 짧은 시간에 여러 번 부르지 않게 잠깐 기억해요 (네이버 하루 호출 한도 절약).
  const cache = new Map();

  function send(res, status, body) {
    res.statusCode = status;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(JSON.stringify(body));
  }

  return async function handle(req, res) {
    // 웹(Chrome)에서 부를 수 있게 CORS를 열어요. 키는 서버에만 있어서 열어도 괜찮아요.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
      res.statusCode = 204;
      return res.end();
    }
    if (req.method !== 'GET') return send(res, 405, { error: 'GET만 쓸 수 있어요' });

    const url = new URL(req.url, 'http://localhost');
    // Firebase는 함수 이름(/api)을 빼고 주지만, 로컬에서 붙여 불러도 되게 해요.
    const path = url.pathname.replace(/^\/api(?=\/|$)/, '').replace(/\/+$/, '') || '/';
    const parts = path.split('/').filter(Boolean);

    if (path === '/health') {
      return send(res, 200, { ok: true, naver: Boolean(cfg.clientId() && cfg.clientSecret()) });
    }

    if (path === '/products/search') {
      const q = (url.searchParams.get('q') ?? '').trim().slice(0, 100);
      const cat = url.searchParams.get('cat') ?? undefined;
      const limit = Number(url.searchParams.get('limit')) || 5;
      if (!q) return send(res, 200, []);
      if (!cfg.clientId() || !cfg.clientSecret()) {
        return send(res, 503, { error: '서버에 네이버 키(NAVER_CLIENT_ID, NAVER_CLIENT_SECRET)가 없어요' });
      }
      const key = `${q}|${cat ?? ''}|${limit}`;
      const hit = cache.get(key);
      if (hit && Date.now() - hit.at < CACHE_MS) return send(res, 200, hit.list);
      try {
        const list = await searchProducts(q, {
          clientId: cfg.clientId(),
          clientSecret: cfg.clientSecret(),
          fetch: cfg.fetch,
          limit,
          category: cat,
        });
        if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value);
        cache.set(key, { at: Date.now(), list });
        return send(res, 200, list);
      } catch (e) {
        console.error(e);
        // 네이버 상태 코드(401: 키 오류, 429: 호출 한도 초과 등)는 detail로 알려 줘요.
        return send(res, 502, { error: '제품 검색에 실패했어요', detail: e instanceof NaverError ? e.status : undefined });
      }
    }

    if (parts[0] === 'products' && parts[1] === 'barcode' && parts.length === 3) {
      return send(res, 404, { error: '바코드로 찾을 수 없어요' });
    }
    if (path === '/products') return send(res, 200, []);
    if (parts[0] === 'products' && parts.length === 2) return send(res, 404, { error: '제품을 찾을 수 없어요' });

    return send(res, 404, { error: '없는 주소예요' });
  };
}

module.exports = { createHandler };
