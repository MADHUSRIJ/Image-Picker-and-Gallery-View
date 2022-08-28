import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:galleryimage/galleryimage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:img_app/api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class FirebaseIn extends StatefulWidget {
  const FirebaseIn({Key? key}) : super(key: key);

  @override
  State<FirebaseIn> createState() => _FirebaseInState();
}

class _FirebaseInState extends State<FirebaseIn> {
  final Future<FirebaseApp> _intialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: _intialization,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text("Error: ${snapshot.error}"),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.done) {
              return StreamBuilder(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, streamsnapshot) {
                    if (streamsnapshot.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Text("Error: ${streamsnapshot.hasError}"),
                        ),
                      );
                    }

                    if (streamsnapshot.connectionState ==
                        ConnectionState.active) {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        return const ImageLoad();
                      } else {
                        FirebaseAuth.instance.signInAnonymously();
                      }
                    }

                    return Scaffold(
                      body: Center(
                        child: Text(
                          "Checking Authentication",
                          style: Theme.of(context).textTheme.bodyText2,
                        ),
                      ),
                    );
                  });
            }
            return const Scaffold(
              body: Center(
                child: Text("Intialising App....."),
              ),
            );
          }),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: FirebaseIn(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ImageLoad extends StatefulWidget {
  const ImageLoad({Key? key}) : super(key: key);

  @override
  State<ImageLoad> createState() => _ImageLoadState();
}

class _ImageLoadState extends State<ImageLoad> {
  List<String> imgs = [];
  bool check = false;
  Future<void> _fetchdata() async {
    QuerySnapshot q =
        await FirebaseFirestore.instance.collection("Images").get();
    final d = q.docs.map((doc) => (doc.get('image'))).toList();

    for (String k in d) {
      imgs.add(k);
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchdata().whenComplete(() => {
          setState(() {
            check = true;
          })
        });
  }

  @override
  Widget build(BuildContext context) {
    return check
        ? MyHomePage(imgs: imgs)
        : Center(
            child: Container(
              child: Text("Loading.."),
            ),
          );
  }
}

class MyHomePage extends StatefulWidget {
  final List<String> imgs;
  const MyHomePage({Key? key, required this.imgs}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? image;

  File? _imageFile;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    XFile? selected = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = File(selected!.path);
    });
  }

  UploadTask? task;

  Future uploadFile() async {
    if (_imageFile == null) {
      image = "No preview";
      _upload();
      return;
    }

    final fileName = _imageFile!.path.split('/').last;
    final destination = 'Images/$fileName';

    // print("Filename : " + fileName);
    task = FirebaseApi.uploadFile(destination, _imageFile!);

    if (task == null) return;

    final snapshot = await task!.whenComplete(() {});

    final urlDownload = await snapshot.ref.getDownloadURL();

    image = urlDownload;

    _upload();
  }

  Future<String?> _upload() async {
    try {
      DocumentReference docref =
          FirebaseFirestore.instance.collection("Images").doc();
      Map<String, dynamic> data = {
        "image": image,
        "doc_id": docref.id,
      };
      FirebaseFirestore.instance
          .collection("Images")
          .doc(docref.id)
          .set(data)
          .whenComplete(() => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => ImageLoad())));
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Image Picker"),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 20,
              ),
              Container(
                alignment: Alignment.center,
                height: 100,
                width: 200,
                child: _imageFile != null
                    ? Image.file(
                        _imageFile!,
                        fit: BoxFit.fill,
                      )
                    : Container(),
              ),
              _imageFile != null
                  ? SizedBox(
                      height: 20,
                    )
                  : Container(),
              GestureDetector(
                onTap: () {
                  _imageFile != null ? uploadFile() : _pickImage();
                },
                child: Container(
                  height: 60,
                  width: 200,
                  alignment: Alignment.center,
                  color: Colors.blue,
                  child: Text(
                    _imageFile != null ? "Upload Image" : "Select Image",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(
                height: 200,
              ),
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "Images",
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 20),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Tap to show image"),
                  GalleryImage(
                    numOfShowImages: widget.imgs.length,
                    imageUrls: widget.imgs,
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}
