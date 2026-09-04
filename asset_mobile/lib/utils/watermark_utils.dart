import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;

class WatermarkUtils {

  static Future<File?> addWatermarkToImage(File imageFile) async {
    try {
      // 1. Get Location
      String locationText = 'Lokasi tidak diketahui';
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          try {
            Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium);
            List<Placemark> placemarks = await placemarkFromCoordinates(
                position.latitude, position.longitude);
            if (placemarks.isNotEmpty) {
              Placemark place = placemarks.first;
              String address = '';
              if (place.street != null && place.street!.isNotEmpty) address += '${place.street}, ';
              if (place.subLocality != null && place.subLocality!.isNotEmpty) address += '${place.subLocality}, ';
              if (place.locality != null && place.locality!.isNotEmpty) address += place.locality!;
              locationText = address.isNotEmpty ? address : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
            } else {
              locationText = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
            }
          } catch (e) {
            print('Error getting location for watermark: $e');
          }
        }
      }

      // 2. Format DateTime
      String dateTimeText = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

      // 3. Read image bytes and decode to ui.Image (scaled to max 1280px for performance & small size)
      final Uint8List fileBytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(
        fileBytes,
        targetWidth: 1280,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image sourceImage = frameInfo.image;

      final int imgWidth = sourceImage.width;
      final int imgHeight = sourceImage.height;

      // 4. Draw on Canvas using dart:ui (No Flutter widget tree needed!)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgWidth.toDouble(), imgHeight.toDouble()));

      // Draw the source image
      canvas.drawImage(sourceImage, Offset.zero, Paint());

      // Watermark text setup
      final double fontSize = imgWidth * 0.030; // Scale font to image width
      final double padding = imgWidth * 0.018;

      final textPainterDate = TextPainter(
        text: TextSpan(
          text: dateTimeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: imgWidth * 0.8);

      final textPainterLoc = TextPainter(
        text: TextSpan(
          text: locationText,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize * 0.75,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: imgWidth * 0.85);

      // Background behind text
      final double boxHeight = textPainterDate.height + textPainterLoc.height + padding * 3;
      final double boxWidth = [textPainterDate.width, textPainterLoc.width].reduce((a, b) => a > b ? a : b) + padding * 2;
      final double boxLeft = imgWidth - boxWidth - padding;
      final double boxTop = imgHeight - boxHeight - padding;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
          const Radius.circular(8),
        ),
        Paint()..color = Colors.black.withOpacity(0.55),
      );

      // Paint date text
      textPainterDate.paint(canvas, Offset(boxLeft + padding, boxTop + padding));
      // Paint location text
      textPainterLoc.paint(canvas, Offset(boxLeft + padding, boxTop + padding + textPainterDate.height + padding * 0.5));

      final ui.Picture picture = recorder.endRecording();
      final ui.Image resultImage = await picture.toImage(imgWidth, imgHeight);
      final ByteData? byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return imageFile;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 5. Write to temp file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFile = File('${directory.path}/watermark_$timestamp.jpg');
      await newFile.writeAsBytes(pngBytes, flush: true);
      return newFile;

    } catch (e) {
      print('Error adding watermark: $e');
      return imageFile; // Fallback: return original image
    }
  }
}
