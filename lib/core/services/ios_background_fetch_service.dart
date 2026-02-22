import 'package:background_fetch/background_fetch.dart';

class IosBackgroundFetchService {
  Future<void> initialize() async {
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
      ),
      _onBackgroundFetch,
      _onBackgroundFetchTimeout,
    );
  }

  void _onBackgroundFetch(String taskId) {
    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundFetchTimeout(String taskId) {
    BackgroundFetch.finish(taskId);
  }
}
