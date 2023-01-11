import 'package:logger/logger.dart';
import 'package:wallet_connect/core/constants.dart';
import 'package:wallet_connect/core/i_core.dart';
import 'package:wallet_connect/core/store/constants.dart';
import 'package:wallet_connect/core/store/i_store.dart';
import 'package:wallet_connect/sign/sign-client/proposal/types.dart';
import 'package:wallet_connect/sign/sign-client/session/types.dart';
import 'package:wallet_connect/utils/error.dart';
import 'package:wallet_connect/wc_utils/jsonrpc/utils/error.dart';

class Store<K, V> implements IStore<K, V> {
  @override
  final Map<K, V> map;

  final String version = STORE_STORAGE_VERSION;

  @override
  final String storagePrefix;

  @override
  final ICore core;

  @override
  final Logger logger;

  @override
  final String name;

  @override
  final StoreObjToJson<V> toJson;

  @override
  final StoreObjFromJson<V> fromJson;

  List<V> _cached;

  bool _initialized;

  /// * [ICore], core Core
  /// * [Logger], logger Logger
  /// * [String], name Store's name
  /// * [String], storagePrefix Prefixes value keys
  /// * [StoreObjToJson], toJson Converts stored data object to json
  /// * [StoreObjFromJson], fromJson Converts stored data object from json
  Store({
    required this.core,
    Logger? logger,
    required this.name,
    String? storagePrefix,
    required this.fromJson,
    required this.toJson,
  })  : logger = logger ?? Logger(),
        storagePrefix = storagePrefix ?? CORE_STORAGE_PREFIX,
        map = {},
        _cached = [],
        _initialized = false;

  @override
  Future<void> init() async {
    if (!_initialized) {
      logger.i('Initialized');
      await _restore();

      for (final value in _cached) {
        if (value is ProposalTypesStruct
            //  && value.proposer.publicKey != null
            ) {
          map[value.id as K] = value;
        } else if (value is SessionTypesStruct
            //  && value.topic != null
            ) {
          map[value.topic as K] = value;
        }
        // else if (getKey && value != null ) {
        //   map.set(getKey(value), value);
        // }
      }

      _cached.clear();
      _initialized = true;
    }
  }

  String get storageKey => '$storagePrefix$version//$name';

  @override
  int get length => map.length;

  @override
  List<K> get keys => map.keys.toList();

  @override
  List<V> get values => map.values.toList();

  @override
  Future<void> set(K key, V value) async {
    _isInitialized();
    logger.d('Setting value');
    logger.i({'type': "method", 'method': "set", 'key': key, 'value': value});
    map[key] = value;
    await _persist();
  }

  @override
  V get(K key) {
    _isInitialized();
    logger.d('Getting value');
    logger.i({'type': "method", 'method': "get", 'key': key});
    final value = _getData(key);
    return value;
  }

  @override
  List<V> getAll([V? filter]) {
    _isInitialized();
    if (filter == null) return values;

    return values.where((value) => value == filter).toList();
  }

  @override
  Future<void> update(key, V Function(V V) update) async {
    _isInitialized();
    final value = update(_getData(key));
    logger.d('Updating value');
    logger.i({
      'type': "method",
      'method': "update",
      'key': key,
      'update': update,
    });
    map[key] = value;
    await _persist();
  }

  @override
  Future<void> delete(key, reason) async {
    _isInitialized();
    if (!map.containsKey(key)) return;
    logger.d('Deleting value');
    logger.i({
      'type': "method",
      'method': "delete",
      'key': key,
      'reason': reason,
    });
    map.remove(key);
    await _persist();
  }

  // ---------- Private ----------------------------------------------- //

  Future<void> _setDataStore(List<dynamic> values) async {
    await core.storage.setItem<List<dynamic>>(storageKey, values);
  }

  Future<List<dynamic>?> _getDataStore() async {
    final value = await core.storage.getItem<List<dynamic>>(storageKey);
    return value;
  }

  V _getData(K key) {
    final value = map[key];
    if (value == null) {
      final error = getInternalError(
        InternalErrorKey.NO_MATCHING_KEY,
        context: '$name: $key',
      );
      logger.e(error.message);
      throw WCException(error.message);
    }
    return value;
  }

  Future<void> _persist() async {
    await _setDataStore(values.map((e) => toJson(e)).toList());
  }

  Future<void> _restore() async {
    try {
      final persisted = await _getDataStore();
      if (persisted?.isEmpty ?? true) return;
      if (map.isNotEmpty) {
        final error = getInternalError(
          InternalErrorKey.RESTORE_WILL_OVERRIDE,
          context: name,
        );
        logger.e(error.message);
        throw WCException(error.message);
      }
      _cached = persisted?.map((e) => fromJson(e)).toList() ?? [];
      logger.d('Successfully Restored value for $name');
      logger.i({
        'type': "method",
        'method': "restore",
        'value': values,
      });
    } catch (e) {
      logger.d('Failed to Restore value for $name');
      logger.e(e.toString());
    }
  }

  void _isInitialized() {
    if (!_initialized) {
      final error = getInternalError(
        InternalErrorKey.NOT_INITIALIZED,
        context: name,
      );
      throw WCException(error.message);
    }
  }
}
