import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_cloud_sync_s3/src/s3_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('S3SignatureV4 签名', () {
    // 使用 AWS 官方 SigV4 文档中的演示凭据，保证与社区向量一致
    final signer = S3SignatureV4(
      accessKey: 'AKIDEXAMPLE',
      secretKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
      region: 'us-east-1',
    );

    final uri = Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt');

    Map<String, String> doSign({List<int>? payloadBytes}) {
      return signer.sign(
        method: payloadBytes == null ? 'GET' : 'PUT',
        uri: uri,
        headers: {'Host': 'examplebucket.s3.amazonaws.com'},
        payloadBytes: payloadBytes,
      );
    }

    test('空 payload 的 content-sha256 等于已知向量', () {
      final headers = doSign();
      // SHA256("") 的标准值，用于验证 _toHex 输出与官方实现一致
      expect(
        headers['x-amz-content-sha256'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('非空 payload 的 content-sha256 与 crypto Digest 一致', () {
      final payload = utf8.encode('hello');
      final headers = doSign(payloadBytes: payload);
      // 与 crypto 包自带 hex（Digest.toString）交叉验证，防止手写 _toHex 引入偏差
      expect(headers['x-amz-content-sha256'], sha256.convert(payload).toString());
      // "hello" 的 SHA256 固定向量
      expect(
        headers['x-amz-content-sha256'],
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });

    test('Authorization header 结构完整且 Signature 为 64 位小写 hex', () {
      final headers = doSign();
      final auth = headers['Authorization']!;
      expect(auth, startsWith('AWS4-HMAC-SHA256 '));
      expect(auth, contains('Credential=AKIDEXAMPLE/'));
      expect(auth, contains('/us-east-1/s3/aws4_request'));
      expect(auth, contains('SignedHeaders='));
      // Signature 是 HMAC 输出经 _toHex 编码的结果，必须是 64 位小写十六进制
      final sigMatch = RegExp(r'Signature=([0-9a-f]{64})$').firstMatch(auth);
      expect(sigMatch, isNotNull);
    });

    test('x-amz-date 为 AWS 标准格式', () {
      final headers = doSign();
      expect(headers['x-amz-date'], matches(RegExp(r'^\d{8}T\d{6}Z$')));
    });
  });
}
