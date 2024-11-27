import 'dart:io';

import 'package:better_player/better_player.dart';
import 'package:example/constants.dart';
import 'package:example/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;

  @override
  void initState() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: true,
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ],
      controlsConfiguration: BetterPlayerControlsConfiguration(
        progressBarPlayedColor:Colors.green,
        progressBarHandleColor:Colors.green
      )
    );
    
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _setupDataSource();
    //_betterPlayerController.setupDataSource(_betterPlayerDataSource);
    super.initState();
  }

  void _setupDataSource() async {
    var filePath = await Utils.getFileUrl(Constants.fileTestVideoUrl);
    File file = File(filePath);

    List<int> bytes = file.readAsBytesSync().buffer.asUint8List();
    BetterPlayerDataSource dataSource =
        BetterPlayerDataSource.memory(bytes, videoExtension: "mp4");
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BetterPlayer(controller: _betterPlayerController),
    );
  }
}
