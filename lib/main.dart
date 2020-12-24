import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tweetdownloader/services/advertservice.dart';
import 'package:twitter_api/twitter_api.dart';
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:share/share.dart';
import 'package:auto_size_text/auto_size_text.dart';

String tweetbody;
TabController tabcontrol;
int show = 0;
bool flag = false;
String screenname;
String sharedText;
enum WhyFarther { rename, delete }
List<String> files = new List<String>();
List<Uint8List> tn = new List<Uint8List>();
List<String> filesnew = new List<String>();
List<Uint8List> tnnew = new List<Uint8List>();
String username;
String ppurl;
String videourl;
String photourl;
String tweettext;
double percentage = 0;
int intper = 0;
String filepath;
TextEditingController textcontroll = new TextEditingController();
bool isdownloading = false;
bool isdownloading_ = false;
bool iscompleted = false;
void main() => runApp(MyApp());

Future<void> checkflies() async {
  String path = await ExtStorage.getExternalStoragePublicDirectory(
      ExtStorage.DIRECTORY_DOWNLOADS);
  path = path + "/tweetvideos";
  final Directory dir = Directory(path);
  if (await dir.exists() == false) {
    final PermissionHandler _permissionHandler = PermissionHandler();
    var result = await _permissionHandler
        .requestPermissions([PermissionGroup.storage]);
    if (result[PermissionGroup.storage] == PermissionStatus.granted) {
      final Directory newdir = await dir.create(recursive: true);}
  }
  var files_ = Directory(path).listSync().toList();
  var toremove = [];
  var indexi = 0;
  for (var file in files) {
    final File f = File(file);
    if (await f.exists() == false) {
      print(file);
      toremove.add(file);
    }
  }
  files.removeWhere((element) => toremove.contains(element));
  for (var file in files_) {
    if (files.contains(file.path) == false) {
      files.add(file.path);
    }
  }
  tn.clear();
  for (var file in files) {
    final uint8list = await VideoThumbnail.thumbnailData(
      video: file,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 100,
      maxWidth:
          100, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
      quality: 25,
    );
    tn.add(uint8list);
  }
  filesnew = files.reversed.toList();
  tnnew = tn.reversed.toList();
  print(files.length);
  print(tn.length);
  print(filesnew.length);
  print(tnnew.length);
  print("finished");
}

class BarWidget extends StatefulWidget {
  @override
  _BarWidgetState createState() => _BarWidgetState();
}

class HistoryWidget extends StatefulWidget {
  @override
  _HistoryWidgetState createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends State<HistoryWidget> {
  final AdvertService _advertService = new AdvertService();
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    checkflies();
    return new ListView.separated(
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey,
        thickness: 1,
      ),
      itemCount: filesnew.length,
      itemBuilder: (context, position) {
        var f = File(filesnew[position]);
        final fstat = FileStat.statSync(filesnew[position]);
        DateTime date = fstat.accessed;
        DateFormat format = DateFormat('dd.MM.yyyy HH:mm');
        String formatted = format.format(date);
        var bytes = f.lengthSync();
        double toMB = bytes / 1000000;
        return ListTile(
            trailing: Wrap(
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {
                    List<String> list = List<String>();
                    list.add(filesnew[position]);
                    Share.shareFiles(list);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    AlertDialog alert = AlertDialog(
                      title:
                          Text("Bu videoyu silmek istediğinize emin misiniz?"),
                      actions: [
                        FlatButton(
                          child: Text("İPTAL", style: TextStyle(fontSize: 15)),
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                        ),
                        FlatButton(
                          child: Text(
                            "SİL",
                            style: TextStyle(fontSize: 15),
                          ),
                          onPressed: () async {
                            final File f = File(filesnew[position]);
                            await f.delete();
                            print(await f.exists());
                            var filename = filesnew[position];
                            await checkflies();
                            setState(() {});
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                        ),
                      ],
                    );
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return alert;
                        });
                  },
                ),
              ],
            ),
            leading: ConstrainedBox(
              child: Image.memory(tnnew[position], width: 100, height: 100),
              constraints: BoxConstraints(maxHeight: 100, maxWidth: 100),
            ),
            title: Text(files[position]
                .substring(filesnew[position].lastIndexOf('/') + 1)),
            onTap: () {
              if (show < 2) {
                show++;
              } else if (show == 2) {
                _advertService.showIntersitial();
                show = 0;
              }
              OpenFile.open(filesnew[position]);
            },
            subtitle: AutoSizeText(
              toMB.toStringAsFixed(2) + "MB" + "  " + formatted,
              maxLines: 1,
            ));
      },
    );
  }
}

String dataShared;

class _BarWidgetState extends State<BarWidget>
    with AutomaticKeepAliveClientMixin<BarWidget> {
  @override
  bool get wantKeepAlive => true;
  StreamSubscription _intentDataStreamSubscription;
  final AdvertService _advertService = AdvertService();
  @override
  void initState() {
    super.initState();
    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        sharedText = value;
        if (flag == false) {
          returntweet(sharedText.substring(sharedText.lastIndexOf("https://")),
              context);
          textcontroll.text =
              sharedText.substring(sharedText.lastIndexOf("https://"));
          flag = true;
        }
      });
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String value) {
      setState(() {
        sharedText = value;
        if (flag == false) {
          returntweet(sharedText.substring(sharedText.lastIndexOf("https://")),
              context);
          textcontroll.text =
              sharedText.substring(sharedText.lastIndexOf("https://"));
          flag = true;
        }
      });
    });
  }

  void showDownloadProgress(received, total) {
    if (total != -1) {
      print((received / total * 100).toStringAsFixed(0) + "%");
    }
    setState(() {
      if (total != -1) {
        if (received != null && total != null) {
          percentage = received / total;
          intper = int.parse((percentage * 100).toStringAsFixed(0));
        }
        if (received == total) {
          _advertService.showIntersitial();
          iscompleted = true;
          isdownloading_ = false;
          checkflies();
        }
      }
    });
    print("r:" + received.toString() + "t:" + total.toString());
  }

  var dio = Dio();
  Future download2(Dio dio, String url, String savePath) async {
    try {
      Response response = await dio.get(
        url,
        onReceiveProgress: showDownloadProgress,
        //Received data with List<int>
        options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            validateStatus: (status) {
              return status < 500;
            }),
      );
      print(response.headers);
      File file = File(savePath);
      var raf = file.openSync(mode: FileMode.write);
      // response.data is List<int> type
      raf.writeFromSync(response.data);
      await raf.close();
    } catch (e) {
      print(e);
    }
  }

  void returntweet(String tweetlink, BuildContext context) async {
    String id;

    final _twitterOauth = new twitterApi(
        consumerKey: '',
        consumerSecret: '',
        token: '',
        tokenSecret: '');
    if (tweetlink.contains('?') == false) {
      id = tweetlink.substring(tweetlink.lastIndexOf('/') + 1);
    } else {
      id = tweetlink.substring(
          tweetlink.lastIndexOf("/") + 1, tweetlink.lastIndexOf('?'));
    }
    Future twitterReq = _twitterOauth.getTwitterRequest(
      "GET",
      "statuses/show.json",
      options: {
        "id": id,
        "include_entities": "true",
        "tweet_mode": "extended",
      },
    );
    var res = await twitterReq;
    bool isvideo = false;
    var tweet = json.decode(res.body);
    if (tweet["errors"] != null) {
      if (tweet["errors"][0]["code"] == 144 ||
          tweet["errors"][0]["code"] == 8) {
        AlertDialog alert = AlertDialog(
          title: Text("Tweet Linki Hatalı!"),
          actions: [
            FlatButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          ],
        );
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return alert;
            });
      }
    } else {
      if (tweet['extended_entities'] != null) {
        for (var media in tweet['extended_entities']['media']) {
          if (media['type'] == "video") {
            int maxbit = 0;
            for (var variant in media["video_info"]["variants"]) {
              if (variant["content_type"] == "video/mp4") {
                isvideo = true;
                if (variant["bitrate"] > maxbit) {
                  maxbit = variant["bitrate"];
                  videourl = variant["url"];
                }
              }
            }
          }
        }
      }
      if (isvideo == true && isdownloading_ == false) {
        photourl = tweet["entities"]["media"][0]["media_url"].toString();
        tweettext = tweet["full_text"];
        screenname = tweet["user"]["screen_name"];
        username = tweet["user"]["name"];
        ppurl = tweet["user"]["profile_image_url_https"];
        String path = await ExtStorage.getExternalStoragePublicDirectory(
            ExtStorage.DIRECTORY_DOWNLOADS);
        path = path + "/tweetvideos";
        final Directory dir = Directory(path);
        if (await dir.exists() == false) {
          final PermissionHandler _permissionHandler = PermissionHandler();
          var result = await _permissionHandler
              .requestPermissions([PermissionGroup.storage]);
          if (result[PermissionGroup.storage] == PermissionStatus.granted) {
          final Directory newdir = await dir.create(recursive: true);}
        }
        String fullPath = "$path/$id.mp4";
        print('full path ${fullPath}');
        final PermissionHandler _permissionHandler = PermissionHandler();
        var result = await _permissionHandler
            .requestPermissions([PermissionGroup.storage]);
        if (result[PermissionGroup.storage] == PermissionStatus.granted) {
          download2(dio, videourl, fullPath);
          isdownloading_ = true;
          filepath = fullPath;
          print(username.length);
          setState(() {
            isdownloading = true;
            iscompleted = false;
          });
        }
      } else if (isvideo == false) {
        AlertDialog alert = AlertDialog(
          title: Text("Bu tweet içinde video bulunamadı!"),
          actions: [
            FlatButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          ],
        );
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return alert;
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: (isdownloading
          ? <Widget>[
              TextField(
                controller: textcontroll,
                decoration: InputDecoration(
                    border: OutlineInputBorder(), hintText: 'Tweet linki'),
              ),
              Container(
                  alignment: Alignment.center,
                  child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Row(children: [
                        RaisedButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    bottomLeft: Radius.circular(10))),
                            onPressed: () {
                              returntweet(textcontroll.text, context);
                            },
                            child: const Text('Videoyu İndir',
                                style: TextStyle(fontSize: 20))),
                        SizedBox(width: 10),
                        RaisedButton(
                          onPressed: () async {
                            ClipboardData getdata =
                                await Clipboard.getData('text/plain');
                            textcontroll.text = getdata.text;
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(10),
                                  bottomRight: Radius.circular(10))),
                          child: const Text(
                            "Kopyalananı Yapıştır",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ]))),
              Text(
                "İndirme:",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5.0),
                child: SizedBox(
                  height: 30,
                  child: Stack(
                    children: <Widget>[
                      SizedBox.expand(
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: LinearProgressIndicator(
                            value: double.parse(percentage.toString()),
                            minHeight: 30,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "%$intper",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Open Sans',
                            fontSize: 20,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              RaisedButton(
                onPressed: iscompleted
                    ? () async {
                        final File f = File(filepath);
                        if (await f.exists() == true) {
                          OpenFile.open(filepath);
                        } else {
                          AlertDialog alert = new AlertDialog(
                            title: Text("Dosya Bulunamadı"),
                            actions: [
                              FlatButton(
                                child: Text(
                                  "TAMAM",
                                  style: TextStyle(fontSize: 10),
                                ),
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                },
                              )
                            ],
                          );
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return alert;
                              });
                        }
                      }
                    : null,
                child: Text(
                  "Videoyu Aç",
                  style: TextStyle(fontSize: 16),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              RaisedButton(
                onPressed: iscompleted
                    ? () async {
                        final File f = File(filepath);
                        if (await f.exists() == true) {
                          List<String> list = new List<String>();
                          list.add(filepath);
                          Share.shareFiles(list);
                        } else {
                          AlertDialog alert = new AlertDialog(
                            title: Text("Dosya Bulunamadı"),
                            actions: [
                              FlatButton(
                                child: Text(
                                  "TAMAM",
                                  style: TextStyle(fontSize: 10),
                                ),
                                onPressed: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                },
                              )
                            ],
                          );
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return alert;
                              });
                        }
                      }
                    : null,
                child: Text(
                  "Videoyu Paylaş",
                  style: TextStyle(fontSize: 16),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              Container(
                decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(15.0)),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: ((username.length < 25)
                              ? <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: Image.network(ppurl),
                                  ),
                                  AutoSizeText(
                                    " " + username,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18.0,
                                        fontFamily: "Segoe UI"),
                                  ),
                                  AutoSizeText(
                                    " @" + screenname,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 16.0,
                                        fontFamily: "Segoe UI"),
                                  )
                                ]
                              : <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: Image.network(ppurl),
                                  ),
                                  Expanded(
                                    child: AutoSizeText(
                                      " " + username,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18.0,
                                          fontFamily: "Segoe UI"),
                                    ),
                                  ),
                                  AutoSizeText(
                                    " @" + screenname,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 16.0,
                                        fontFamily: "Segoe UI"),
                                  )
                                ]),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 3,
                          ),
                        )
                      ],
                    ),
                    Image.network(photourl.replaceAll("http:", "https:"),
                        height: 400, width: 400),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 2,
                          ),
                        )
                      ],
                    ),
                    Text(
                      tweettext,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 5,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.0,
                          fontFamily: "Segoe UI"),
                    ),
                  ],
                ),
              )
            ]
          : <Widget>[
              TextField(
                maxLines: 1,
                controller: textcontroll,
                decoration: InputDecoration(
                    border: OutlineInputBorder(), hintText: 'Tweet Linki'),
              ),
              Container(
                  alignment: Alignment.center,
                  child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Row(children: [
                        RaisedButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(10),
                                    topLeft: Radius.circular(10))),
                            onPressed: () {
                              returntweet(textcontroll.text, context);
                            },
                            child: const Text('Videoyu İndir',
                                style: TextStyle(fontSize: 20))),
                        SizedBox(width: 10),
                        RaisedButton(
                          onPressed: () async {
                            ClipboardData getdata =
                                await Clipboard.getData('text/plain');
                            textcontroll.text = getdata.text;
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(10),
                                  bottomRight: Radius.circular(10))),
                          child: const Text(
                            "Kopyalananı Yapıştır",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ]))),
            ]),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    checkflies();
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tweet Video Downloader',
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.blue,
              title: Row(children: [
                Image.asset(
                  "assets/logo.png",
                  width: 45,
                  height: 45,
                ),
                Text(
                  'Tweet Video Downloader',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Segoe UI"),
                ),
              ]),
              bottom: TabBar(
                controller: tabcontrol,
                indicator: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10)))),
                tabs: [
                  Tab(
                    text: "Video İndir",
                  ),
                  Tab(
                    text: "İndirilenler",
                  ),
                ],
                labelColor: Colors.blue,
                labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 20.0,
                    fontFamily: "Segoe UI",
                    fontWeight: FontWeight.w500),
                unselectedLabelColor: Colors.white,
              ),
            ),
            body: TabBarView(children: [
              SingleChildScrollView(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                    Container(
                        margin: EdgeInsets.only(top: 10.0, bottom: 5.0),
                        child: Text(
                          "Lütfen Twitter Linkini Alttaki Alana Yapıştırın:",
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16.0),
                        )),
                    BarWidget(),
                  ])),
              HistoryWidget(),
            ]),
          ),
        ));
  }
}
