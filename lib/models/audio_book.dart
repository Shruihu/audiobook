import 'audio_track.dart';

class AudioBook {
  final String name;
  final String folderPath;
  final List<AudioTrack> tracks;

  AudioBook({
    required this.name,
    required this.folderPath,
    required this.tracks,
  });

  int get trackCount => tracks.length;
}
