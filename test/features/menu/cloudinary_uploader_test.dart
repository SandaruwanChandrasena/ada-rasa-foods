import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ada_rasa_foods/core/errors/data_failure.dart';
import 'package:ada_rasa_foods/features/menu/data/cloudinary_uploader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Stands in for the internet. It reads the upload, then gives an answer.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter({
    this.status = 200,
    this.body = const {'secure_url': 'https://res.cloudinary.com/x.jpg'},
    this.error,
  });

  final int status;
  final Map<String, dynamic> body;
  final DioExceptionType? error;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    // Reading the upload is what makes Dio report progress.
    await requestStream?.drain<void>();

    final type = error;
    if (type != null) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory folder;
  late String photoPath;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('upload_test');
    final photo = File('${folder.path}/kottu.jpg')
      ..writeAsBytesSync(List<int>.filled(50000, 7));
    photoPath = photo.path;
  });

  tearDown(() => folder.deleteSync(recursive: true));

  CloudinaryUploader uploaderWith(FakeAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    return CloudinaryUploader(dio);
  }

  test('sends the photo to our cloud with the unsigned preset', () async {
    final adapter = FakeAdapter();

    await uploaderWith(adapter).upload(photoPath);

    final request = adapter.lastRequest!;
    expect(
      request.uri.toString(),
      'https://api.cloudinary.com/v1_1/dtmcqgolr/image/upload',
    );
    expect(request.method, 'POST');
    final form = request.data as FormData;
    expect(
      form.fields,
      contains(
        isA<MapEntry<String, String>>()
            .having((f) => f.key, 'key', 'upload_preset')
            .having((f) => f.value, 'value', 'ada_rasa_unsigned'),
      ),
    );
    expect(form.files.single.key, 'file');
  });

  test('gives back the secure link', () async {
    final url = await uploaderWith(FakeAdapter()).upload(photoPath);

    expect(url, 'https://res.cloudinary.com/x.jpg');
  });

  test('reports progress up to 1', () async {
    final progress = <double>[];

    await uploaderWith(FakeAdapter()).upload(
      photoPath,
      onProgress: progress.add,
    );

    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
    expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
  });

  test('no internet gives a clear message', () async {
    final adapter = FakeAdapter(error: DioExceptionType.connectionError);

    await expectLater(
      uploaderWith(adapter).upload(photoPath),
      throwsA(
        const DataFailure('No internet connection. Please try again.'),
      ),
    );
  });

  test('a slow upload that times out gives the same message', () async {
    final adapter = FakeAdapter(error: DioExceptionType.sendTimeout);

    await expectLater(
      uploaderWith(adapter).upload(photoPath),
      throwsA(
        const DataFailure('No internet connection. Please try again.'),
      ),
    );
  });

  test('a refused upload gives the upload failed message', () async {
    final adapter = FakeAdapter(
      status: 400,
      body: const {
        'error': {'message': 'Upload preset not found'},
      },
    );

    await expectLater(
      uploaderWith(adapter).upload(photoPath),
      throwsA(const DataFailure(CloudinaryUploader.failedMessage)),
    );
  });

  test('an answer with no link gives the upload failed message', () async {
    final adapter = FakeAdapter(body: const {'public_id': 'x'});

    await expectLater(
      uploaderWith(adapter).upload(photoPath),
      throwsA(const DataFailure(CloudinaryUploader.failedMessage)),
    );
  });

  test('a missing file gives the upload failed message', () async {
    await expectLater(
      uploaderWith(FakeAdapter()).upload('${folder.path}/missing.jpg'),
      throwsA(const DataFailure(CloudinaryUploader.failedMessage)),
    );
  });
}