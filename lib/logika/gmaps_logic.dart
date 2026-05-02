import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class GmapsResult {
  final String? name;
  final double? latitude;
  final double? longitude;
  final File? photoFile;

  GmapsResult({this.name, this.latitude, this.longitude, this.photoFile});
}

class GmapsLogic {
  final Dio _dio = Dio();

  Future<GmapsResult> parseUrl(String rawText) async {
    // 0. Extract Name and URL from raw text
    String textBeforeUrl = '';
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final urlMatch = urlRegExp.firstMatch(rawText);

    if (urlMatch != null) {
      textBeforeUrl = rawText.substring(0, urlMatch.start).trim();
    } else {
      throw Exception('Tidak ditemukan URL dalam teks.');
    }

    String url = urlMatch.group(0)!;
    String finalUrl = url;

    if (url.contains('goo.gl')) {
      final response = await _dio.get(
        url,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.headers.map.containsKey('location')) {
        finalUrl = response.headers.map['location']!.first;
      }
    }

    double? lat, lng;
    String? placeName;
    String? photoUrl;

    if (textBeforeUrl.isNotEmpty) {
      placeName = textBeforeUrl.split('\n').first.split(',').first.trim();
    }

    if (placeName == null || placeName.isEmpty || placeName == "Google Maps") {
      final placeMatch = RegExp(r'/maps/place/([^/]+)').firstMatch(finalUrl);
      if (placeMatch != null) {
        String rawUrlName = Uri.decodeComponent(placeMatch.group(1)!.replaceAll('+', ' '));
        placeName = rawUrlName.split(',').first.trim();
      }
    }

    try {
      final response = await _dio.get(
        finalUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
          },
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data.toString();

        if (placeName == null || placeName.isEmpty || placeName == "Google Maps") {
          final titleMeta = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"').firstMatch(html);
          if (titleMeta != null) {
            String rawTitle = titleMeta.group(1)!;
            placeName = rawTitle.split(' - Google Maps')[0].split(' · ')[0].split(',').first.trim();
          }
        }

        final imgPattern = RegExp(r'https?://lh\d+\.googleusercontent\.com/(?:p|gps-cs-s)/[a-zA-Z0-9_-]+');
        final matches = imgPattern.allMatches(html);
        if (matches.isNotEmpty) {
          for (var m in matches) {
            if (m.group(0)!.length > 40) {
              photoUrl = m.group(0);
              break;
            }
          }
          photoUrl ??= matches.first.group(0);
        }

        if (photoUrl == null) {
          final imageMeta = RegExp(r'<meta[^>]*property="og:image"[^>]*content="([^"]+)"').firstMatch(html);
          if (imageMeta != null) {
            String candidateUrl = imageMeta.group(1)!;
            if (!candidateUrl.contains('staticmap') && !candidateUrl.contains('maps/api')) {
              photoUrl = candidateUrl;
            }
          }
        }

        if (photoUrl != null) {
          photoUrl = photoUrl.replaceAll('&amp;', '&');
          if (photoUrl.contains('googleusercontent.com')) {
            if (photoUrl.contains('=')) {
              photoUrl = '${photoUrl.split('=')[0]}=w1000-h1000';
            } else {
              photoUrl = '$photoUrl=w1000-h1000';
            }
          }
        }

        final metaMatch = RegExp(r'center=(-?\d+\.\d+)%2C(-?\d+\.\d+)').firstMatch(html);
        if (metaMatch != null) {
          lat = double.tryParse(metaMatch.group(1)!);
          lng = double.tryParse(metaMatch.group(2)!);
        } else {
          final coordsMatches = RegExp(r'\[(-?\d+\.\d+),(-?\d+\.\d+)\]').allMatches(html);
          for (var m in coordsMatches) {
            double? tLat = double.tryParse(m.group(1)!);
            double? tLng = double.tryParse(m.group(2)!);
            if (tLat != null && tLng != null && tLat > -11 && tLat < 6 && tLng > 95 && tLng < 141) {
              lat = tLat;
              lng = tLng;
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching HTML in logic: $e");
    }

    if (lat == null || lng == null) {
      final atMatch = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(finalUrl);
      final queryMatch = RegExp(r'[?&](?:q|query|ll)=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(finalUrl);

      if (atMatch != null) {
        lat = double.tryParse(atMatch.group(1)!);
        lng = double.tryParse(atMatch.group(2)!);
      } else if (queryMatch != null) {
        lat = double.tryParse(queryMatch.group(1)!);
        lng = double.tryParse(queryMatch.group(2)!);
      }
    }

    File? photoFile;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final response = await _dio.get(
          photoUrl,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'image/*',
              'Referer': 'https://www.google.com/',
            },
          ),
        );

        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          photoFile = File('${tempDir.path}/gmaps_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await photoFile.writeAsBytes(response.data);
          if (await photoFile.length() < 500) photoFile = null;
        }
      } catch (e) {
        debugPrint("Gagal mendownload foto di logic: $e");
      }
    }

    return GmapsResult(
      name: placeName,
      latitude: lat,
      longitude: lng,
      photoFile: photoFile,
    );
  }
}
