import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchResult {
  final String url;
  final String title;
  final String markdown;
  const SearchResult({required this.url, required this.title, required this.markdown});
}

class FirecrawlService {
  final String apiKey;
  const FirecrawlService(this.apiKey);

  Future<List<SearchResult>> search(String query, {int limit = 3}) async {
    if (apiKey.isEmpty) throw Exception('Firecrawl API key not set');

    final resp = await http.post(
      Uri.parse('https://api.firecrawl.dev/v2/search'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'query': query, 'limit': limit, 'scrapeOptions': {'formats': ['markdown']}}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Firecrawl error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = data['data'] as List<dynamic>? ?? [];
    return results.map((r) {
      final m = r as Map<String, dynamic>;
      return SearchResult(
        url: m['url'] as String? ?? '',
        title: m['metadata']?['title'] as String? ?? m['url'] as String? ?? '',
        markdown: m['markdown'] as String? ?? '',
      );
    }).toList();
  }

  String buildContext(List<SearchResult> results) {
    if (results.isEmpty) return '';
    final buf = StringBuffer('[Web Search Results]\n\n');
    for (final r in results) {
      buf.writeln('## ${r.title}');
      buf.writeln('Source: ${r.url}');
      buf.writeln();
      final snippet = r.markdown.length > 1500 ? '${r.markdown.substring(0, 1500)}...' : r.markdown;
      buf.writeln(snippet);
      buf.writeln();
    }
    return buf.toString();
  }
}
