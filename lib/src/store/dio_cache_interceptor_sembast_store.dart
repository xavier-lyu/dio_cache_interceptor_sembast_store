import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:sembast/sembast.dart';

/// A store saving response using sembast.
///
class SembastCacheStore implements CacheStore {
  // Sembast database instance
  final Database database;
  // Cache store name
  final String storeName;

  StoreRef<String, Map<String, Object?>>? _store;

  /// Initialize cache store by giving a Sembast database instance.
  SembastCacheStore(
    this.database, {
    this.storeName = "dio_cache",
  }) {
    clean(staleOnly: true);
  }

  StoreRef<String, Map<String, Object?>> _openStore() {
    _store ??= stringMapStoreFactory.store(storeName);
    return _store!;
  }

  @override
  Future<void> clean(
      {CachePriority priorityOrBelow = CachePriority.high,
      bool staleOnly = false}) async {
    final store = _openStore();
    await store.delete(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.lessThanOrEquals('priority', priorityOrBelow.index),
          staleOnly
              ? Filter.lessThan(
                  'maxStale', DateTime.now().millisecondsSinceEpoch)
              : Filter.custom((record) => !staleOnly),
        ]),
      ),
    );
  }

  @override
  Future<void> close() {
    return database.close();
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    final resp = await get(key);
    if (resp == null) return Future.value();

    if (staleOnly && !resp.isStaled()) {
      return Future.value();
    }

    final store = _openStore();
    await store.record(key).delete(database);
  }

  @override
  Future<bool> exists(String key) {
    final store = _openStore();
    return store.record(key).exists(database);
  }

  @override
  Future<CacheResponse?> get(String key) async {
    final store = _openStore();
    final resp = await store.record(key).get(database);
    return resp == null ? null : cacheResponseFromMap(resp);
  }

  @override
  Future<void> set(CacheResponse response) async {
    final store = _openStore();
    await store.record(response.key).put(database, response.toMap());
  }
}

extension CacheResponseObject on CacheResponse {
  Map<String, Object?> toMap() {
    return {
      'cacheControl': cacheControl.toMap(),
      'content': content,
      'date': date?.toIso8601String(),
      'eTag': eTag,
      'expires': expires?.toIso8601String(),
      'headers': headers,
      'key': key,
      'lastModified': lastModified,
      'maxStale': maxStale?.millisecondsSinceEpoch,
      'priority': priority.index,
      'requestDate': requestDate.toIso8601String(),
      'responseDate': responseDate.toIso8601String(),
      'url': url,
    };
  }
}

CacheResponse cacheResponseFromMap(Map<String, Object?> map) {
  return CacheResponse(
    cacheControl:
        cacheControlfromMap(map['cacheControl'] as Map<String, Object?>),
    content: (map['content'] as List<dynamic>?)?.map((e) => e as int).toList(),
    date: map['date'] == null ? null : DateTime.parse(map['date'] as String),
    eTag: map['eTag'] as String?,
    expires: map['expires'] == null
        ? null
        : DateTime.parse(map['expires'] as String),
    headers: (map['headers'] as List<dynamic>?)?.map((e) => e as int).toList(),
    key: map['key'] as String,
    lastModified: map['lastModified'] as String?,
    maxStale: map['maxStale'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((map['maxStale'] as int)),
    priority: CachePriority.values[map['priority'] as int],
    requestDate: map['requestDate'] != null
        ? DateTime.parse(map['requestDate'] as String)
        : DateTime.parse(map['responseDate'] as String)
            .subtract(const Duration(milliseconds: 150)),
    responseDate: DateTime.parse(map['responseDate'] as String),
    url: map['url'] as String,
  );
}

extension CacheControlObject on CacheControl {
  Map<String, Object?> toMap() {
    return {
      'maxAge': maxAge,
      'privacy': privacy,
      'noCache': noCache,
      'noStore': noStore,
      'other': other,
      'maxStale': maxStale,
      'minFresh': minFresh,
      'mustRevalidate': mustRevalidate,
    };
  }
}

CacheControl cacheControlfromMap(Map<String, Object?> map) {
  return CacheControl(
    maxAge: map['maxAge'] as int,
    privacy: map['privacy'] as String?,
    noCache: map['noCache'] as bool,
    noStore: map['noStore'] as bool,
    other: (map['other'] as List<dynamic>).map((e) => e as String).toList(),
    maxStale: map['maxStale'] as int,
    minFresh: map['minFresh'] as int,
    mustRevalidate: map['mustRevalidate'] as bool,
  );
}
