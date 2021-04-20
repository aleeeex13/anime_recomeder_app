import 'package:boilerplate/data/local/datasources/anime/anime_datasource.dart';
import 'package:boilerplate/data/local/datasources/user/user_datasource.dart';
import 'package:boilerplate/data/local/datasources/token/token_datasource.dart';
import 'package:boilerplate/data/network/apis/users/users_api.dart';
import 'package:boilerplate/data/network/dio_client.dart';
import 'package:boilerplate/data/repository.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/modules/local_module.dart';
import 'package:boilerplate/di/modules/netwok_module.dart';
import 'package:boilerplate/di/modules/preference_module.dart';
import 'package:boilerplate/data/network/apis/animes/anime_api.dart';

/// The top level injector that stitches together multiple app features into
/// a complete app.
abstract class AppComponent {
  static Repository _repository;
  static bool isInited = false;
  NetworkModule networkModule;
  LocalModule localModule;
  PreferenceModule preferenceModule;

  static Repository getReposInstance(NetworkModule networkModule,
      LocalModule localModule, PreferenceModule preferenceModule) {
    if (isInited) return _repository;

    SharedPreferenceHelper _sharedPreferenceHelper =
        networkModule.provideSharedPreferenceHelper();
    DioClient _dioClient = networkModule
        .provideDioClient(networkModule.provideDio(_sharedPreferenceHelper));

    AnimeApi _animeApi = AnimeApi(_dioClient);
    UsersApi _usersApi = UsersApi(_dioClient);

    AnimeDataSource _animeDataSource =
        AnimeDataSource(localModule.provideDatabase());
    UserDataSource _userDataSource =
        UserDataSource(localModule.provideDatabase());
    TokenDataSource _tokenDataSource =
        TokenDataSource(localModule.provideDatabase());

    isInited = true;

    _repository = Repository(_animeApi, _usersApi, _sharedPreferenceHelper,
        _animeDataSource, _userDataSource, _tokenDataSource);

    return _repository;
  }
}
