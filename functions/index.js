// Firebase Cloud Functions 진입점. 배포하면 주소는
//   https://asia-northeast3-<프로젝트ID>.cloudfunctions.net/api
// 이고, 이 주소를 앱의 PRODUCT_API_BASE_URL에 넣어요.
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { createHandler } = require('./src/api');

// 키는 코드에 넣지 않고 Secret Manager에 넣어요:
//   firebase functions:secrets:set NAVER_CLIENT_ID
//   firebase functions:secrets:set NAVER_CLIENT_SECRET
const naverId = defineSecret('NAVER_CLIENT_ID');
const naverSecret = defineSecret('NAVER_CLIENT_SECRET');

const handle = createHandler({
  clientId: () => naverId.value(),
  clientSecret: () => naverSecret.value(),
});

exports.api = onRequest(
  { region: 'asia-northeast3', secrets: [naverId, naverSecret], maxInstances: 5, memory: '256MiB' },
  handle,
);
