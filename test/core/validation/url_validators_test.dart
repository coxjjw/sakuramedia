import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/validation/url_validators.dart';

void main() {
  group('url validators', () {
    test('validates http and https urls', () {
      expect(isValidHttpUrl('http://llm.internal:8000'), isTrue);
      expect(isValidHttpUrl('https://api.example.com/v1'), isTrue);
      expect(isValidHttpUrl('socks5://127.0.0.1:1080'), isFalse);
      expect(isValidHttpUrl('api.example.com'), isFalse);
    });

    test('validates proxy urls', () {
      expect(isValidProxyUrl('http://127.0.0.1:7890'), isTrue);
      expect(isValidProxyUrl('https://proxy.example.com'), isTrue);
      expect(isValidProxyUrl('socks5://127.0.0.1:1080'), isTrue);
      expect(isValidProxyUrl('socks5h://proxy.example.com:1080'), isTrue);
      expect(isValidProxyUrl('ftp://proxy.example.com'), isFalse);
      expect(isValidProxyUrl('proxy.example.com:1080'), isFalse);
    });

    test('validates bare hostnames for javdb host', () {
      expect(isValidHostname('jdforrepam.com'), isTrue);
      expect(isValidHostname('sub.javdb.example'), isTrue);
      expect(isValidHostname('127.0.0.1'), isTrue);
      expect(isValidHostname('localhost'), isTrue);
      expect(isValidHostname('https://jdforrepam.com'), isFalse);
      expect(isValidHostname('jdforrepam.com/path'), isFalse);
      expect(isValidHostname('bad host.example'), isFalse);
    });
  });
}
