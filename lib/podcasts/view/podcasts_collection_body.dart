import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:yaru/yaru.dart';

import '../../app/connectivity_model.dart';
import '../../common/data/audio.dart';
import '../../common/view/adaptive_container.dart';
import '../../common/view/audio_card.dart';
import '../../common/view/audio_card_bottom.dart';
import '../../common/view/common_widgets.dart';
import '../../common/view/loading_grid.dart';
import '../../common/view/no_search_result_page.dart';
import '../../common/view/offline_page.dart';
import '../../common/view/safe_network_image.dart';
import '../../common/view/theme.dart';
import '../../constants.dart';
import '../../extensions/build_context_x.dart';
import '../../l10n/l10n.dart';
import '../../library/library_model.dart';
import '../../player/player_model.dart';
import '../../search/search_model.dart';
import '../podcast_model.dart';

class PodcastsCollectionBody extends StatelessWidget with WatchItMixin {
  const PodcastsCollectionBody({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.t;
    final isOnline = watchPropertyValue((ConnectivityModel m) => m.isOnline);
    if (!isOnline) return const OfflineBody();

    final loading =
        watchPropertyValue((PodcastModel m) => m.checkingForUpdates);
    final subs = watchPropertyValue((LibraryModel m) => m.podcasts);
    watchPropertyValue((LibraryModel m) => m.podcastUpdatesLength);
    final playerModel = di<PlayerModel>();
    final libraryModel = di<LibraryModel>();
    final podcastUpdateAvailable = libraryModel.podcastUpdateAvailable;
    final feedHasDownload = libraryModel.feedHasDownload;
    final updatesLength =
        watchPropertyValue((LibraryModel m) => m.podcastUpdatesLength);
    final model = di<PodcastModel>();
    final updatesOnly = watchPropertyValue((PodcastModel m) => m.updatesOnly);
    final downloadsOnly =
        watchPropertyValue((PodcastModel m) => m.downloadsOnly);
    final subsLength = watchPropertyValue((LibraryModel m) => m.podcastsLength);
    final feedsWithDownloadLength =
        watchPropertyValue((LibraryModel m) => m.feedsWithDownloadsLength);
    final setUpdatesOnly = model.setUpdatesOnly;
    final setDownloadsOnly = model.setDownloadsOnly;
    final removeUpdate = libraryModel.removePodcastUpdate;

    final itemCount = updatesOnly
        ? updatesLength
        : (downloadsOnly ? feedsWithDownloadLength : subsLength);

    return subsLength == 0
        ? NoSearchResultPage(
            icon: const AnimatedEmoji(AnimatedEmojis.faceInClouds),
            message: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.noPodcastSubsFound),
                const SizedBox(
                  height: 10,
                ),
                ImportantButton(
                  onPressed: () {
                    di<LibraryModel>().pushNamed(pageId: kSearchPageId);
                    di<SearchModel>()
                      ..setAudioType(AudioType.podcast)
                      ..setSearchQuery(null)
                      ..search();
                  },
                  child: Text(context.l10n.discover),
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: YaruChoiceChipBar(
                    chipBackgroundColor: chipColor(theme),
                    selectedChipBackgroundColor:
                        chipSelectionColor(theme, loading),
                    borderColor: chipBorder(theme, loading),
                    yaruChoiceChipBarStyle: YaruChoiceChipBarStyle.wrap,
                    clearOnSelect: false,
                    selectedFirst: false,
                    labels: [
                      Text(context.l10n.newEpisodes),
                      Text(
                        context.l10n.downloadsOnly,
                      ),
                    ],
                    isSelected: [
                      updatesOnly,
                      downloadsOnly,
                    ],
                    onSelected: loading
                        ? null
                        : (index) {
                            if (index == 0) {
                              if (updatesOnly) {
                                setUpdatesOnly(false);
                              } else {
                                model.update(context.l10n.newEpisodeAvailable);

                                setUpdatesOnly(true);
                                setDownloadsOnly(false);
                              }
                            } else {
                              if (downloadsOnly) {
                                setDownloadsOnly(false);
                              } else {
                                setDownloadsOnly(true);
                                setUpdatesOnly(false);
                              }
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              if (loading)
                Expanded(child: LoadingGrid(limit: subsLength))
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.builder(
                        padding: getAdaptiveHorizontalPadding(
                          constraints: constraints,
                        ),
                        itemCount: itemCount,
                        gridDelegate: audioCardGridDelegate,
                        itemBuilder: (context, index) {
                          final MapEntry<String, List<Audio>> podcast;
                          if (updatesOnly) {
                            podcast = subs.entries
                                .where((e) => podcastUpdateAvailable(e.key))
                                .elementAt(index);
                          } else if (downloadsOnly) {
                            podcast = subs.entries
                                .where((e) => feedHasDownload(e.key))
                                .elementAt(index);
                          } else {
                            podcast = subs.entries.elementAt(index);
                          }

                          final artworkUrl600 =
                              podcast.value.firstOrNull?.albumArtUrl ??
                                  podcast.value.firstOrNull?.imageUrl;
                          final image = SafeNetworkImage(
                            url: artworkUrl600,
                            fit: BoxFit.cover,
                            height: kAudioCardDimension,
                            width: kAudioCardDimension,
                          );

                          return AudioCard(
                            image: image,
                            bottom: AudioCardBottom(
                              style: podcastUpdateAvailable(podcast.key)
                                  ? theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ) ??
                                      TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      )
                                  : null,
                              text: podcast.value.firstOrNull?.album ??
                                  podcast.value.firstOrNull?.title ??
                                  podcast.value.firstOrNull.toString(),
                            ),
                            onPlay: () => playerModel
                                .startPlaylist(
                                  audios: podcast.value,
                                  listName: podcast.key,
                                )
                                .then((_) => removeUpdate(podcast.key)),
                            onTap: () =>
                                libraryModel.pushNamed(pageId: podcast.key),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
  }
}
