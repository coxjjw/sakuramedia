import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/theme.dart';

/// 「层级二」轻量播放器的控制主题 / 控件 builder 构建函数。
///
/// 原本定义在 `movie_player_surface.dart`,现抽到 base 层——供 [ThemedVideoPlayer]
/// (`base/media/video/themed_video_player.dart`)与 `MoviePlayerSurface`
/// (`domain/movies/player/movie_player_surface.dart`)共用,断开 base→domain 的
/// 反向依赖。改控制条样式 / 按钮只改这里,一处生效(进度条 / 全屏 / 音量样式一致)。

@visibleForTesting
Widget buildMoviePlayerMobileVideoControls(VideoState state) {
  return MaterialVideoControls(state);
}

@visibleForTesting
Widget buildMoviePlayerDesktopVideoControls(VideoState state) {
  return MaterialDesktopVideoControls(state);
}

Widget Function(VideoState state) resolveMoviePlayerVideoControlsBuilder({
  required bool useTouchOptimizedControls,
}) {
  return useTouchOptimizedControls
      ? buildMoviePlayerMobileVideoControls
      : buildMoviePlayerDesktopVideoControls;
}

MaterialVideoControlsThemeData buildMoviePlayerMobileControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
  bool displaySeekBar = true,
}) {
  final overlayTokens = theme.appOverlayTokens;
  return MaterialVideoControlsThemeData(
    horizontalGestureSensitivity: 3000,
    seekOnDoubleTap: true,
    seekBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerSeekBarHorizontalInset,
      0,
      overlayTokens.playerSeekBarHorizontalInset,
      overlayTokens.playerSeekBarBottomInset,
    ),
    seekGesture: true,
    volumeGesture: true,
    speedUpOnLongPress: true,
    brightnessGesture: true,
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    displaySeekBar: displaySeekBar,
    topButtonBar: topControls,
    topButtonBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerControlBarHorizontalInset,
      overlayTokens.playerControlBarTopInset,
      overlayTokens.playerControlBarHorizontalInset,
      0,
    ),
    bottomButtonBar: bottomControls,
  );
}

MaterialDesktopVideoControlsThemeData buildMoviePlayerDesktopControlsThemeData({
  required ThemeData theme,
  required List<Widget> topControls,
  required List<Widget> bottomControls,
  bool displaySeekBar = true,
}) {
  final overlayTokens = theme.appOverlayTokens;
  return MaterialDesktopVideoControlsThemeData(
    seekBarThumbColor: theme.colorScheme.primary,
    seekBarPositionColor: theme.colorScheme.primary,
    seekBarHeight: 6,
    seekBarThumbSize: 14,
    displaySeekBar: displaySeekBar,
    topButtonBar: topControls,
    topButtonBarMargin: EdgeInsets.fromLTRB(
      overlayTokens.playerControlBarHorizontalInset,
      overlayTokens.playerControlBarTopInset,
      overlayTokens.playerControlBarHorizontalInset,
      0,
    ),
    bottomButtonBar: bottomControls,
  );
}
