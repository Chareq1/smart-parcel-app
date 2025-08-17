import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CameraService {
  late final Player player;
  late final VideoController controller;

  CameraService(String url) {
    player = Player();

    if(player.platform is NativePlayer) {
      const props = {
        'profile': 'low-latency',
        'untimed': '',
        'no-cache': '',
        'packet-buffering': '0',
        'packet-max_delay': '0',
        'opengl-glfinish': 'yes',
        'no-demuxer-thread': '',
        'vd-lavc-threads': '1'
      };

      for (final entry in props.entries) {
        (player.platform as NativePlayer).setProperty(entry.key, entry.value);
      }
    }

    controller = VideoController(player);
    player.open(Media(url));
  }

  VideoController getController() => controller;

  void dispose() {
    player.dispose();
  }
}