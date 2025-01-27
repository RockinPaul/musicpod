import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:watch_it/watch_it.dart';

import '../../common/view/icons.dart';
import '../common/data/audio.dart';
import '../common/view/audio_filter.dart';
import '../common/view/progress.dart';
import '../common/view/snackbars.dart';
import '../l10n/l10n.dart';
import '../library/library_model.dart';
import '../player/player_model.dart';
import 'podcast_model.dart';
import 'view/podcast_page.dart';

Future<void> searchAndPushPodcastPage({
  required BuildContext context,
  required String? feedUrl,
  String? itemImageUrl,
  String? genre,
  required bool play,
}) async {
  if (feedUrl == null) {
    showSnackBar(
      context: context,
      content: Text(context.l10n.podcastFeedIsEmpty),
    );
    return;
  }

  final libraryModel = di<LibraryModel>();
  if (libraryModel.isPageInLibrary(feedUrl)) {
    return libraryModel.pushNamed(pageId: feedUrl);
  }

  showSnackBar(
    context: context,
    duration: const Duration(seconds: 1000),
    content: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(context.l10n.loadingPodcastFeed),
        SizedBox(
          height: iconSize,
          width: iconSize,
          child: const Progress(),
        ),
      ],
    ),
  );

  di<PodcastModel>().setLoadingFeed(true);
  return findEpisodes(
    feedUrl: feedUrl,
    itemImageUrl: itemImageUrl,
    genre: genre,
  ).then(
    (podcast) async {
      if (podcast.isEmpty) {
        if (context.mounted) {
          showSnackBar(
            context: context,
            content: Text(context.l10n.podcastFeedIsEmpty),
          );
        }
        return;
      }

      if (play) {
        di<PlayerModel>().startPlaylist(listName: feedUrl, audios: podcast);
      } else {
        di<LibraryModel>().push(
          builder: (_) => PodcastPage(
            imageUrl: itemImageUrl ?? podcast.firstOrNull?.imageUrl,
            audios: podcast,
            pageId: feedUrl,
            title: podcast.firstOrNull?.album ??
                podcast.firstOrNull?.title ??
                feedUrl,
          ),
          pageId: feedUrl,
        );
      }
    },
  ).whenComplete(
    () {
      di<PodcastModel>().setLoadingFeed(false);
      if (context.mounted) ScaffoldMessenger.of(context).clearSnackBars();
    },
  ).timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      if (context.mounted) {
        showSnackBar(
          context: context,
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.podcastFeedLoadingTimeout),
              SizedBox(
                height: iconSize,
                width: iconSize,
                child: const Progress(),
              ),
            ],
          ),
        );
      }
    },
  );
}

Future<List<Audio>> findEpisodes({
  required String feedUrl,
  String? itemImageUrl,
  String? genre,
}) async {
  final episodes = <Audio>[];
  final Podcast? podcast = await compute(loadPodcast, feedUrl);

  if (podcast?.episodes.isNotEmpty == true) {
    for (var episode in podcast?.episodes ?? []) {
      if (episode.contentUrl != null) {
        final audio = Audio.fromPodcast(
          episode: episode,
          podcast: podcast,
          itemImageUrl: itemImageUrl,
          genre: genre,
        );
        episodes.add(audio);
      }
    }
  }
  final sortedEpisodes = episodes.toList();
  sortListByAudioFilter(
    audioFilter: AudioFilter.year,
    audios: sortedEpisodes,
    descending: true,
  );
  return List<Audio>.from(sortedEpisodes);
}

Future<Podcast?> loadPodcast(String url) async {
  try {
    return await Podcast.loadFeed(
      url: url,
    );
  } catch (e) {
    return null;
  }
}
