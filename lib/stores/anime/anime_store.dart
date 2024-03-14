import 'dart:isolate';
import 'dart:ui';
import 'package:anime_recommendations_app/data/network/apis/animes/scrappers/anime_scraper.dart';
import 'package:anime_recommendations_app/data/network/dio_client.dart';
import 'package:anime_recommendations_app/data/repository.dart';
import 'package:anime_recommendations_app/di/components/app_component.dart';
import 'package:anime_recommendations_app/di/modules/local_module.dart';
import 'package:anime_recommendations_app/di/modules/netwok_module.dart';
import 'package:anime_recommendations_app/di/modules/preference_module.dart';
import 'package:anime_recommendations_app/models/anime/anime.dart';
import 'package:anime_recommendations_app/models/anime/anime_list.dart';
import 'package:anime_recommendations_app/models/anime/anime_video.dart';
import 'package:anime_recommendations_app/stores/error/error_store.dart';
import 'package:anime_recommendations_app/utils/dio/dio_error_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:anime_recommendations_app/models/recomendation/recomendation_list.dart';

part 'anime_store.g.dart';

ReceivePort receivePort = ReceivePort();
final String recieverName = "Reciever";

enum ParserType { Anilibria, Gogo, AniVost, Anime9, AnimeGo }

class AnimeStore = _AnimeStore with _$AnimeStore;

abstract class _AnimeStore with Store {
  // repository instance
  Repository _repository;

  // store for handling errors
  final ErrorStore errorStore = ErrorStore();

  // constructor:---------------------------------------------------------------
  _AnimeStore(Repository repository) : this._repository = repository;

  @observable
  AnimeList animeList = AnimeList(animes: []);

  @observable
  Map<int, RecomendationList> similarsListsMap = {};

  @observable
  bool success = false;

  @observable
  bool isLoading = false;

  @observable
  ParserType scrapperType = ParserType.Anilibria;

  @observable
  String anilibriaAnimeUrl = '';

  @observable
  String anivostAnimeUrl = '';

  @observable
  String gogoAnimeUrl = '';

  @observable
  String anime9Url = '';

  @observable
  String animeGoUrl = '';

  @observable
  bool isSearching = false;

  String searchText = "";

  bool _isInited = false;

  final TextEditingController searchQuery = new TextEditingController();

  @action
  void initialize() {
    if (!_isInited) {
      searchQuery.addListener(() {
        if (searchQuery.text.isEmpty) {
          isSearching = false;
          searchText = "";
          animeList.cashedAnimes = animeList.animes;

          var list = AnimeList(animes: animeList.animes);
          list.cashedAnimes = animeList.animes;

          animeList = list;
        } else {
          isSearching = true;
          searchText = searchQuery.text;
          animeList.cashedAnimes = animeList.animes
              .where((element) =>
                  element.nameEng
                      .toLowerCase()
                      .contains(searchText.toLowerCase()) ||
                  element.name.toLowerCase().contains(searchText.toLowerCase()))
              .toList();

          var list = AnimeList(animes: animeList.animes);
          list.cashedAnimes = animeList.cashedAnimes;

          animeList = list;
        }
      });

      receivePort.listen((message) {
        if (message["list"] != null) {
          this.animeList = message["list"];
        }
        isLoading = false;
      });
    }

    _isInited = true;
  }

  @action
  void handleSearchStart() {
    isSearching = true;
    animeList.cashedAnimes = animeList.animes;
  }

  void handleSearchEnd() {
    isSearching = false;
    searchQuery.clear();
    animeList.cashedAnimes = [];
  }

  @action
  Future<void> getLinksForAnime(Anime anime) async {
    var dio = DioClient(Dio());
    AnimeScrapper.fromType(dio, ParserType.Gogo)
        .getAnimeUrl(anime.name)
        .then((value) => gogoAnimeUrl = value)
        .onError((error, stackTrace) => "");
    AnimeScrapper.fromType(dio, ParserType.AniVost)
        .getAnimeUrl(anime.name)
        .then((value) => anivostAnimeUrl = value)
        .onError((error, stackTrace) => "");
    AnimeScrapper.fromType(dio, ParserType.Anime9)
        .getAnimeUrl(anime.name)
        .then((value) => anime9Url = value)
        .onError((error, stackTrace) => "");
    AnimeScrapper.fromType(dio, ParserType.AnimeGo)
        .getAnimeUrl(anime.name)
        .then((value) => animeGoUrl = value)
        .onError((error, stackTrace) => "");
  }

  @action
  void clearAnimesUrls() {
    anilibriaAnimeUrl = '';
    anivostAnimeUrl = '';
    gogoAnimeUrl = '';
    anime9Url = '';
    animeGoUrl = '';
  }

  // actions:-------------------------------------------------------------------
  @action
  Future getAnimes() async {
    isLoading = true;

    try {
      this.animeList = await _repository.getAnimes();
    } catch (error) {
      errorStore.errorMessage = DioErrorUtil.handleError(error);
    }

    isLoading = false;
  }

  @action
  Future refreshAnimes() async {
    isLoading = true;
    final token = RootIsolateToken.instance;
    await Isolate.spawn(_refreshAnimeList, token);
  }

  static void _refreshAnimeList(RootIsolateToken? token) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token!);

    Repository? _repository = AppComponent.getReposInstance(
      NetworkModule(),
      LocalModule(),
      PreferenceModule(),
    );
    SendPort? checkingPort = IsolateNameServer.lookupPortByName(recieverName);
    try {
      var animeList = await _repository?.refreshAnimes();
      checkingPort?.send({"list": animeList});
    } catch (error) {
      checkingPort?.send({"list": null});
    }
  }

  @action
  Future<RecomendationList> querrySImilarItems(int itemDataId) async {
    isLoading = true;
    similarsListsMap[itemDataId] = RecomendationList(recomendations: []);

    try {
      similarsListsMap[itemDataId] =
          await _repository.getSimilarItems(itemDataId.toString());
    } catch (error) {
      similarsListsMap[itemDataId] = RecomendationList(recomendations: []);
      errorStore.errorMessage = DioErrorUtil.handleError(error);
    }
    isLoading = false;

    return similarsListsMap[itemDataId] ??
        RecomendationList(recomendations: []);
  }

  @action
  Future<List<AnimeVideo>> getAnimeLinks(String animeId, int episodeNum) async {
    try {
      return await _repository.getProviderAnimeLinks(
          animeId, episodeNum, scrapperType);
    } catch (error) {
      errorStore.errorMessage = DioErrorUtil.handleError(error);
      return [];
    }
  }

  @action
  Future<String> getAnimeId(Anime anime) async {
    try {
      return await _repository.getProviderAnimeId(anime, scrapperType);
    } catch (error) {
      errorStore.errorMessage = DioErrorUtil.handleError(error);
      return "";
    }
  }
}
