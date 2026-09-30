// 식약처 "화장품 원료성분정보" API를 모두 내려받아 앱의 성분 사전(assets/data/ingredient_dictionary.json)을 만들어요.
//
// 사용법 (프로젝트 폴더에서):
//   dart run tool/fetch_mfds_ingredients.dart --key=<data.go.kr 인증키(Decoding)>
//   또는 환경 변수 MFDS_SERVICE_KEY 에 키를 넣고 실행
//
// 키는 코드나 저장소에 넣지 마세요.
import 'dart:convert';
import 'dart:io';

const _defaultBase = 'https://apis.data.go.kr/1471000/CsmtcsIngdCpntInfoService01/getCsmtcsIngdCpntInfoService01';
const _out = 'assets/data/ingredient_dictionary.json';
const _rows = 100;

Future<void> main(List<String> args) async {
  String? arg(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  final key = arg('key') ?? Platform.environment['MFDS_SERVICE_KEY'];
  final base = arg('base-url') ?? _defaultBase;
  if (key == null || key.isEmpty) {
    stderr.writeln('인증키가 없어요. --key=<Decoding 키> 또는 MFDS_SERVICE_KEY 환경 변수로 넣어 주세요.');
    exit(64);
  }

  final client = HttpClient();
  final rows = <Map<String, dynamic>>[];
  int? total;
  var page = 1;
  try {
    while (true) {
      // Encoding 키(이미 %가 들어 있는 키)도 그대로 쓸 수 있게 해요.
      final k = key.contains('%') ? key : Uri.encodeQueryComponent(key);
      final uri = Uri.parse('$base?serviceKey=$k&pageNo=$page&numOfRows=$_rows&type=json');
      final json = await _getJson(client, uri);
      final header = (json['header'] ?? (json['response'] as Map?)?['header']) as Map?;
      final code = header?['resultCode']?.toString();
      if (code != null && code != '00') {
        stderr.writeln('API 오류: $code ${header?['resultMsg']}');
        exit(1);
      }
      final body = (json['body'] ?? (json['response'] as Map?)?['body']) as Map? ?? const {};
      total ??= int.tryParse('${body['totalCount']}');
      final got = <Map<String, dynamic>>[];
      _collect(body['items'], got);
      if (got.isEmpty) break;
      rows.addAll(got);
      stdout.write('\r${rows.length} / ${total ?? '?'} 건 받는 중…');
      if (total != null && rows.length >= total) break;
      page++;
    }
  } finally {
    client.close();
  }
  stdout.writeln();
  if (rows.isEmpty) {
    stderr.writeln('받은 데이터가 없어요. 활용신청 승인 여부와 키를 확인해 주세요.');
    exit(1);
  }

  // 표준명은 식약처 데이터만 써요. 앱에 들어 있던 임시 사전의 표기는 식약처 표기와 다를 수 있어서요.
  final old = File(_out).existsSync() ? jsonDecode(File(_out).readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};
  final names = <String>{};
  final synonyms = <String, String>{};
  for (final r in rows) {
    final std = '${r['INGR_KOR_NAME'] ?? ''}'.trim();
    if (std.isEmpty) continue;
    names.add(std);
    final eng = '${r['INGR_ENG_NAME'] ?? ''}'.trim();
    if (eng.isNotEmpty) synonyms.putIfAbsent(eng, () => std);
    for (final s in splitSynonyms('${r['INGR_SYNONYM'] ?? ''}')) {
      if (s != std) synonyms.putIfAbsent(s, () => std);
    }
  }
  // 임시 사전의 일상 표현(비타민C → 아스코빅애씨드 등)은 가리키는 표준명이 식약처 데이터에 있을 때만 살려요.
  Map<String, String>.from(old['synonyms'] as Map? ?? const {}).forEach((k, v) {
    if (names.contains(v)) synonyms.putIfAbsent(k, () => v);
  });
  // 표준명과 같은 글자의 이명은 필요 없어요.
  synonyms.removeWhere((k, _) => names.contains(k));

  File(_out).writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      '_note': '식약처 화장품 원료성분정보 (${DateTime.now().toIso8601String().substring(0, 10)} 내려받음, ${rows.length}건)',
      'names': names.toList()..sort(),
      'synonyms': synonyms,
    }),
  );
  stdout.writeln('완료: 표준명 ${names.length}개, 이명 ${synonyms.length}개 → $_out');
}

/// 이명 칸을 나눠요. 이명 칸의 정확한 구분 형식은 실제 데이터를 받아 봐야 알 수 있어서,
/// "1,2-헥산다이올"처럼 숫자 사이 쉼표는 나누지 않고 줄바꿈·세미콜론·(쉼표+공백)으로만 나눠요.
List<String> splitSynonyms(String raw) =>
    raw.split(RegExp(r'[;\n]|,\s+|,(?!\d)')).map((s) => s.trim()).where((s) => s.isNotEmpty && s != 'null').toList();

/// 응답 모양이 조금 달라도(items가 목록이거나 {item: [...]}) 성분 행을 모두 모아요.
void _collect(Object? node, List<Map<String, dynamic>> out) {
  if (node is Map) {
    if (node.containsKey('INGR_KOR_NAME')) {
      out.add(Map<String, dynamic>.from(node));
      return;
    }
    for (final v in node.values) {
      _collect(v, out);
    }
  } else if (node is List) {
    for (final v in node) {
      _collect(v, out);
    }
  }
}

Future<Map<String, dynamic>> _getJson(HttpClient client, Uri uri) async {
  for (var attempt = 1; ; attempt++) {
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}: ${text.length > 200 ? text.substring(0, 200) : text}');
      final decoded = jsonDecode(text);
      return Map<String, dynamic>.from(decoded as Map);
    } on FormatException {
      // 키가 틀리면 JSON 대신 XML 오류가 와요.
      stderr.writeln('\n응답이 JSON이 아니에요. 인증키(Decoding 키)가 맞는지, 활용신청이 승인됐는지 확인해 주세요.');
      exit(1);
    } catch (e) {
      if (attempt >= 3) rethrow;
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    }
  }
}
