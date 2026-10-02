// Firebase 없이 내 컴퓨터에서 바로 띄워 보는 서버.
//   NAVER_CLIENT_ID=... NAVER_CLIENT_SECRET=... node dev-server.js
// 그다음 앱을 PRODUCT_API_BASE_URL=http://localhost:8787 로 실행해요.
const http = require('node:http');
const { createHandler } = require('./src/api');

const port = Number(process.env.PORT) || 8787;
const handle = createHandler({
  clientId: () => process.env.NAVER_CLIENT_ID ?? '',
  clientSecret: () => process.env.NAVER_CLIENT_SECRET ?? '',
});

http.createServer(handle).listen(port, () => {
  const hasKey = process.env.NAVER_CLIENT_ID && process.env.NAVER_CLIENT_SECRET;
  console.log(`SkinMatch 제품 API: http://localhost:${port}`);
  console.log(`예) http://localhost:${port}/products/search?q=라운드랩%20토너`);
  if (!hasKey) console.log('⚠ NAVER_CLIENT_ID / NAVER_CLIENT_SECRET 환경 변수가 없어서 검색은 503을 돌려줘요.');
});
