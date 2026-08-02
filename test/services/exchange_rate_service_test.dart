// 源链契约:首源失败滑到次源;成功记住源下次先试;全挂抛 RateFetchException;
// fawazahmed0 小写键解析;frankfurter 解析。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../helpers/test_isolation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spitout/services/currency/exchange_rate_service.dart';

// 把解析用的 Map 包成 200 响应,等价原测试里的 ResponseBody.fromString。
http.Response _json(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => resetGlobalTestState());

  test('首源失败滑到次源,并记住成功源', () async {
    // 用 MockClient 桩接网络:fastly 抛异常模拟超时,其余源返回成功 JSON。
    final client = MockClient((request) {
      if (request.url.host == 'fastly.jsdelivr.net') {
        throw http.ClientException('timeout');
      }
      return Future.value(_json({
        'date': '2026-06-10',
        'cny': {'usd': 0.1477, 'jpy': 21.65}
      }));
    });
    final svc = ExchangeRateService(client: client);
    final r = await svc.fetch('CNY');
    expect(r.source, 'gcore.jsdelivr.net');
    expect(r.rateDate, '2026-06-10');
    expect(r.ratesBaseToQuote['USD'], '0.1477'); // 键转大写,值转字符串
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rateSourceIndex'), 1); // 下次从 gcore 起跳
  });

  test('全链失败抛 RateFetchException', () async {
    final client = MockClient((request) =>
        throw http.ClientException('down'));
    final svc = ExchangeRateService(client: client);
    expect(() => svc.fetch('CNY'), throwsA(isA<RateFetchException>()));
  });

  test('frankfurter 解析', () {
    final r = ExchangeRateService.parseFrankfurter('USD', {
      'base': 'USD',
      'date': '2026-06-10',
      'rates': {'CNY': 6.7715, 'JPY': 146.6},
    });
    expect(r.ratesBaseToQuote['CNY'], '6.7715');
    expect(r.rateDate, '2026-06-10');
  });

  test('记住源后下次从它起跳(跳过更靠前的源)', () async {
    SharedPreferences.setMockInitialValues({'rateSourceIndex': 1});
    final hitHosts = <String>[];
    final client = MockClient((request) {
      hitHosts.add(request.url.host);
      return Future.value(_json({'date': '2026-06-10', 'cny': {'usd': 0.1477}}));
    });
    final svc = ExchangeRateService(client: client);
    final r = await svc.fetch('CNY');
    expect(hitHosts.first, 'gcore.jsdelivr.net'); // 从 idx1 起跳,fastly 被跳过
    expect(r.source, 'gcore.jsdelivr.net');
  });
}
