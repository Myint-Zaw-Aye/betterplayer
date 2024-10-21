import 'dart:async';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:rxdart/rxdart.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'better_player_vertical_slider.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  final Widget videoWidget;
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  // final Widget videoWidget;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration, required this.videoWidget,
    // required this.videoWidget,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;


  bool isMultiTouch= false;
  int touchCount = 0;
  bool isIgnoreControl = false,

      isRepeat = false,
      isLoop = false,
      isVisableVoice = false,
      isVisableBrightness = false;
  final BehaviorSubject<double> volume = BehaviorSubject.seeded(0);
  final BehaviorSubject<double> brightness = BehaviorSubject.seeded(0);

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  bool isTwoFingerDrag = true;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }
    return Stack(
      children: [
        IgnorePointer(
          ignoring: isIgnoreControl,
          child: Stack(
            //  fit: StackFit.expand,
              children: [
                if (_wasLoading)
                  Center(child: _buildLoadingWidget())
                else
                  _buildHitArea(widget.videoWidget),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(),
                ),
                Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
                _buildNextVideoWidget(),
                        
                Align(
                  alignment: Alignment.centerLeft,
                  child: volumeUpWidget(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: brightnessUpWidget(),
                )
              ],
            ),
        ),
        if (isIgnoreControl)
            IconButton(
            onPressed: _onLockCollapse,
            icon: Icon(
              Icons.lock,
              color: Colors.white,
            )),
      ],
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    isLoop = _controlsConfiguration.isLoop;
    isRepeat = _controlsConfiguration.isRepeat;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
       print("call again original");
      getOriginalVolumeAndBrightness();
    }

    super.didChangeDependencies();
  }

  getOriginalVolumeAndBrightness() async {
    double? originalVolume = await FlutterVolumeController.getVolume();
    double originalBrightness = await ScreenBrightness().current;
    if (originalVolume != null) {
      volume.value = originalVolume;
    }
    brightness.value = originalBrightness;
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    color:Colors.black.withOpacity(0.09),
                    height: _controlsConfiguration.controlBarHeight,
                    child: Row(
                      children: [
                        IconButton(
                            onPressed: () {
                              if (_betterPlayerController!.isFullScreen) {
                                _onExpandCollapse();
                              }
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            )),
                        SizedBox(
                          width: 20,
                        ),
                        Expanded(
                            child: Text(
                          _betterPlayerController!.betterPlayerDataSource!.title??'',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                        ))
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _controlsConfiguration.controlBarHeight,
                    child: Row(
                     // mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildLockButton(),
                        if (_controlsConfiguration.enableFullscreen)
                        _buildExpandButton()
                        else
                        const SizedBox(),

                        if (_betterPlayerController!.isLiveStream())
                          const SizedBox()
                        else
                        !isLoop
                        ? _buildLoopButton(Icons.repeat,_controlsConfiguration.controlBarColor,(){
                           isLoop = true;
                           setState(() {});
                           _controlsConfiguration.setLoopingNew!(true);
                        })
                        : isRepeat
                            ? _buildLoopButton(Icons.repeat_one,Theme.of(context).primaryColor,(){
                                isRepeat = false;
                                isLoop = false;
                                setState(() {});
                                _controlsConfiguration.setRepeat!(false);
                                _controlsConfiguration.setLoopingNew!(false);                                
                            })
                            : _buildLoopButton(Icons.repeat,Theme.of(context).primaryColor,(){
                                isRepeat = true;
                                setState(() {});
                                _controlsConfiguration.setRepeat!(true);
                            }),


                        
                          Spacer(),
                        if (_controlsConfiguration.enablePip)
                          _buildPipButtonWrapperWidget(
                              controlsNotVisible, _onPlayerHide)
                        else
                          const SizedBox(),
                        _buildMoreButton(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: betterPlayerControlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: Container(
              height: betterPlayerControlsConfiguration.controlBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildPipButton(),
                ],
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            color: _controlsConfiguration.controlBarColor,
          ),
          child: Icon(
            _controlsConfiguration.overflowMenuIcon,
            color: _controlsConfiguration.iconsColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        color: _controlsConfiguration.controlBarColor.withOpacity(0.1),
        margin: EdgeInsets.symmetric(vertical: 15),
        height: _controlsConfiguration.controlBarHeight + 20.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (_betterPlayerController!.isLiveStream())
              const SizedBox()
            else
              _controlsConfiguration.enableProgressBar
                  ? _buildProgressBar()
                  : const SizedBox(),
            Expanded(
              flex: 75,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   if (!_betterPlayerController!.isLiveStream())
                  _buildPrevious(_controller!),
                  if (_controlsConfiguration.enablePlayPause)
                    _buildPlayPause(_controller!)
                  else
                    const SizedBox(),

                   if (!_betterPlayerController!.isLiveStream())
                   _buildNext(_controller!),
                   
                  if (_betterPlayerController!.isLiveStream())
                    _buildLiveWidget()
                  // else
                  //   // _controlsConfiguration.enableProgressText
                  //   //     ? Expanded(child: _buildPosition())
                  //   //     : 
                        
                  //       const SizedBox(),
                  
                ],
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Text(
      _betterPlayerController!.translations.controlsLive,
      style: TextStyle(
          color: _controlsConfiguration.liveTextColor,
          fontWeight: FontWeight.bold),
    );
  }

  Widget _buildLockButton() {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: _onLockCollapse,
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              color: _controlsConfiguration.controlBarColor,
            ),
            child: Center(
              child: Icon(
                Icons.lock_open,
                color: _controlsConfiguration.iconsColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: _onExpandCollapse,
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.0),
              color: _controlsConfiguration.controlBarColor,
            ),
            child: Center(
              child: Icon(
                // _betterPlayerController!.isFullScreen
                //     ? _controlsConfiguration.fullscreenDisableIcon
                //     : _controlsConfiguration.fullscreenEnableIcon,
                Icons.screen_rotation,
                color: _controlsConfiguration.iconsColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoopButton(IconData iconData,Color color,VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.0),
              color: color,
            ),
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Icon(
                iconData,
                color: _controlsConfiguration.iconsColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea(Widget videoWidget) {
  //  if (betterPlayerController!.controlsEnabled) {
     //use videoWidget pass to control video with InteractiveViewer zoom
      return Listener(
        onPointerDown: (PointerDownEvent event) {
          touchCount++;

          if(touchCount >1 ){
            setState(() {
            isMultiTouch = true;
            print("plus" + touchCount.toString());
          });
          }
         
        },
        onPointerUp: (PointerUpEvent event) {
          setState(() {
            isMultiTouch = false;
            print('minus' + touchCount.toString());
             isVisableVoice = false;
             isVisableBrightness = false;
             touchCount = 0;
          });
        },
        child: controlDetect(child: videoWidget));
    // }
    // return videoWidget;
    // return videoWidget;
    // return Container(
    //   child: Center(
    //     child: AnimatedOpacity(
    //       opacity: controlsNotVisible ? 0.0 : 1.0,
    //       duration: _controlsConfiguration.controlsHideTime,
    //       child: _buildMiddleRow(),
    //     ),
    //   ),
    // );
  }
  
  GestureDetector controlDetect({required Widget child}){
    return GestureDetector(
      onVerticalDragDown:isMultiTouch?null:(drapDownDetails){
        dragScreenStart(drapDownDetails);
      } ,
      onVerticalDragUpdate:isMultiTouch?null:(dragUpdateDetails) {
        dragScreen(dragUpdateDetails);
      },
      onVerticalDragEnd:isMultiTouch?null: (dragEndDetails) {
        //already write in on Pointer up
        isVisableVoice = false;
        isVisableBrightness = false;
        setState(() {});
      },
      onDoubleTap: () {
        _onPlayPause();
      },
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      // onDoubleTap: () {
      //   if (BetterPlayerMultipleGestureDetector.of(context) != null) {
      //     BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
      //   }
      //   cancelAndRestartTimer();
      // },
      // onLongPress: () {
      //   if (BetterPlayerMultipleGestureDetector.of(context) != null) {
      //     BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
      //   }
      // },
      child: child,
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      color: _controlsConfiguration.controlBarColor,
      width: double.infinity,
      height: double.infinity,
      child: _betterPlayerController?.isLiveStream() == true
          ? const SizedBox()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_controlsConfiguration.enableSkips)
                  Expanded(child: _buildSkipButton())
                else
                  const SizedBox(),
                Expanded(child: _buildReplayButton(_controller!)),
                if (_controlsConfiguration.enableSkips)
                  Expanded(child: _buildForwardButton())
                else
                  const SizedBox(),
              ],
            ),
    );
  }

  Widget _buildHitAreaClickableButton(
      {Widget? icon, required void Function() onClicked}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon!],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipBackIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipBack,
    );
  }

  Widget _buildForwardButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipForwardIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipForward,
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished
          ? Icon(
              Icons.replay,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            )
          : Icon(
              controller.value.isPlaying
                  ? _controlsConfiguration.pauseIcon
                  : _controlsConfiguration.playIcon,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            ),
      onClicked: () {
        if (isFinished) {
          if (_latestValue != null && _latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return BetterPlayerMaterialClickableWidget(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: _controlsConfiguration.controlBarHeight + 20,
                    right: 24),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if (_latestValue!.volume == 0) {
          _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          _betterPlayerController!.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              (_latestValue != null && _latestValue!.volume > 0)
                  ? _controlsConfiguration.muteIcon
                  : _controlsConfiguration.unMuteIcon,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        // padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Icon(
          size: 30,
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildNext(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_next_button"),
      onTap:() {
        if (_controlsConfiguration.playNextVideo != null) {
            _controlsConfiguration.playNextVideo!();
        }
      },
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          _controlsConfiguration.nextIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPrevious(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_previous_button"),
      onTap:() {
        if (_controlsConfiguration.playPreviousVideo != null) {
            _controlsConfiguration.playPreviousVideo!();
        }
      },
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          _controlsConfiguration.previousIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  // Widget _buildPosition() {
  //   final position =
  //       _latestValue != null ? _latestValue!.position : Duration.zero;
  //   final duration = _latestValue != null && _latestValue!.duration != null
  //       ? _latestValue!.duration!
  //       : Duration.zero;

  //   return Padding(
  //     padding: _controlsConfiguration.enablePlayPause
  //         ? const EdgeInsets.only(right: 24)
  //         : const EdgeInsets.symmetric(horizontal: 22),
  //     child: RichText(
  //       text: TextSpan(
  //           text: BetterPlayerUtils.formatDuration(position),
  //           style: TextStyle(
  //             fontSize: 10.0,
  //             color: _controlsConfiguration.textColor,
  //             decoration: TextDecoration.none,
  //           ),
  //           children: <TextSpan>[
  //             TextSpan(
  //               text: ' / ${BetterPlayerUtils.formatDuration(duration)}',
  //               style: TextStyle(
  //                 fontSize: 10.0,
  //                 color: _controlsConfiguration.textColor,
  //                 decoration: TextDecoration.none,
  //               ),
  //             )
  //           ]),
  //     ),
  //   );
  // }

  Widget volumeUpWidget() {
    return StreamBuilder<double>(
        stream: volume,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return Container();
          }
          return Visibility(
              visible: isVisableVoice,
              child: Container(
                margin: EdgeInsets.only(left: 10),
                width: 30,
                height: 180,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withOpacity(0.4)),
                child: IgnorePointer(
                    child: Column(
                  children: [
                    Text(
                      volumeToRange15(snapshot.data!).toString(),
                      style: TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: VerticalSlider(
                          min: 0,
                          max: 15,
                          value: volumeToRange15(snapshot.data!).toDouble(),
                          onChanged: (value) {}),
                    ),
                    snapshot.data == 0
                        ? Icon(
                            Icons.volume_off_rounded,
                            color: Colors.white,
                          )
                        : Icon(
                            Icons.volume_up,
                            color: Colors.white,
                          )
                  ],
                )),
              ));
        });
  }

  Widget brightnessUpWidget() {
    return StreamBuilder<double>(
        stream: brightness,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return Container();
          }
          return Visibility(
              visible: isVisableBrightness,
              child: Container(
                margin: EdgeInsets.only(right: 10),
                width: 30,
                height: 200,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withOpacity(0.4)),
                child: IgnorePointer(
                    child: Column(
                  children: [
                    Text(
                      volumeToRange15(snapshot.data!).toString(),
                      style: TextStyle(color: Colors.white),
                    ),
                    VerticalSlider(
                        min: 0,
                        max: 15,
                        value: volumeToRange15(snapshot.data!).toDouble(),
                        onChanged: (value) {}),
                    Icon(
                      Icons.brightness_4_rounded,
                      color: Colors.white,
                    )
                  ],
                )),
              ));
        });
  }

  int volumeToRange15(double volume) {
    return (volume * 15).round();
  }

  Future<void> dragScreenStart(DragDownDetails dragUpdateDetails) async {
    double screenWidth = MediaQuery.of(context).size.width;
    double third = screenWidth / 3;
    double xPos = dragUpdateDetails.localPosition.dx;
    if (xPos < third) {
      //left
      isVisableBrightness = true;
    } else if (xPos > 2 * third) {
      isVisableVoice = true;
    }
    setState(() {});
  }

  Future<void> dragScreen(DragUpdateDetails dragUpdateDetails) async {
    double screenWidth = MediaQuery.of(context).size.width;
    double third = screenWidth / 3;
    double xPos = dragUpdateDetails.localPosition.dx;

    double yDelta = dragUpdateDetails.delta.dy;
    if (xPos < third) {
      //left
      if (brightness.value < 1 && yDelta < 0) {
        brightness
            .add(double.parse((brightness.value + 0.005).toStringAsFixed(3)));
      }

      if (brightness.value > 0 && yDelta > 0) {
        brightness
            .add(double.parse((brightness.value - 0.005).toStringAsFixed(3)));
      }
      await ScreenBrightness().setScreenBrightness(brightness.value);
    } else if (xPos > 2 * third) {
      //right
      if (volume.value < 1 && yDelta < 0) {
        volume.add(double.parse((volume.value + 0.005).toStringAsFixed(3)));
      }

      if (volume.value > 0 && yDelta > 0) {
        volume.add(double.parse((volume.value - 0.005).toStringAsFixed(3)));
      }
      FlutterVolumeController.showSystemUI = false;
      await FlutterVolumeController.setVolume(volume.value);
    }
    setState(() {});
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  void _onLockCollapse() {
    isIgnoreControl = !isIgnoreControl;
    changePlayerControlsNotVisible(true);
    setState(() {
      _hideTimer?.cancel();
      _startHideTimer();    
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;


    return Expanded(
      flex: 40,
      child: Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(text: TextSpan(
                text: '${BetterPlayerUtils.formatDuration(position)}',
                style: TextStyle(
                  fontSize: 10.0,
                  color: _controlsConfiguration.textColor,
                  decoration: TextDecoration.none,
                ),
              )),
            
            BetterPlayerMaterialVideoProgressBar(
              _controller,
              _betterPlayerController,
              onDragStart: () {
                _hideTimer?.cancel();
              },
              onDragEnd: () {
                _startHideTimer();
              },
              onTapDown: () {
                cancelAndRestartTimer();
              },
              colors: BetterPlayerProgressColors(
                  playedColor: _controlsConfiguration.progressBarPlayedColor,
                  handleColor: _controlsConfiguration.progressBarHandleColor,
                  bufferedColor: _controlsConfiguration.progressBarBufferedColor,
                  backgroundColor:
                      _controlsConfiguration.progressBarBackgroundColor),
            ),
            RichText(text: TextSpan(
                text: '${BetterPlayerUtils.formatDuration(duration)}',
                style: TextStyle(
                  fontSize: 10.0,
                  color: _controlsConfiguration.textColor,
                  decoration: TextDecoration.none,
                ),
              )),

              if (_controlsConfiguration.enableMute)
                    _buildMuteButton(_controller)
                  else
                    const SizedBox(),
            
          ],
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
