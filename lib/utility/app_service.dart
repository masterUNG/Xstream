import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tiktok/models/otp_require_thaibulk.dart';
import 'package:flutter_tiktok/models/user_model.dart';
import 'package:flutter_tiktok/models/video_model.dart';
import 'package:flutter_tiktok/pages/check_video_upload.dart';
import 'package:flutter_tiktok/pages/detail_post.dart';
import 'package:flutter_tiktok/pages/homePage.dart';
import 'package:flutter_tiktok/utility/app_constant.dart';
import 'package:flutter_tiktok/utility/app_controller.dart';
import 'package:flutter_tiktok/utility/app_snackbar.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class AppService {
  AppController appController = Get.put(AppController());

  Future<void> processFtpUploadAndInsertDataVideo(
      {required File fileVideo,
      required String nameFileVideo,
      required String urlThumbnail,
      required String detail}) async {
    FTPConnect ftpConnect = FTPConnect(AppConstant.host,
        user: AppConstant.user, pass: AppConstant.pass);
    await ftpConnect.connect();
    bool response = await ftpConnect.uploadFileWithRetry(fileVideo,
        pRemoteName: nameFileVideo);
    await ftpConnect.disconnect();
    print('response upload ---> $response');
    if (response) {
      VideoModel videoModel = VideoModel(
        url:
            'https://stream115.otaro.co.th:443/vod/mp4:$nameFileVideo/playlist.m3u8',
        image: urlThumbnail,
        desc: nameFileVideo,
        detail: detail,
        timestamp: Timestamp.fromDate(
          DateTime.now(),
        ),
        mapUserModel: appController.currentUserModels.last.toMap(),
      );
      FirebaseFirestore.instance
          .collection('video')
          .doc()
          .set(videoModel.toMap())
          .then((value) {
        print('Insert Data Video Success');
        Get.offAll(HomePage());
        AppSnackBar(title: 'Upload Video Success', message: 'Thankyou')
            .normalSnackBar();
      });
    }
  }

  Future<String?> processUploadThumbnailVideo(
      {required File fileThumbnail, required String nameFile}) async {
    String? urlThumbnail;

    FirebaseStorage firebaseStorage = FirebaseStorage.instance;
    Reference reference = firebaseStorage.ref().child('thumbnail/$nameFile');
    UploadTask uploadTask = reference.putFile(fileThumbnail);
    await uploadTask.whenComplete(() async {
      urlThumbnail = await reference.getDownloadURL();
    });

    return urlThumbnail;
  }

  Future<void> verifyOTPThaibulk(
      {required String token,
      required String pin,
      required BuildContext context,
      required String phoneNumber}) async {
    try {
      String urlApi = 'https://otp.thaibulksms.com/v2/otp/verify';
      Map<String, dynamic> map = {};
      map['key'] = AppConstant.key;
      map['secret'] = AppConstant.secret;
      map['token'] = token;
      map['pin'] = pin;

      Dio dio = Dio();
      dio.options.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      await dio.post(urlApi, data: map).then((value) async {
        print('##11july statusCode --> ${value.statusCode}');
        if (value.statusCode == 200) {
          //Everything OK

          AppSnackBar(title: 'OTP True', message: 'Welcome').normalSnackBar();

          await FirebaseFirestore.instance
              .collection('user')
              .where('phone', isEqualTo: phoneNumber)
              .get()
              .then((value) async {
            if (value.docs.isEmpty) {
              //ยังไม่สมัครสมาชิค

              await FirebaseAuth.instance
                  .createUserWithEmailAndPassword(
                      email: 'email$phoneNumber@xstream.com',
                      password: '123456')
                  .then((value) async {
                String uid = value.user!.uid;
                UserModel userModel = UserModel(
                    name: 'Khun$phoneNumber',
                    uid: uid,
                    urlAvatar: AppConstant.urlAvatar,
                    phone: phoneNumber);
                await FirebaseFirestore.instance
                    .collection('user')
                    .doc(uid)
                    .set(userModel.toMap())
                    .then((value) {
                  findCurrentUserModel()
                      .then((value) => Get.offAll(HomePage()));
                });
              }).catchError((onError) {});
            } else {
              //เป็นสมาชิกแล้ว
              print('เป็นสมาชิกแล้ว');
              await FirebaseAuth.instance
                  .signInWithEmailAndPassword(
                      email: 'email$phoneNumber@xstream.com',
                      password: '123456')
                  .then((value) {
                findCurrentUserModel().then((value) => Get.offAll(HomePage()));
              });
            }
          });

          // readAllUserModel().then((value) async {
          //   UserModel? havePhoneUserModel;

          //   bool havePhone = false;

          //   print(
          //       '##13may userModels.length ---->>>${appController.userModels.length}');

          //   for (var element in appController.userModels) {
          //     if (element.phoneNumber == phoneNumber) {
          //       havePhone = true;
          //       havePhoneUserModel = element;
          //     }
          //   }
          //   print('##13may havePhone = $havePhone');

          //   if (havePhone) {
          //     print('##13may เคยเอาเบอร์นี่ไปสมัครแล้ว');
          //     print('##13may havePhoneModel ---> ${havePhoneUserModel!.toMap()}');

          //     await FirebaseAuth.instance
          //         .signInWithEmailAndPassword(
          //             email: havePhoneUserModel.email!,
          //             password: havePhoneUserModel.password!)
          //         .then((value) {
          //       appController.mainUid.value = value.user!.uid;
          //       Get.offAllNamed('/commentChat');
          //     });
          //   } else {
          //     print('##13may เบอร์ใหม่');

          //     print('##13may ต่อไปก็ไป สมัครสมาชิกใหม่');

          //     String email = 'phone$phoneNumber@realpost.com';
          //     String password = '123456';

          //     await FirebaseAuth.instance
          //         .createUserWithEmailAndPassword(
          //             email: email, password: password)
          //         .then((value) {
          //       String uidUser = value.user!.uid;
          //       appController.mainUid.value = uidUser;
          //       print('##13may uidUser ---> $uidUser');
          //       Get.offAll(DisplayName(
          //           uidLogin: uidUser,
          //           phoneNumber: phoneNumber,
          //           email: email,
          //           password: password));
          //     }).catchError((onError) {
          //       print(
          //           '##13may onError on create new accoount ---> ${onError.message}');
          //     });
          //   }
          // });
        }
      });
    } on Exception catch (e) {
      Get.back();
      AppSnackBar(title: 'OTP ผิด', message: 'กรุณาลองใหม่').errorSnackBar();
    }
  }

  Future<OtpRequireThaibulk> processSentSmsThaibulk(
      {required String phoneNumber}) async {
    String urlApi = 'https://otp.thaibulksms.com/v2/otp/request';

    Map<String, dynamic> map = {};
    map['key'] = AppConstant.key;
    map['secret'] = AppConstant.secret;
    map['msisdn'] = phoneNumber;

    Dio dio = Dio();
    dio.options.headers['Content-Type'] = 'application/x-www-form-urlencoded';

    var result = await dio.post(urlApi, data: map);
    OtpRequireThaibulk otpRequireThaibulk =
        OtpRequireThaibulk.fromMap(result.data);
    return otpRequireThaibulk;
  }

  Future<void> readAllVideo() async {
    if (appController.videoModels.isNotEmpty) {
      appController.videoModels.clear();
    }

    await FirebaseFirestore.instance
        .collection('video')
        .orderBy('timestamp', descending: true)
        .get()
        .then((value) {
      for (var element in value.docs) {
        VideoModel videoModel = VideoModel.fromMap(element.data());
        appController.videoModels.add(videoModel);
      }
    });
  }

  Future<void> findCurrentUserModel() async {
    var user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(user.uid)
          .get()
          .then((value) {
        if (value.data() != null) {
          UserModel userModel = UserModel.fromMap(value.data()!);
          appController.currentUserModels.add(userModel);
        }
      });
    }
  }

  Future<void> processSignOut() async {
    await FirebaseAuth.instance.signOut().then((value) {
      appController.currentUserModels.clear();
      Get.offAll(HomePage());
      AppSnackBar(title: 'Sign Out Success', message: 'Sign Out Success')
          .normalSnackBar();
    });
  }

  Future<void> processUploadVideoFromGallery() async {
    var result = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (result != null) {
      File file = File(result.path);

      int i = Random().nextInt(1000000);
      String nameFileVideo = 'xtream$i.mp4';
      String nameFileImage = 'xtream$i.jpg';

      final pathThumbnailFile =
          await VideoThumbnail.thumbnailFile(video: file.path);

      File thumbnailFile = File(pathThumbnailFile.toString());

      Get.offAll(DetailPost(
          fileThumbnail: thumbnailFile,
          fileVideo: file,
          nameFileVideo: nameFileVideo,
          nameFileImage: nameFileImage));

      // Get.to(CheckVideoUpload(
      //   fileThumbnail: thumbnailFile,
      //   fileVideo: file,
      //   nameFileImage: nameFileImage,
      //   nameFileVideo: nameFileVideo,
      // ));

      // FTPConnect ftpConnect = FTPConnect(AppConstant.host,
      //     user: AppConstant.user, pass: AppConstant.pass);
      // await ftpConnect.connect();
      // bool response =
      //     await ftpConnect.uploadFileWithRetry(file, pRemoteName: nameFile);
      // await ftpConnect.disconnect();
      // print('response upload ---> $response');
      // if (response) {
      //   VideoModel videoModel = VideoModel(
      //     url:
      //         'https://stream115.otaro.co.th:443/vod/mp4:$nameFile/playlist.m3u8',
      //     image: '',
      //     desc: nameFile,
      //     timestamp: Timestamp.fromDate(
      //       DateTime.now(),
      //     ), mapUserModel: appController.currentUserModels.last.toMap(),
      //   );
      //   FirebaseFirestore.instance
      //       .collection('video')
      //       .doc()
      //       .set(videoModel.toMap())
      //       .then((value) {
      //     print('Insert Data Video Success');
      //     AppSnackBar(title: 'Upload Video Success', message: 'Thankyou')
      //         .normalSnackBar();
      //   });
      // }
    }
  }
}
