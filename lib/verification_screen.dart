import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cwfront/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cwfront/success_page.dart';
import 'package:cwfront/unsuccessfull_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'login_screen.dart';

class VerificationScreen extends StatefulWidget {
  final bool isClockIn;

  const VerificationScreen({super.key, required this.isClockIn});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  XFile? _image;
  String? _jwtToken; // Replace this with your method of retrieving the JWT token
  String? _username;
  LocationData? _currentLocation; // To hold the current location

  @override
  void initState() {
    super.initState();
    _loadUserData();  // Token ve username yükleme
    _getCurrentLocation(); // Fetch the current location on init
  }

  Future<void> _loadUserData() async {
    // Bu kısımda secure storage veya başka bir yöntem ile token ve username alınır
    _jwtToken = await StorageService.read('jwt_token'); // JWT token secure storage'dan alınır
    _username = await StorageService.read('username');  // Username secure storage'dan alınır
    setState(() {}); // Değişkenler güncellenince UI güncellenir
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();
    try {
      _currentLocation = await location.getLocation();
    } catch (e) {
      print('Could not get location: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });
    }
  }

  Future<bool> _submitVerification() async {
    // Gerekli verilerin mevcut olup olmadığını kontrol et
    if (_image == null || _currentLocation == null || _jwtToken == null || _username == null) {
      print('Image, location, token, or username is missing');
      return false; // Eğer eksikse false döndür
    }

    // API URL'sini belirle
    final url = widget.isClockIn ? '${StorageService.url}/clock-in' : '${StorageService.url}/clock-out';

    // Multipart request oluştur
    var request = http.MultipartRequest('POST', Uri.parse(url));

    // Request başlıklarını ayarla
    request.headers['Authorization'] = 'Bearer $_jwtToken'; // JWT token ekle
    request.fields['username'] = _username!; // Kullanıcı adını ekle
    request.fields['gpsLocation'] = '{"lat": ${_currentLocation!.latitude}, "lon": ${_currentLocation!.longitude}}'; // GPS konumunu ekle

    print("username -> $_username");
    print("username -> $_jwtToken");

    // Resmi multipart dosyası olarak ekle
    var file = await http.MultipartFile.fromPath(
      'selfie',
      _image!.path,
      contentType: MediaType(
        lookupMimeType(path.basename(_image!.path))!.split('/')[0],
        lookupMimeType(path.basename(_image!.path))!.split('/')[1],
      ),
    );

    request.files.add(file); // Dosyayı request'e ekle

    try {
      // Request'i gönder
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      // Sunucu yanıtını yazdır
      print('Response status: ${response.statusCode}');
      print('Response body: ${responseData.body}');

      // Durum koduna göre başarılı veya başarısız olduğunu döndür
      if (response.statusCode == 200) {
        return true; // Başarılı
      } else {
        return false; // Başarısız
      }
    } catch (e) {
      // Hata durumunda log yazdır
      print('Error submitting verification: $e');
      return false; // Hata durumunda da false döndür
    }
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_jwtToken == null || _username == null) {
      // Token veya username yüklenmemişse loading spinner gösterebiliriz
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 300,
                          height: 300,
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _image != null
                                ? Image.file(
                              File(_image!.path),
                              fit: BoxFit.cover,
                            )
                                : Image.asset(
                              'assets/images/bg2.jpeg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.center,
                            child: IconButton(
                              iconSize: 80,
                              icon: const Icon(Icons.add_circle, color: Colors.amber),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () async {
                        if (_image != null && _currentLocation != null) {
                          bool success = await _submitVerification();
                          if (success) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => ReportSuccessPage(isClockIn: widget.isClockIn)),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => UnsuccessfulReportPage(isClockIn: widget.isClockIn)),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(localizations!.translate('please_take_photo'))),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB8860B),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        widget.isClockIn
                            ? localizations!.translate('submit_clock_in')
                            : localizations!.translate('submit_clock_out'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 120,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
