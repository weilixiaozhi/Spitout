import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 's3_exceptions.dart';
import 's3_signature.dart';

/// S3 列表条目信息（Key + 真实 size / lastModified）。
class S3ObjectInfo {
  final String key;
  final int? size;
  final DateTime? lastModified;

  const S3ObjectInfo({required this.key, this.size, this.lastModified});
}

/// HEAD 对象返回的元数据（真实 size / lastModified / 自定义元数据）。
class S3HeadResult {
  final int? size;
  final DateTime? lastModified;
  final String? etag;
  final Map<String, String> metadata;

  const S3HeadResult({
    this.size,
    this.lastModified,
    this.etag,
    this.metadata = const {},
  });
}

/// S3 REST API 客户端
///
/// 实现基础的 S3 操作：
/// - PutObject: 上传对象
/// - GetObject: 下载对象
/// - DeleteObject: 删除对象
/// - HeadObject: 检查对象是否存在
/// - ListObjectsV2: 列出对象（含分页）
class S3Client {
  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;
  final bool useSSL;
  final int? port;

  /// 请求超时：避免网络卡死导致同步线程无限等待。
  static const Duration _requestTimeout = Duration(seconds: 30);

  late final S3SignatureV4 _signer;
  late final String _baseUrl;
  late final http.Client _httpClient;

  S3Client({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
    this.useSSL = true,
    this.port,
  }) {
    _signer = S3SignatureV4(
      accessKey: accessKey,
      secretKey: secretKey,
      region: region,
    );

    final scheme = useSSL ? 'https' : 'http';
    final portStr = port != null ? ':$port' : '';
    _baseUrl = '$scheme://$endpoint$portStr';

    _httpClient = http.Client();
  }

  /// 释放资源
  void dispose() {
    _httpClient.close();
  }

  /// PUT Object - 上传文件
  ///
  /// [metadata] 会以 `x-amz-meta-*` 请求头写入对象元数据，
  /// 供后续 HEAD 读取（指纹等同步所需信息）。
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List data,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    final uri = _requestUri(bucket, key);

    final headers = <String, String>{
      'Host': endpoint,
      'Content-Type': contentType ?? 'application/octet-stream',
      'Content-Length': '${data.length}',
      for (final entry in (metadata ?? const <String, String>{}).entries)
        'x-amz-meta-${entry.key}': entry.value,
    };

    // 签名请求（传递字节数组以正确计算 SHA256）
    final signedHeaders = _signer.sign(
      method: 'PUT',
      uri: uri,
      headers: headers,
      payloadBytes: data,
      canonicalPath: _canonicalPath(bucket, key),
    );

    try {
      final response = await _httpClient
          .put(uri, headers: signedHeaders, body: data)
          .timeout(_requestTimeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        _handleError('PutObject', response);
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } on TimeoutException catch (e) {
      throw S3NetworkException('Request timed out', originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('PutObject failed: $e', originalException: e);
    }
  }

  /// GET Object - 下载文件
  Future<Uint8List> getObject({
    required String bucket,
    required String key,
  }) async {
    final uri = _requestUri(bucket, key);

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'GET',
      uri: uri,
      headers: headers,
      canonicalPath: _canonicalPath(bucket, key),
    );

    try {
      final response =
          await _httpClient.get(uri, headers: headers).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw S3ObjectNotFoundException(key);
      } else {
        _handleError('GetObject', response);
        throw S3Exception('GetObject failed');
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } on TimeoutException catch (e) {
      throw S3NetworkException('Request timed out', originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('GetObject failed: $e', originalException: e);
    }
  }

  /// DELETE Object - 删除文件
  Future<void> deleteObject({
    required String bucket,
    required String key,
  }) async {
    final uri = _requestUri(bucket, key);

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'DELETE',
      uri: uri,
      headers: headers,
      canonicalPath: _canonicalPath(bucket, key),
    );

    try {
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(_requestTimeout);

      if (response.statusCode != 204 && response.statusCode != 200) {
        // 404 也算成功（对象已不存在）
        if (response.statusCode != 404) {
          _handleError('DeleteObject', response);
        }
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } on TimeoutException catch (e) {
      throw S3NetworkException('Request timed out', originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('DeleteObject failed: $e', originalException: e);
    }
  }

  /// HEAD Object - 检查文件是否存在并读取真实元数据。
  ///
  /// 仅 404 返回 null（文件不存在）；403 / 5xx / 网络异常必须抛错，
  /// 避免鉴权失败或瞬时故障被误判为「云端干净」。
  Future<S3HeadResult?> headObject({
    required String bucket,
    required String key,
  }) async {
    final uri = _requestUri(bucket, key);

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'HEAD',
      uri: uri,
      headers: headers,
      canonicalPath: _canonicalPath(bucket, key),
    );

    try {
      final response = await _httpClient
          .head(uri, headers: headers)
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final size = int.tryParse(response.headers['content-length'] ?? '');
        // Last-Modified 是 RFC 1123 格式（如 Wed, 21 Oct 2015 07:28:00 GMT），
        // DateTime.parse 不支持，需用 dart:io 的 HttpDate.parse 解析。
        DateTime? lastModified;
        final lastModifiedHeader = response.headers['last-modified'];
        if (lastModifiedHeader != null) {
          try {
            lastModified = HttpDate.parse(lastModifiedHeader);
          } catch (_) {
            lastModified = DateTime.tryParse(lastModifiedHeader);
          }
        }
        final metadata = <String, String>{
          for (final entry in response.headers.entries)
            if (entry.key.startsWith('x-amz-meta-'))
              entry.key.substring('x-amz-meta-'.length): entry.value,
        };
        return S3HeadResult(
          size: size,
          lastModified: lastModified,
          etag: response.headers['etag'],
          metadata: metadata,
        );
      }
      if (response.statusCode == 404) {
        return null;
      }
      // 403 / 5xx 等一律按错误处理，不得返回 false。
      _handleError('HeadObject', response);
      throw S3Exception('HeadObject failed');
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } on TimeoutException catch (e) {
      throw S3NetworkException('Request timed out', originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('HeadObject failed: $e', originalException: e);
    }
  }

  /// LIST Objects V2 - 列出对象（自动翻页，避免超过 1000 个对象被截断）。
  Future<List<S3ObjectInfo>> listObjects({
    required String bucket,
    String? prefix,
  }) async {
    final objects = <S3ObjectInfo>[];
    var continuationToken = '';

    do {
      final queryParams = <String, String>{
        'list-type': '2', // ListObjectsV2
      };
      if (prefix != null && prefix.isNotEmpty) {
        queryParams['prefix'] = prefix;
      }
      if (continuationToken.isNotEmpty) {
        queryParams['continuation-token'] = continuationToken;
      }

      final uri =
          Uri.parse('$_baseUrl/$bucket').replace(queryParameters: queryParams);

      var headers = <String, String>{
        'Host': endpoint,
      };

      headers = _signer.sign(
        method: 'GET',
        uri: uri,
        headers: headers,
        canonicalPath: '/$bucket',
      );

      try {
        final response = await _httpClient
            .get(uri, headers: headers)
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final page = _parseListObjectsResponse(response.body);
          objects.addAll(page.objects);
          continuationToken = page.nextContinuationToken ?? '';
        } else if (response.statusCode == 404) {
          throw S3BucketNotFoundException(bucket);
        } else {
          _handleError('ListObjects', response);
        }
      } on SocketException catch (e) {
        throw S3NetworkException('Network error: ${e.message}',
            originalException: e);
      } on TimeoutException catch (e) {
        throw S3NetworkException('Request timed out', originalException: e);
      } catch (e) {
        if (e is S3Exception) rethrow;
        throw S3Exception('ListObjects failed: $e', originalException: e);
      }
    } while (continuationToken.isNotEmpty);

    return objects;
  }

  /// 解析 ListObjects 响应（XML），返回对象列表与续页 token。
  ///
  /// XML 解析失败必须抛错而不是返回空列表，否则会静默漏掉全部对象。
  ({List<S3ObjectInfo> objects, String? nextContinuationToken})
      _parseListObjectsResponse(String xmlBody) {
    try {
      final document = XmlDocument.parse(xmlBody);
      final contents = document.findAllElements('Contents');
      final objects = contents
          .map((element) {
            final keyElement = element.findElements('Key').firstOrNull;
            final key = keyElement?.innerText;
            if (key == null) return null;

            final sizeElement = element.findElements('Size').firstOrNull;
            final lastModifiedElement =
                element.findElements('LastModified').firstOrNull;
            return S3ObjectInfo(
              key: key,
              size: int.tryParse(sizeElement?.innerText ?? ''),
              lastModified:
                  DateTime.tryParse(lastModifiedElement?.innerText ?? ''),
            );
          })
          .whereType<S3ObjectInfo>()
          .toList();

      final truncatedElement =
          document.findAllElements('IsTruncated').firstOrNull;
      final tokenElement =
          document.findAllElements('NextContinuationToken').firstOrNull;
      final isTruncated = truncatedElement?.innerText.trim() == 'true';
      return (
        objects: objects,
        nextContinuationToken: isTruncated ? tokenElement?.innerText : null,
      );
    } catch (e) {
      throw S3Exception('ListObjects 响应解析失败: $e', originalException: e);
    }
  }

  /// 构造实际请求 URI。
  Uri _requestUri(String bucket, String key) {
    return Uri.parse('$_baseUrl/$bucket/${_encodeKey(key)}');
  }

  /// 构造 SigV4 Canonical URI（按路径分段 RFC 3986 编码）。
  ///
  /// 不能依赖 `Uri.path`：它返回解码后的路径，非 ASCII / 特殊字符 Key
  /// 会签出错误签名。
  String _canonicalPath(String bucket, String key) {
    return '/$bucket/${_encodeKey(key)}';
  }

  /// URL 编码 Key（保留 /）
  String _encodeKey(String key) {
    return key.split('/').map(Uri.encodeComponent).join('/');
  }

  /// 统一错误处理
  void _handleError(String operation, http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    // 尝试解析 XML 错误信息
    String? errorCode;
    String? errorMessage;
    try {
      final document = XmlDocument.parse(body);
      errorCode = document.findAllElements('Code').firstOrNull?.innerText;
      errorMessage = document.findAllElements('Message').firstOrNull?.innerText;
    } catch (_) {
      // XML 解析失败，使用原始 body
    }

    final message = errorMessage ?? body;

    if (statusCode == 403) {
      if (errorCode == 'InvalidAccessKeyId' ||
          errorCode == 'SignatureDoesNotMatch') {
        throw S3AuthException('Authentication failed: $message');
      } else {
        throw S3PermissionDeniedException('Permission denied: $message');
      }
    } else if (statusCode == 404) {
      throw S3ObjectNotFoundException('Object not found');
    } else {
      throw S3Exception(
        '$operation failed (HTTP $statusCode): $message',
        statusCode: statusCode,
      );
    }
  }
}
